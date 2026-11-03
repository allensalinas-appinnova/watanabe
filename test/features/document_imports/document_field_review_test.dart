import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/document_imports/data/document_connection.dart';
import 'package:personal_finance/features/document_imports/data/document_import_mapper.dart';
import 'package:personal_finance/features/document_imports/domain/document_import.dart';
import 'package:personal_finance/features/document_imports/presentation/document_field_review_hint.dart';
import 'package:personal_finance/features/document_imports/presentation/document_import_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_category.dart';
import 'package:personal_finance/features/finance/presentation/models/movement_save_result.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_operation_form_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class ReviewRepo extends Mock implements DocumentImportRepository {}

class OnlineConnection extends DocumentConnection {
  @override
  Future<bool> hasNetwork() async => true;
}

class OfflineConnection extends DocumentConnection {
  @override
  Future<bool> hasNetwork() async => false;
}

final file = DocumentFile(bytes: Uint8List.fromList([1]), contentType: 'image/png');
DocumentImport source({String currency = 'COP', Set<DocumentReviewField> fields = const {}}) =>
    DocumentImport(
      id: 'review-source',
      generation: 0,
      version: 1,
      phase: DocumentPhase.ready,
      suggestion: DocumentSuggestion(
        amountMinor: 25000,
        currency: currency,
        accountId: 'bank',
        categoryId: 'food',
        description: 'Synthetic receipt',
        date: DateTime(2026, 11, 2),
        reviewFields: fields,
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(DocumentDraft(file: file, importId: 'review-source', generation: 0));
    registerFallbackValue(
      DocumentApproval(
        source: source(),
        accountId: 'bank',
        categoryId: 'food',
        currency: 'COP',
        amountMinor: 1,
        occurredAt: DateTime(2026, 11, 2),
        monthKey: '2026-11',
        description: '',
        creditCard: false,
      ),
    );
  });
  for (final replaceForm in [false, true]) {
    testWidgets('confirmed receipt survives form replacement=$replaceForm', (tester) async {
      final repo = ReviewRepo(), imported = source();
      final completed = ValueNotifier(false);
      addTearDown(completed.dispose);
      final draft = DocumentDraft(
        file: file,
        importId: imported.id,
        generation: 0,
        review: const {'performed': true, 'dateConfirmed': true},
      );
      when(() => repo.loadDraft('qa', 0)).thenAnswer((_) async => Right(draft));
      when(() => repo.saveDraft('qa', any())).thenAnswer((_) async => const Right(unit));
      when(() => repo.approve(any())).thenAnswer((_) async {
        if (replaceForm) completed.value = true;
        return const Right('saved-operation');
      });
      MovementSaveResult? receipt;
      await pumpForm(
        tester,
        repo,
        imported,
        onReturned: (value) => receipt = value,
        completed: replaceForm ? completed : null,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('operation_save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('operation_save')));
      await tester.pumpAndSettle();
      expect(find.text('Origin'), findsOneWidget);
      expect(receipt?.status, MovementSaveStatus.confirmed);
      expect(receipt?.amountMinor, 25000);
      expect(receipt?.idempotencyKey, 'doc_review-source');
    });
  }
  test(
    'server warnings are typed, unknown warnings are tolerated, and old responses remain compatible',
    () {
      final row = mapDocumentImport('id', {
        'status': 'ready',
        'extraction': {
          'amountMinor': 25000,
          'currency': 'COP',
          'warnings': ['amount-review', 'account-review', 'future-warning', 12],
        },
      });
      expect(row.suggestion.reviewFields, {
        DocumentReviewField.amount,
        DocumentReviewField.account,
      });
      expect(
        row.suggestion.statusFor(DocumentReviewField.amount, available: true, userEdited: false),
        DocumentReviewStatus.needsReview,
      );
      expect(
        row.suggestion.statusFor(DocumentReviewField.amount, available: true, userEdited: true),
        DocumentReviewStatus.userProvided,
      );
      expect(
        row.suggestion.statusFor(DocumentReviewField.amount, available: false, userEdited: true),
        DocumentReviewStatus.needsReview,
      );
      expect(
        mapDocumentImport('id', {'extraction': <String, dynamic>{}}).suggestion.reviewFields,
        isEmpty,
      );
      for (final date in ['1999-12-31', '2101-01-01', '2026-02-31', 'invalid']) {
        expect(
          mapDocumentImport('id', {
            'extraction': {'date': date},
          }).suggestion.date,
          isNull,
        );
      }
      expect(
        mapDocumentImport('id', {
          'extraction': {'date': '2024-02-29'},
        }).suggestion.date,
        DateTime(2024, 2, 29),
      );
    },
  );
  for (final language in ['es', 'en', 'pt']) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('field review hints wrap accessibly at 320dp in $language $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: ThemeData(brightness: brightness),
            home: Builder(
              builder: (context) => Scaffold(
                body: MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
                  child: ListView(
                    children: [
                      for (final status in DocumentReviewStatus.values)
                        DocumentFieldReviewHint(
                          field: DocumentReviewField.amount,
                          status: status,
                          detail: AppLocalizations.of(
                            context,
                          ).documentCurrencyMismatch('COP', 'USD'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(DocumentFieldReviewHint), findsNWidgets(3));
        expect(find.byType(ExcludeSemantics), findsWidgets);
      });
    }
  }
  testWidgets(
    'editing an imported amount updates its origin and preserves draft metadata on offline save',
    (tester) async {
      final repo = ReviewRepo();
      final imported = source();
      var draft = DocumentDraft(
        file: file,
        importId: imported.id,
        generation: 0,
        review: const {'serverAttempted': true},
      );
      when(() => repo.loadDraft('qa', 0)).thenAnswer((_) async => Right(draft));
      when(() => repo.saveDraft('qa', any())).thenAnswer((invocation) async {
        draft = invocation.positionalArguments[1] as DocumentDraft;
        return const Right(unit);
      });
      await pumpForm(tester, repo, imported);
      DocumentReviewStatus state(String field) => tester
          .widget<DocumentFieldReviewHint>(find.byKey(ValueKey('document_field_$field')))
          .status;
      expect(state('amount'), DocumentReviewStatus.suggested);
      await tester.ensureVisible(find.byKey(const ValueKey('operation_amount')));
      await tester.enterText(find.byKey(const ValueKey('operation_amount')), '30000');
      await tester.pump();
      expect(state('amount'), DocumentReviewStatus.userProvided);
      await tester.pump(const Duration(milliseconds: 500));
      expect(draft.review['amount'], '30000');
      expect(draft.review['serverAttempted'], true);
      expect(draft.review['editedFields'], contains('amount'));
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('document_performed')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('document_performed')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byKey(const ValueKey('document_performed'))).value,
        true,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('operation_save')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byKey(const ValueKey('operation_save'))).onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('operation_save')));
      await tester.pumpAndSettle();
      expect(draft.review['amount'], '30000');
      expect(draft.review['serverAttempted'], true);
      expect(find.textContaining('Necesitas conexión a internet'), findsOneWidget);
      verifyNever(() => repo.approve(any()));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpForm(tester, repo, imported);
      expect(state('amount'), DocumentReviewStatus.userProvided);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('operation_amount')))
            .controller!
            .text,
        '30000',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets(
    'currency mismatch stays reviewable and existing manual draft values keep their origin',
    (tester) async {
      final repo = ReviewRepo();
      final imported = source(currency: 'USD');
      final draft = DocumentDraft(
        file: file,
        importId: imported.id,
        generation: 0,
        review: const {'amount': '31000', 'date': '1900-01-01T00:00:00', 'dateConfirmed': true},
      );
      when(() => repo.loadDraft('qa', 0)).thenAnswer((_) async => Right(draft));
      when(() => repo.saveDraft('qa', any())).thenAnswer((_) async => const Right(unit));
      await pumpForm(tester, repo, imported);
      expect(
        tester
            .widget<DocumentFieldReviewHint>(find.byKey(const ValueKey('document_field_currency')))
            .status,
        DocumentReviewStatus.needsReview,
      );
      expect(
        tester
            .widget<DocumentFieldReviewHint>(find.byKey(const ValueKey('document_field_currency')))
            .detail,
        contains('USD'),
      );
      expect(
        tester
            .widget<DocumentFieldReviewHint>(find.byKey(const ValueKey('document_field_amount')))
            .status,
        DocumentReviewStatus.userProvided,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('document_field_date')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<DocumentFieldReviewHint>(find.byKey(const ValueKey('document_field_date')))
            .status,
        DocumentReviewStatus.needsReview,
      );
      expect(
        tester.widget<FilledButton>(find.byKey(const ValueKey('operation_save'))).onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

Future<void> pumpForm(
  WidgetTester tester,
  ReviewRepo repo,
  DocumentImport imported, {
  void Function(MovementSaveResult?)? onReturned,
  ValueNotifier<bool>? completed,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: onReturned == null ? '/review' : '/origin',
    routes: [
      GoRoute(
        path: '/origin',
        builder: (c, _) => Scaffold(
          body: TextButton(
            onPressed: () async {
              onReturned?.call(await c.push<MovementSaveResult>('/review'));
            },
            child: const Text('Origin'),
          ),
        ),
      ),
      GoRoute(
        path: '/review',
        builder: (c, _) {
          final form = CanonicalOperationFormScreen(
            documentImport: imported,
            onDocumentSaved: completed == null ? null : (result) async => c.pop(result),
            initialAccountId: imported.suggestion.accountId,
            initialCategoryId: imported.suggestion.categoryId,
            initialOccurredAt: imported.suggestion.date,
          );
          if (completed == null) return form;
          return ValueListenableBuilder<bool>(
            valueListenable: completed,
            builder: (_, approved, _) => approved ? const Scaffold(body: Text('Approved')) : form,
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(id: 'qa', isAnonymous: false)),
        ),
        canonicalAccountsProvider('qa').overrideWith(
          (ref) => Stream.value(const [
            FinanceAccount(id: 'bank', name: 'Synthetic bank', type: 'cash', currency: 'COP'),
          ]),
        ),
        canonicalCategoriesProvider('qa').overrideWith(
          (ref) => Stream.value(const [
            FinanceCategory(
              id: 'food',
              type: CategoryType.expense,
              icon: 'shopping_bag',
              sortOrder: 0,
              isSystem: false,
              isArchived: false,
            ),
          ]),
        ),
        canonicalRecentOperationsProvider('qa').overrideWith((ref) => Stream.value([])),
        documentImportRepositoryProvider.overrideWithValue(repo),
        documentConnectionProvider.overrideWithValue(
          onReturned == null ? OfflineConnection() : OnlineConnection(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (onReturned != null) {
    await tester.tap(find.text('Origin'));
    await tester.pumpAndSettle();
  }
}
