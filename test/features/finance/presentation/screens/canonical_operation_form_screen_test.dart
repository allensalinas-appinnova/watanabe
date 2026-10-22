import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_category.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/presentation/models/budget_item_movement_preset.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_operation_form_screen.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_transfer_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('new income and expense forms default to the current local time', (tester) async {
    final before = DateTime.now();
    await _pumpOperationForm(tester, const [
      FinanceAccount(id: 'cash', name: 'Efectivo', type: 'cash'),
    ]);
    expect(find.byKey(const ValueKey('operation_time_selector')), findsNothing);
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    final after = DateTime.now();
    final timeLabel = find.descendant(
      of: find.byKey(const ValueKey('operation_time_selector')),
      matching: find.byType(Text),
    );
    final displayedTime = tester.widget<Text>(timeLabel).data;
    final context = tester.element(timeLabel);
    expect(
      displayedTime,
      anyOf(
        TimeOfDay.fromDateTime(before).format(context),
        TimeOfDay.fromDateTime(after).format(context),
      ),
    );
    expect(find.byKey(const ValueKey('operation_time_selector')), findsOneWidget);
  });

  testWidgets('edited operation keeps its saved local time and exposes a time picker', (
    tester,
  ) async {
    final operation = FinancialOperation(
      id: 'op-1',
      type: OperationType.expense,
      amountMinor: 2500,
      currency: 'COP',
      monthKey: '2026-10',
      occurredAt: DateTime(2026, 10, 7, 16, 45).toUtc(),
      status: OperationStatus.confirmed,
      idempotencyKey: 'key-1',
      accountId: 'cash',
      categoryId: 'food',
      description: 'Mercado',
    );
    await _pumpOperationForm(
      tester,
      const [FinanceAccount(id: 'cash', name: 'Efectivo', type: 'cash')],
      initialOperation: operation,
    );

    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    final timeSelector = find.byKey(const ValueKey('operation_time_selector'));
    expect(
      tester.widget<Text>(find.descendant(of: timeSelector, matching: find.byType(Text))).data,
      TimeOfDay.fromDateTime(operation.occurredAt.toLocal()).format(tester.element(timeSelector)),
    );
    await tester.tap(timeSelector);
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transfer form defaults to current time and allows opening time picker', (
    tester,
  ) async {
    final before = DateTime.now();
    await _pumpTransferForm(tester);
    final after = DateTime.now();
    final timeSelector = find.byKey(const ValueKey('transfer_time_selector'));
    final timeText = tester.widget<Text>(
      find.descendant(of: timeSelector, matching: find.byType(Text)),
    );
    final context = tester.element(timeSelector);
    expect(
      timeText.data,
      anyOf(
        TimeOfDay.fromDateTime(before).format(context),
        TimeOfDay.fromDateTime(after).format(context),
      ),
    );
    await tester.tap(timeSelector);
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
  });

  testWidgets('preselects the only active account for a new expense', (tester) async {
    await _pumpOperationForm(tester, const [
      FinanceAccount(id: 'cash', name: 'Efectivo', type: 'cash'),
    ]);

    final selector = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('operation_account_selector_cash')),
    );
    expect(selector.initialValue, 'cash');
  });

  testWidgets('shows inline validation for an amount above the currency limit', (tester) async {
    await _pumpOperationForm(tester, const [
      FinanceAccount(id: 'cash', name: 'Efectivo', type: 'cash'),
    ]);
    await tester.enterText(find.byKey(const ValueKey('operation_amount')), '1000000001');
    final save = find.byKey(const ValueKey('operation_save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Amount cannot exceed 1,000,000,000 in this currency.'), findsOneWidget);
  });

  testWidgets('preselects the only active account for a new income', (tester) async {
    await _pumpOperationForm(
      tester,
      const [FinanceAccount(id: 'bank', name: 'Banco', type: 'checking')],
      initialType: OperationType.income,
    );

    final selector = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('operation_account_selector_bank')),
    );
    expect(selector.initialValue, 'bank');
  });

  testWidgets('ignores archived accounts when choosing the only active account', (tester) async {
    await _pumpOperationForm(tester, const [
      FinanceAccount(id: 'cash', name: 'Efectivo', type: 'cash'),
      FinanceAccount(id: 'old', name: 'Old', type: 'checking', status: 'archived'),
    ]);

    final selector = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('operation_account_selector_cash')),
    );
    expect(selector.initialValue, 'cash');
  });

  testWidgets('does not guess when multiple active accounts are available', (tester) async {
    await _pumpOperationForm(tester, const [
      FinanceAccount(id: 'cash', name: 'Efectivo', type: 'cash'),
      FinanceAccount(id: 'bank', name: 'Banco', type: 'checking'),
    ]);

    final selector = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('operation_account_selector_none')),
    );
    expect(selector.initialValue, isNull);
  });

  testWidgets('preserves an explicitly preselected account when there are several', (tester) async {
    await _pumpOperationForm(
      tester,
      const [
        FinanceAccount(id: 'cash', name: 'Efectivo', type: 'cash'),
        FinanceAccount(id: 'bank', name: 'Banco', type: 'checking'),
      ],
      initialAccountId: 'bank',
    );

    final selector = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('operation_account_selector_bank')),
    );
    expect(selector.initialValue, 'bank');
  });

  testWidgets('budget item form preloads editable values and limits accounts to its currency', (
    tester,
  ) async {
    const preset = BudgetItemMovementPreset(
      budgetId: '2026-10_expense_food_COP',
      itemId: 'item-1',
      type: OperationType.expense,
      categoryId: 'food',
      currency: 'COP',
      description: 'Mercado semanal',
      amountMinor: 300000,
    );
    await _pumpOperationForm(
      tester,
      const [
        FinanceAccount(id: 'cash', name: 'Efectivo', type: 'cash', currency: 'COP'),
        FinanceAccount(id: 'bank', name: 'Banco', type: 'checking', currency: 'COP'),
        FinanceAccount(id: 'mxn', name: 'Cuenta MX', type: 'checking', currency: 'MXN'),
      ],
      preset: preset,
      categories: const [
        FinanceCategory(
          id: 'food',
          type: CategoryType.expense,
          icon: 'food',
          sortOrder: 1,
          isSystem: true,
          isArchived: false,
          customName: 'Comida',
        ),
      ],
    );

    expect(
      tester.widget<TextFormField>(find.byKey(const ValueKey('operation_amount'))).controller!.text,
      '300000',
    );
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('operation_description')))
          .controller!
          .text,
      'Mercado semanal',
    );
    final accountDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('operation_account_selector_none')),
    );
    expect(accountDropdown.onChanged, isNotNull);
    await tester.tap(find.byKey(const ValueKey('operation_account_selector_none')));
    await tester.pumpAndSettle();
    expect(find.text('Efectivo (COP)'), findsOneWidget);
    expect(find.text('Banco (COP)'), findsOneWidget);
    expect(find.text('Cuenta MX (MXN)'), findsNothing);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('operation_category_selector')),
          )
          .onChanged,
      isNull,
    );
    expect(find.byKey(const ValueKey('budget_item_movement_context')), findsOneWidget);
  });

  testWidgets('budget item form explains when no active account uses the budget currency', (
    tester,
  ) async {
    const preset = BudgetItemMovementPreset(
      budgetId: '2026-10_expense_food_COP',
      itemId: 'item-1',
      type: OperationType.expense,
      categoryId: 'food',
      currency: 'COP',
      description: 'Mercado semanal',
      amountMinor: 300000,
    );
    await _pumpOperationForm(
      tester,
      const [FinanceAccount(id: 'mxn', name: 'Cuenta MX', type: 'checking', currency: 'MXN')],
      preset: preset,
      categories: const [
        FinanceCategory(
          id: 'food',
          type: CategoryType.expense,
          icon: 'food',
          sortOrder: 1,
          isSystem: true,
          isArchived: false,
        ),
      ],
    );
    expect(find.byKey(const ValueKey('budget_item_add_compatible_account')), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
    expect(find.byKey(const ValueKey('operation_save')), findsOneWidget);
  });

  testWidgets('opens category management without losing the operation draft', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/operations/new',
      routes: [
        GoRoute(
          path: '/operations/new',
          builder: (context, state) => const CanonicalOperationFormScreen(),
        ),
        GoRoute(
          path: '/categories',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Category management route')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
          ),
          canonicalAccountsProvider('user-1').overrideWith(
            (ref) =>
                Stream.value(const [FinanceAccount(id: 'cash', name: 'Efectivo', type: 'cash')]),
          ),
          canonicalCategoriesProvider('user-1').overrideWith(
            (ref) => Stream.value(const [
              FinanceCategory(
                id: 'food',
                type: CategoryType.expense,
                icon: 'food',
                sortOrder: 1,
                isSystem: true,
                isArchived: false,
                customName: 'Comida',
              ),
            ]),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final amountField = find.byKey(const ValueKey('operation_amount'));
    await tester.enterText(amountField, '250');
    await tester.tap(find.byKey(const ValueKey('operation_manage_categories')));
    await tester.pumpAndSettle();
    expect(find.text('Category management route'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(amountField).controller!.text, '250');
    expect(find.byKey(const ValueKey('operation_manage_categories')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpOperationForm(
  WidgetTester tester,
  List<FinanceAccount> accounts, {
  OperationType initialType = OperationType.expense,
  String? initialAccountId,
  FinancialOperation? initialOperation,
  BudgetItemMovementPreset? preset,
  List<FinanceCategory> categories = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/operations/new',
    routes: [
      GoRoute(
        path: '/operations/new',
        builder: (context, state) => CanonicalOperationFormScreen(
          initialType: initialType,
          initialAccountId: initialAccountId,
          initialOperation: initialOperation,
          initialBudgetItemPreset: preset,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
        ),
        canonicalAccountsProvider('user-1').overrideWith((ref) => Stream.value(accounts)),
        canonicalCategoriesProvider('user-1').overrideWith(
          (ref) => Stream.value(categories),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpTransferForm(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: true)),
        ),
        canonicalAccountsProvider('user-1').overrideWith(
          (ref) => Stream.value(const [
            FinanceAccount(id: 'cash', name: 'Efectivo', type: 'cash'),
            FinanceAccount(id: 'bank', name: 'Banco', type: 'checking'),
          ]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CanonicalTransferScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
