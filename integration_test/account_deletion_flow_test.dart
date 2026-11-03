import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_finance/app.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/firebase/firebase_bootstrap.dart';
import 'package:personal_finance/core/routing/app_router.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('USE_FIREBASE_EMULATORS') ||
        !const bool.fromEnvironment('ACCOUNT_DELETION_ENABLED')) {
      throw StateError('Emulator and explicit deletion qualification flag required');
    }
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '127.0.0.1');
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(
        Uri.parse(
          'http://$host:59199/emulator/v1/projects/demo-clearbudget/config',
        ),
      )).close();
      if (response.statusCode != 200) throw StateError('Auth Emulator required');
    } finally {
      client.close(force: true);
    }
    await FirebaseBootstrap.initialize(AppEnvironment.dev, useEmulators: true, emulatorHost: host);
    if (FirebaseBootstrap.app.options.projectId != 'demo-clearbudget') {
      throw StateError('demo project required');
    }
    await configureDependencies(useEmulators: true);
  });
  tearDownAll(() async {
    await disposeAppRouter();
    await GetIt.I.reset();
  });

  testWidgets('registered synthetic user confirms deletion through Settings and returns to login', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await disposeAppRouter();
    });
    final auth = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app);
    await auth.signOut();
    const password = 'Emulator-only-test-123';
    final user = (await auth.createUserWithEmailAndPassword(
      email: 'deletion-${DateTime.now().microsecondsSinceEpoch}@example.test',
      password: password,
    )).user!;
    await FirebaseFirestore.instanceFor(app: FirebaseBootstrap.app).doc('users/${user.uid}').set({
      'dataGeneration': 0,
      'locale': 'es',
      'countryCode': 'CO',
      'timeZone': 'America/Bogota',
      'defaultCurrency': 'COP',
      'onboardingStatus': 'complete',
      'categoryCatalogVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await tester.pumpWidget(ProviderScope(key: UniqueKey(), child: const PersonalFinanceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final settings = find.byKey(const ValueKey('global_settings_action'));
    final loadedBy = DateTime.now().add(const Duration(seconds: 20));
    while (settings.evaluate().isEmpty && DateTime.now().isBefore(loadedBy)) {
      await tester.pump(const Duration(milliseconds: 200));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(settings, findsOneWidget);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('settings_delete_account'));
    await tester.scrollUntilVisible(action, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), password);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    final submit = find.byType(FilledButton);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline) &&
        find.byKey(const ValueKey('auth_guest_button')).evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 200));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('auth_guest_button')), findsOneWidget);
    expect(auth.currentUser, isNull);
    // Acceptance precedes asynchronous cleanup. Inspect only the isolated Emulator marker.
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '127.0.0.1');
    final client = HttpClient();
    var complete = false;
    final completedBy = DateTime.now().add(const Duration(seconds: 90));
    try {
      while (!complete && DateTime.now().isBefore(completedBy)) {
        final lookup = await client.getUrl(
          Uri.parse(
            'http://$host:59180/v1/projects/demo-clearbudget/databases/(default)/documents/accountDeletions/${user.uid}',
          ),
        );
        lookup.headers.set('Authorization', 'Bearer owner');
        final response = await lookup.close();
        final body = jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>;
        final fields = body['fields'] as Map<String, dynamic>?;
        final status = fields?['status'] as Map<String, dynamic>?;
        complete = status?['stringValue'] == 'complete';
        if (!complete) {
          await tester.pump(const Duration(milliseconds: 200));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    } finally {
      client.close(force: true);
    }
    expect(complete, isTrue, reason: 'The accepted request must finish its Emulator worker');
    await expectLater(
      auth.signInWithEmailAndPassword(email: user.email!, password: password),
      throwsA(isA<FirebaseAuthException>()),
    );
  });
}
