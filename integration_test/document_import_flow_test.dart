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
import 'package:pdfrx/pdfrx.dart';
import 'package:personal_finance/app.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/firebase/firebase_bootstrap.dart';
import 'package:personal_finance/features/document_imports/data/document_connection.dart';
import 'package:personal_finance/features/document_imports/data/document_file_picker.dart';
import 'package:personal_finance/features/document_imports/domain/document_import.dart';
import 'package:personal_finance/features/document_imports/presentation/document_field_review_hint.dart';
import 'package:personal_finance/features/document_imports/presentation/document_import_providers.dart';
import 'package:personal_finance/features/document_imports/presentation/document_import_screen.dart';
import 'package:personal_finance/features/document_imports/presentation/resource_usage_screen.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/widgets/finance_components.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

import 'fixtures/purchase_pdf.dart';

class SyntheticPicker extends DocumentFilePicker {
  @override
  Future<DocumentFile?> pick(DocumentFileSource source) async => source == DocumentFileSource.file
      ? DocumentFile(contentType: 'application/pdf', bytes: base64Decode(purchasePdfBase64))
      : DocumentFile(
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
  testWidgets('offline image, reviewed PDF and duplicate import preserve balances and attachments', (
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
    await openDocumentFromRegister(tester);
    await wait(
      tester,
      () => find.byKey(const ValueKey('document_pick_gallery')).evaluate().isNotEmpty,
    );
    if (const bool.fromEnvironment('QA_NATIVE_SHARE')) {
      await nativeShare('image');
    } else {
      await tester.tap(find.byKey(const ValueKey('document_pick_gallery')));
    }
    await wait(tester, () => find.byKey(const ValueKey('document_analyze')).evaluate().isNotEmpty);
    await tester.pumpAndSettle();
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
    await setProviderFailure(true);
    connection.online = true;
    await tester.tap(find.byKey(const ValueKey('document_analyze')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(AlertDialog).evaluate().isNotEmpty
          ? find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)).last
          : find.widgetWithText(FilledButton, 'Analizar documento').last,
    );
    final feedbackLabels = AppLocalizations.of(tester.element(find.byType(DocumentImportScreen)));
    await wait(tester, () => find.text(feedbackLabels.documentServiceBusy).evaluate().isNotEmpty);
    final failedSource = (await root.collection('documentImports').get()).docs.single;
    expect(failedSource.get('status'), 'failed');
    expect(failedSource.get('issue'), 'document-service-busy');
    final failedUsage = (await getIt<DocumentImportRepository>().usage()).getOrElse(
      (f) => throw StateError(f.message),
    );
    expect(failedUsage.dailyUsed, 0);
    expect((await root.collection('operations').get()).size, 0);
    expect(
      (await root.collection('accounts').doc(account.id).get()).get('currentBalanceMinor'),
      100000,
    );
    await setProviderFailure(false);
    await tester.ensureVisible(find.byKey(const ValueKey('document_analyze')));
    await tester.tap(find.byKey(const ValueKey('document_analyze')));
    expect((await root.collection('documentImports').get()).docs.single.id, failedSource.id);
    await wait(
      tester,
      () => find.byKey(const ValueKey('document_performed')).evaluate().isNotEmpty,
    );
    final save = find.byKey(const ValueKey('operation_save'));
    final amountHint = tester.widget<DocumentFieldReviewHint>(
      find.byKey(const ValueKey('document_field_amount')),
    );
    expect(amountHint.status, DocumentReviewStatus.suggested);
    expect(
      tester
          .widget<DocumentFieldReviewHint>(find.byKey(const ValueKey('document_field_account')))
          .status,
      DocumentReviewStatus.suggested,
    );
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
      'qaEmail': user.email,
      'checks': {
        'operations': operations.size,
        'attachments': attachments.size,
        'bankBalanceMinor': (await root.collection('accounts').doc(account.id).get()).get(
          'currentBalanceMinor',
        ),
        'analysisUnits': usage.getOrElse((f) => throw StateError(f.message)).dailyUsed,
        'providerBusyRecovered': true,
        'failedAttemptRefunded': true,
        'retryKeptImportId': true,
      },
    };
    // Repeat through the app with a PDF whose account/category are intentionally absent.
    // Only the picker and external provider are fixtures; all financial commands are real Emulator calls.
    await wait(tester, () => find.byType(DocumentImportScreen).evaluate().isEmpty);
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
    await tester.tap(find.byKey(const ValueKey('finance_nav_activity')));
    await tester.pumpAndSettle();
    final expenseFilter = find.byKey(const ValueKey('activity_filter_expense'));
    await tester.ensureVisible(expenseFilter);
    await tester.pumpAndSettle();
    await tester.tap(expenseFilter);
    await tester.pumpAndSettle();
    await openDocumentFromRegister(tester);
    await wait(tester, () => find.byType(DocumentImportScreen).evaluate().isNotEmpty);
    final l10n = AppLocalizations.of(tester.element(find.byType(DocumentImportScreen)));
    final pickPdf = find.byKey(const ValueKey('document_pick_file'));
    await wait(tester, () => pickPdf.evaluate().isNotEmpty);
    await tester.ensureVisible(pickPdf);
    if (const bool.fromEnvironment('QA_NATIVE_SHARE')) {
      await nativeShare('pdf');
    } else {
      await tester.tap(pickPdf);
    }
    await wait(tester, () => find.byKey(const ValueKey('document_analyze')).evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('document_analyze')));
    await tester.tap(find.byKey(const ValueKey('document_analyze')));
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)),
      );
    }
    await wait(
      tester,
      () => find.byKey(const ValueKey('document_performed')).evaluate().isNotEmpty,
    );
    expect(
      tester.widget<TextFormField>(find.byKey(const ValueKey('operation_amount'))).controller!.text,
      '39000',
    );
    expect(
      tester
          .widget<DocumentFieldReviewHint>(find.byKey(const ValueKey('document_field_account')))
          .status,
      DocumentReviewStatus.needsReview,
    );
    expect(
      tester
          .widget<DocumentFieldReviewHint>(find.byKey(const ValueKey('document_field_category')))
          .status,
      DocumentReviewStatus.needsReview,
    );
    await tester.tap(find.byKey(const ValueKey('document_performed')));
    final selectAccount = find.byKey(const ValueKey('operation_account_selector_none_tap'));
    await tester.ensureVisible(selectAccount);
    await tester.tap(selectAccount);
    final accountOption = find.byKey(ValueKey('finance_popup_option_${account.id}'));
    await wait(tester, () => accountOption.evaluate().isNotEmpty);
    await tester.tap(accountOption);
    await wait(tester, () => accountOption.evaluate().isEmpty);
    expect(
      tester
          .widget<DocumentFieldReviewHint>(find.byKey(const ValueKey('document_field_account')))
          .status,
      DocumentReviewStatus.userProvided,
    );
    await tester.pump(const Duration(milliseconds: 500));
    final selectCategory = find.byKey(const ValueKey('operation_category_selector_tap'));
    await tester.ensureVisible(selectCategory);
    await tester.tap(selectCategory);
    final categoryOption = find.byKey(const ValueKey('finance_popup_option_food'));
    await wait(tester, () => categoryOption.evaluate().isNotEmpty);
    await tester.tap(categoryOption);
    await wait(tester, () => categoryOption.evaluate().isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(save);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(save);
    await wait(tester, () => save.evaluate().isEmpty);
    final finalOperations = await root.collection('operations').get();
    expect(finalOperations.size, 2);
    expect(finalOperations.docs.map((d) => d.get('amountMinor')), unorderedEquals([25000, 39000]));
    expect(
      finalOperations.docs.every(
        (d) => d.get('type') == 'expense' && d.get('status') == 'confirmed',
      ),
      isTrue,
    );
    final finalBalance = (await root.collection('accounts').doc(account.id).get()).get(
      'currentBalanceMinor',
    );
    expect(finalBalance, 36000);
    final finalAttachments = await root.collection('attachments').get();
    expect(finalAttachments.size, 2);
    final pdfAttachment = finalAttachments.docs.singleWhere(
      (d) => d.get('contentType') == 'application/pdf',
    );
    final pdfContent = (await getIt<DocumentImportRepository>().readAttachment(
      pdfAttachment.id,
    )).getOrElse((f) => throw StateError(f.message));
    expect(pdfContent.bytes, base64Decode(purchasePdfBase64));
    await wait(tester, () => find.byType(DocumentImportScreen).evaluate().isEmpty);
    expect(
      router.state.uri.path,
      const bool.fromEnvironment('QA_NATIVE_SHARE') ? '/home' : '/activity',
    );
    if (!const bool.fromEnvironment('QA_NATIVE_SHARE')) {
      await tester.ensureVisible(expenseFilter);
      expect(tester.widget<ChoiceChip>(expenseFilter).selected, isTrue);
    }
    expect(
      tester.widget<FilledButton>(find.byKey(const ValueKey('global_add_operation'))).onPressed,
      isNotNull,
    );
    unawaited(router.push('/attachments/${pdfAttachment.id}'));
    await wait(tester, () => find.byType(PdfViewer).evaluate().isNotEmpty);
    router.pop();
    await tester.pump(const Duration(milliseconds: 500));
    await openDocumentFromRegister(tester);
    await wait(tester, () => pickPdf.evaluate().isNotEmpty);
    await tester.ensureVisible(pickPdf);
    await tester.tap(pickPdf);
    await wait(tester, () => find.byKey(const ValueKey('document_analyze')).evaluate().isNotEmpty);
    await tester.ensureVisible(find.byKey(const ValueKey('document_analyze')));
    await tester.tap(find.byKey(const ValueKey('document_analyze')));
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)),
      );
    }
    await wait(tester, () => find.text(l10n.documentOpenExisting).evaluate().isNotEmpty);
    expect((await root.collection('operations').get()).size, 2);
    expect((await root.collection('attachments').get()).size, 2);
    expect(
      (await root.collection('accounts').doc(account.id).get()).get('currentBalanceMinor'),
      36000,
    );
    final finalUsage = (await getIt<DocumentImportRepository>().usage()).getOrElse(
      (f) => throw StateError(f.message),
    );
    expect(finalUsage.dailyUsed, 2);
    expect(
      finalUsage.attachmentBytes,
      (attachments.docs.single.get('size') as int) + (pdfAttachment.get('size') as int),
    );
    expect(finalUsage.temporaryBytes, 0);
    binding.reportData = {
      ...?binding.reportData,
      'pdfAndDuplicateChecks': {
        'operations': 2,
        'attachments': 2,
        'bankBalanceMinor': finalBalance,
        'analysisUnits': finalUsage.dailyUsed,
        'pdfContentMatches': true,
        'pdfViewerOpened': true,
        'duplicateDidNotDebit': true,
        'nativeImageAndPdfChooser': const bool.fromEnvironment('QA_NATIVE_SHARE'),
      },
    };
    // The compact attachment is secondary to flow selection, and deleting it is not a financial reversal.
    unawaited(router.push('/operations/${pdfAttachment.get('operationId')}/edit'));
    await wait(tester, () => find.byType(CompactAttachmentRow).evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    final compact = find.byType(CompactAttachmentRow);
    expect(
      tester.getTopLeft(find.byType(FinanceOperationTypeSelector)).dy,
      lessThan(tester.getTopLeft(compact).dy),
    );
    expect(
      tester.getTopLeft(compact).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('operation_amount'))).dy),
    );
    await tester.tap(find.descendant(of: compact, matching: find.byType(PopupMenuButton<String>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.documentDeleteAttachment).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, l10n.cancel),
      ),
    );
    await tester.pumpAndSettle();
    expect(compact, findsOneWidget);
    await tester.tap(find.descendant(of: compact, matching: find.byType(PopupMenuButton<String>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.documentDeleteAttachment).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, l10n.documentDelete),
      ),
    );
    await wait(tester, () => compact.evaluate().isEmpty);
    expect((await root.collection('operations').get()).size, 2);
    expect(
      (await root.collection('accounts').doc(account.id).get()).get('currentBalanceMinor'),
      36000,
    );
    expect(
      (await root.collection('attachments').where('status', isEqualTo: 'active').get()).size,
      1,
    );
    binding.reportData = {
      ...?binding.reportData,
      'compactAttachmentChecks': {
        'automaticReview': true,
        'returnedHomeAfterImage': true,
        'returnedToSourceAfterPdf': true,
        'registrarReusableAfterSave': true,
        'entryThroughRegistrar': true,
        'positionBelowFlow': true,
        'cancelPreserved': true,
        'activeAttachmentsAfterDelete': 1,
        'operationsAfterDelete': 2,
        'bankAfterDelete': 36000,
      },
    };
    router.pop();
    await tester.pumpAndSettle();
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('document-expense-confirmed');
  });
}

