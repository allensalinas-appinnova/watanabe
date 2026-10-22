import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/firebase/firebase_bootstrap.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_category.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '127.0.0.1');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final response = await client
          .getUrl(Uri(scheme: 'http', host: host, port: 59199))
          .then((request) => request.close());
      await response.drain<void>();
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('Auth emulator is unavailable: ${response.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
    await FirebaseBootstrap.initialize(AppEnvironment.dev, useEmulators: true, emulatorHost: host);
    await configureDependencies();
    await FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).signOut();
  });

  tearDownAll(() async {
    await FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).signOut();
    await GetIt.I.reset();
  });

  testWidgets('category icon update persists and is returned by the repository', (_) async {
    final user = (await FirebaseAuth.instanceFor(
      app: FirebaseBootstrap.app,
    ).signInAnonymously()).user!;
    final userRef = FirebaseFirestore.instanceFor(
      app: FirebaseBootstrap.app,
    ).collection('users').doc(user.uid);
    await userRef.set({
      'locale': 'es',
      'countryCode': 'CO',
      'timeZone': 'America/Bogota',
      'defaultCurrency': 'COP',
      'onboardingStatus': 'complete',
      'categoryCatalogVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final repository = getIt<CanonicalFinanceRepository>();
    final bootstrap = await repository.ensureDefaultCategories(
      user.uid,
      locale: 'es',
      countryCode: 'CO',
    );
    bootstrap.match(
      (failure) => fail('Category bootstrap failed: ${failure.message}'),
      (_) {},
    );

    final categories = await repository.watchCategories(user.uid).first;
    final original = categories.firstWhere((category) => category.type == CategoryType.expense);
    final updated = FinanceCategory(
      id: original.id,
      type: original.type,
      icon: 'transport',
      sortOrder: original.sortOrder,
      isSystem: original.isSystem,
      isArchived: original.isArchived,
      catalogId: original.catalogId,
      customName: original.customName,
      colorValue: original.colorValue,
    );

    final result = await repository.updateCategory(user.uid, updated);
    result.match(
      (failure) => fail('Category icon update failed: ${failure.message}'),
      (_) {},
    );

    final persisted = await userRef.collection('categories').doc(original.id).get();
    expect(persisted.data()?['icon'], 'transport');
    final readBack = await repository.watchCategories(user.uid).first;
    expect(readBack.singleWhere((category) => category.id == original.id).icon, 'transport');
  });
}
