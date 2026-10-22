import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/offline/sync_state.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/balance_adjustment.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_category.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/operation_page.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_activity_screen.dart';
import 'package:personal_finance/features/finance/presentation/services/activity_csv_save_service.dart';
import 'package:personal_finance/features/finance/presentation/services/activity_csv_share_service.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class _MockFinanceRepository extends Mock implements CanonicalFinanceRepository {}

class _FakeActivityCsvShareService implements ActivityCsvShareService {
  String? contents;
  String? fileName;

  @override
  Future<void> shareCsv({
    required String fileName,
    required String contents,
    required String subject,
  }) async {
    this.fileName = fileName;
    this.contents = contents;
  }
}

class _FakeActivityCsvSaveService implements ActivityCsvSaveService {
  String? contents;
  String? fileName;
  bool saved = true;

  @override
  Future<bool> saveCsv({required String fileName, required String contents}) async {
    this.fileName = fileName;
    this.contents = contents;
    return saved;
  }
}

void main() {
  final operations = [
    _operation(
      id: 'salary',
      type: OperationType.income,
      description: 'Salario',
      accountId: 'savings',
      categoryId: 'salary-category',
      amountMinor: 100,
    ),
    _operation(
      id: 'market',
      type: OperationType.expense,
      description: 'Mercado',
      accountId: 'savings',
      categoryId: 'food',
      amountMinor: 80,
    ),
    _operation(
      id: 'transfer',
      type: OperationType.transfer,
      description: 'Mover dinero',
      amountMinor: 20,
      sourceAccountId: 'savings',
      destinationAccountId: 'cash',
    ),
  ];

  Widget buildSubject({
    required Locale locale,
    _FakeActivityCsvShareService? shareService,
    _FakeActivityCsvSaveService? saveService,
  }) {
    final repository = _MockFinanceRepository();
    when(
      () => repository.fetchOperationsPage(
        any(),
        cursor: any(named: 'cursor'),
        monthKey: any(named: 'monthKey'),
        currency: any(named: 'currency'),
        type: any(named: 'type'),
        accountId: any(named: 'accountId'),
        accountIds: any(named: 'accountIds'),
        startAt: any(named: 'startAt'),
        endAtExclusive: any(named: 'endAtExclusive'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((invocation) async {
      final type = invocation.namedArguments[#type] as OperationType?;
      return Right(
        OperationPage(
          items: operations.where((item) => type == null || item.type == type).toList(),
        ),
      );
    });

    return ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
        ),
        canonicalFinanceRepositoryProvider.overrideWithValue(repository),
        balanceAdjustmentsProvider.overrideWith(
          (ref, userId) => Stream.value(const <BalanceAdjustmentEvent>[]),
        ),
        if (shareService != null) activityCsvShareServiceProvider.overrideWithValue(shareService),
        if (saveService != null) activityCsvSaveServiceProvider.overrideWithValue(saveService),
        canonicalAccountsProvider('user-1').overrideWith(
          (ref) => Stream.value(
            const [
              FinanceAccount(id: 'savings', name: 'Banco1 Ahorros', type: 'savings'),
              FinanceAccount(id: 'cash', name: 'Efectivo', type: 'cash'),
            ],
          ),
        ),
        canonicalCategoriesProvider('user-1').overrideWith(
          (ref) => Stream.value([
            const FinanceCategory(
              id: 'food',
              type: CategoryType.expense,
              customName: 'Comida',
              icon: 'food',
              sortOrder: 1,
              isSystem: true,
              isArchived: false,
            ),
            const FinanceCategory(
              id: 'salary-category',
              type: CategoryType.income,
              customName: 'Salario',
              icon: 'payments',
              sortOrder: 2,
              isSystem: true,
              isArchived: false,
            ),
          ]),
        ),
        pendingOperationSyncStatusProvider.overrideWith(
          (ref) => Stream.value(
            const SyncStatusSnapshot(pending: 0, syncing: 0, confirmed: 0, rejected: 0),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CanonicalActivityScreen(),
      ),
    );
  }

  testWidgets('renders canonical activity rows and filters income and expense', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject(locale: const Locale('es')));
    await tester.pumpAndSettle();

    expect(find.text('Encuentra y revisa tus movimientos'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity_filter_all')), findsOneWidget);
    expect(find.byKey(const ValueKey('activity_operation_salary')), findsOneWidget);
    final activityAmount = find.byKey(const ValueKey('activity_operation_amount_salary'));
    expect(tester.widget<Text>(activityAmount).textAlign, TextAlign.end);
    final activityAmountColumn = find
        .ancestor(of: activityAmount, matching: find.byType(SizedBox))
        .first;
    expect(tester.getSize(activityAmountColumn).width, greaterThanOrEqualTo(100));
    final dateTime = DateFormat.yMMMd('es').add_Hm().format(DateTime(2026, 10, 7, 9, 30));
    expect(find.text('Ingreso · $dateTime'), findsOneWidget);
    expect(find.text('Gasto · $dateTime'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('canonical_activity_scroll_view')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Transferencia · $dateTime'), findsOneWidget);
    expect(find.text('Banco1 Ahorros · Salario'), findsOneWidget);
    expect(find.text('Banco1 Ahorros · Comida'), findsOneWidget);
    expect(find.text('Banco1 Ahorros → Efectivo'), findsOneWidget);
    expect(find.text('Totales confirmados'), findsOneWidget);
    expect(find.text('Saldo neto'), findsOneWidget);
    expect(find.text('Movimientos · 3'), findsOneWidget);
    expect(find.text('Los totales incluyen solo movimientos confirmados.'), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('canonical_activity_scroll_view')),
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_filter_income')));
    await tester.pumpAndSettle();
    expect(find.text('Salario'), findsOneWidget);
    expect(find.text('Mercado'), findsNothing);
    expect(find.text('Mover dinero'), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('canonical_activity_scroll_view')),
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_filter_expense')));
    await tester.pumpAndSettle();
    expect(find.text('Mercado'), findsOneWidget);
    expect(find.text('Salario'), findsNothing);
    expect(find.text('Mover dinero'), findsNothing);
  });

  testWidgets('opens export review and shares confirmed rows including transfers', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _FakeActivityCsvShareService();

    await tester.pumpWidget(buildSubject(locale: const Locale('es'), shareService: service));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_export_open')));
    await tester.pumpAndSettle();

    expect(find.text('Exportar CSV'), findsOneWidget);
    expect(find.text('Todas las cuentas'), findsOneWidget);
    expect(find.text('3 movimientos confirmados'), findsOneWidget);
    expect(find.byKey(const ValueKey('activity_export_save')), findsOneWidget);
    expect(find.byKey(const ValueKey('activity_export_share')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity_export_share')));
    await tester.pumpAndSettle();
    expect(service.fileName, startsWith('lumiomoney-activity-'));
    expect(service.contents, contains('"Transferencia"'));
    expect(service.contents, contains('"Salario"'));
    expect(service.contents, contains('"Mercado"'));
  });

  testWidgets('saves CSV from the review sheet and keeps the same filtered rows', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _FakeActivityCsvSaveService();

    await tester.pumpWidget(buildSubject(locale: const Locale('es'), saveService: service));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_export_open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity_export_save')));
    await tester.pumpAndSettle();

    expect(service.fileName, endsWith('.csv'));
    expect(service.contents, contains('"Transferencia"'));
    expect(find.text('Exportar CSV'), findsNothing);
  });

  testWidgets('fits compact width and enlarged text in Spanish, Portuguese, and English', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final locale in const [Locale('es'), Locale('pt'), Locale('en')]) {
      await tester.pumpWidget(buildSubject(locale: locale));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('activity_title')), findsOneWidget);
      expect(find.byKey(const ValueKey('activity_filter_all')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

FinancialOperation _operation({
  required String id,
  required OperationType type,
  required String description,
  int amountMinor = 100,
  String? accountId,
  String? categoryId,
  String? sourceAccountId,
  String? destinationAccountId,
}) => FinancialOperation(
  id: id,
  type: type,
  amountMinor: amountMinor,
  currency: 'COP',
  monthKey: '2026-10',
  occurredAt: DateTime(2026, 10, 7, 9, 30),
  status: OperationStatus.confirmed,
  idempotencyKey: id,
  description: description,
  accountId: accountId,
  categoryId: categoryId,
  sourceAccountId: sourceAccountId,
  destinationAccountId: destinationAccountId,
);