Future<void> openDocumentFromRegister(WidgetTester tester) async {
  final register = find.byKey(const ValueKey('global_add_operation'));
  await wait(tester, () => register.evaluate().isNotEmpty);
  expect(tester.widget<FilledButton>(register).onPressed, isNotNull);
  await tester.tap(register);
  await tester.pumpAndSettle();
  final document = find.byKey(const ValueKey('add_movement_document'));
  await tester.ensureVisible(document);
  await tester.pumpAndSettle();
  await tester.tap(document);
  await wait(tester, () => find.byType(DocumentImportScreen).evaluate().isNotEmpty);
}

Future<void> wait(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 300));
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  if (Platform.isAndroid && const bool.fromEnvironment('QA_NATIVE_SHARE')) {
    final client = HttpClient();
    try {
      await (await client.getUrl(Uri.parse('http://10.0.2.2:59179/capture'))).close();
    } finally {
      client.close(force: true);
    }
  }
  debugDumpApp();
  fail('UI did not reach expected document-import state within 50 seconds');
}

Future<void> nativeShare(String kind) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(
      Uri.parse('http://10.0.2.2:59179/share/$kind'),
    )).close().timeout(const Duration(seconds: 45));
    await response.drain<void>();
    expect(response.statusCode, 200, reason: 'Native Android share chooser must complete');
  } finally {
    client.close(force: true);
  }
}

Future<void> setProviderFailure(bool fail) async {
  if (!const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) throw StateError('Emulator only');
  final host = const String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '10.0.2.2');
  final client = HttpClient();
  try {
    final uri = Uri.http(
      '$host:59180',
      '/v1/projects/demo-clearbudget/databases/(default)/documents/servicePolicies/documentImportTestFixture',
      {
        'updateMask.fieldPaths': ['fail', 'failStatus'],
      },
    );
    final request = await client.patchUrl(uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'fields': {
          'fail': {'booleanValue': fail},
          'failStatus': {'integerValue': '429'},
        },
      }),
    );
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode != 200) throw StateError('Emulator fixture update failed');
  } finally {
    client.close(force: true);
  }
}
