import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_finance/app.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/firebase/firebase_bootstrap.dart';
import 'package:personal_finance/features/document_imports/data/document_connection.dart';
import 'package:personal_finance/features/document_imports/data/document_file_picker.dart';
import 'package:personal_finance/features/document_imports/domain/document_import.dart';
import 'package:personal_finance/features/document_imports/presentation/document_import_providers.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';

class SyntheticPicker extends DocumentFilePicker {
  @override
  Future<DocumentFile?> pick(DocumentFileSource source) async => DocumentFile(
    contentType: 'image/png',
    bytes: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=',
    ),
  );
}

class ControlledConnection extends DocumentConnection {
  bool online = false;
  @override
  Future<bool> hasNetwork() async => online;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) throw StateError('Emulator only');
    await FirebaseBootstrap.initialize(
      AppEnvironment.dev,
      useEmulators: true,
      emulatorHost: const String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: '10.0.2.2',
      ),
    );
    await configureDependencies();
  });
  testWidgets('offline draft, analyze, review and one expense with retained receipt', (
    tester,
  ) async {
    final auth = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app);
    await auth.signOut();
    final user = (await auth.createUserWithEmailAndPassword(
      email: 'receipt-${DateTime.now().microsecondsSinceEpoch}@example.test',
      password: 'Synthetic-QA-12345',
    )).user!;
    final db = FirebaseFirestore.instanceFor(app: FirebaseBootstrap.app),
        root = FirebaseFirestore.instanceFor(app: FirebaseBootstrap.app).doc('users/${user.uid}');
    expect(db.app.options.projectId, 'demo-clearbudget');
    await root.set({
      'locale': 'es',
      'countryCode': 'CO',
      'timeZone': 'America/Bogota',
      'defaultCurrency': 'COP',
      'onboardingStatus': 'complete',
      'categoryCatalogVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final repo = getIt<CanonicalFinanceRepository>();
    (await repo.ensureDefaultCategories(
      user.uid,
      locale: 'es',
      countryCode: 'CO',
    )).match((f) => fail(f.message), (_) {});
    final account = (await repo.createAccount(
      user.uid,
      name: 'QA receipt bank',
      type: 'checking',
      currency: 'COP',
      openingBalanceMinor: 100000,
      accountLastFour: '9999',
    )).getOrElse((f) => throw StateError(f.message));
    final connection = ControlledConnection();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentFilePickerProvider.overrideWithValue(SyntheticPicker()),
          documentConnectionProvider.overrideWithValue(connection),
        ],
        child: const PersonalFinanceApp(),
      ),
    );
    await wait(tester, () => find.byType(NavigationBar).evaluate().isNotEmpty);
    unawaited(
      GoRouter.of(tester.element(find.byType(NavigationBar))).push('/document-imports/new'),
    );
    await wait(
      tester,
      () => find.byKey(const ValueKey('document_pick_gallery')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const ValueKey('document_pick_gallery')));
    await wait(tester, () => find.byKey(const ValueKey('document_analyze')).evaluate().isNotEmpty);
    await tester.ensureVisible(find.byKey(const ValueKey('document_analyze')));
    await tester.tap(find.byKey(const ValueKey('document_analyze')));
    await tester.pump(const Duration(seconds: 1));
    final offline = find.textContaining('internet connection');
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      offline.evaluate().isNotEmpty ||
          find.textContaining('Necesitas conexión a internet').evaluate().isNotEmpty,
      isTrue,
    );
    expect((await root.collection('documentImports').get()).size, 0);
    connection.online = true;
    await tester.tap(find.byKey(const ValueKey('document_analyze')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(AlertDialog).evaluate().isNotEmpty
          ? find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)).last
          : find.widgetWithText(FilledButton, 'Analizar documento').last,
    );
    await wait(tester, () => find.byKey(const ValueKey('document_review')).evaluate().isNotEmpty);
    await tester.ensureVisible(find.byKey(const ValueKey('document_review')));
    await tester.tap(find.byKey(const ValueKey('document_review')));
    await wait(
      tester,
      () => find.byKey(const ValueKey('document_performed')).evaluate().isNotEmpty,
    );
    final save = find.byKey(const ValueKey('operation_save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('document_performed')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('document_performed')));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await wait(tester, () => find.byKey(const ValueKey('operation_save')).evaluate().isEmpty);
    final operations = await root.collection('operations').get();
    expect(operations.size, 1);
    expect(operations.docs.single.get('amountMinor'), 25000);
    expect(
      (await root.collection('accounts').doc(account.id).get()).get('currentBalanceMinor'),
      75000,
    );
    final attachments = await root.collection('attachments').get();
    expect(attachments.size, 1);
    expect(attachments.docs.single.get('status'), 'active');
    final usage = await getIt<DocumentImportRepository>().usage();
    expect(usage.getOrElse((f) => throw StateError(f.message)).dailyUsed, 1);
    final content = await getIt<DocumentImportRepository>().readAttachment(
      attachments.docs.single.id,
    );
    expect(content.isRight(), isTrue);
    binding.reportData = {
      ...?binding.reportData,
      'project': 'demo-clearbudget',
      'checks': {
        'operations': operations.size,
        'attachments': attachments.size,
        'bankBalanceMinor': (await root.collection('accounts').doc(account.id).get()).get(
          'currentBalanceMinor',
        ),
        'analysisUnits': usage.getOrElse((f) => throw StateError(f.message)).dailyUsed,
      },
    };
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('document-expense-confirmed');
  });
}

Future<void> wait(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 300));
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  fail('UI did not reach expected document-import state within 50 seconds');
}
