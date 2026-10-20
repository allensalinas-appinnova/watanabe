import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/budget.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_flow_type.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_category.dart';
import 'package:personal_finance/features/finance/domain/entities/monthly_summary.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_budget_tracking_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

const _budgets = [
  Budget(
    id: 'food-budget',
    categoryId: 'food',
    flowType: BudgetFlowType.expense,
    monthKey: '2026-03',
    currency: 'COP',
    plannedAmountMinor: 50000,
    status: 'active',
  ),
  Budget(
    id: 'salary-budget',
    categoryId: 'salary',
    flowType: BudgetFlowType.income,
    monthKey: '2026-03',
    currency: 'MXN',
    plannedAmountMinor: 100000,
    status: 'active',
  ),
];

const _categories = [
  FinanceCategory(
    id: 'food',
    type: CategoryType.expense,
    icon: 'restaurant',
    sortOrder: 1,
    isSystem: true,
    isArchived: false,
    customName: 'Comida',
  ),
  FinanceCategory(
    id: 'salary',
    type: CategoryType.income,
    icon: 'payments',
    sortOrder: 2,
    isSystem: true,
    isArchived: false,
    customName: 'Salario',
  ),
];
final _currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

MonthlySummary _summary(String currency) => MonthlySummary(
  monthKey: '2026-03',
  currency: currency,
  incomeMinor: currency == 'MXN' ? 150000 : 0,
  expenseMinor: currency == 'COP' ? 50000 : 0,
  transferInMinor: 90000,
  transferOutMinor: 90000,
  byCategory: currency == 'MXN'
      ? {'salary': 120000, 'other-income': 30000}
      : {'food': -32000, 'transport': -18000},
);

MonthlySummary _emptySummary(String currency) => MonthlySummary(
  monthKey: '2026-03',
  currency: currency,
  incomeMinor: 0,
  expenseMinor: 0,
  transferInMinor: 90000,
  transferOutMinor: 90000,
  byCategory: const {},
);

void main() {
  Widget subject({
    List<Budget> budgets = _budgets,
    Locale locale = const Locale('es'),
    bool budgetError = false,
    double textScale = 1,
    bool includeUnbudgetedActivity = false,
  }) {
    final router = GoRouter(
      initialLocation: '/budgets/tracking?month=2026-03',
      routes: [
        GoRoute(
          path: '/budgets',
          builder: (context, state) => const Scaffold(body: Text('Budgets list')),
          routes: [
            GoRoute(
              path: 'tracking',
              builder: (context, state) => CanonicalBudgetTrackingScreen(
                initialMonthKey: state.uri.queryParameters['month'],
              ),
            ),
            GoRoute(
              path: 'new',
              builder: (context, state) => const Scaffold(body: Text('Create budget')),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => Scaffold(
                body: Column(
                  children: [
                    IconButton(
                      onPressed: context.pop,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Text('Detail ${state.pathParameters['id']}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(id: 'user-1', isAnonymous: false)),
        ),
        canonicalBudgetsProvider.overrideWith(
          (ref, input) => budgetError
              ? Stream.error(StateError('load failed'))
              : Stream.value(
                  input.monthKey == '2026-03' || input.monthKey == _currentMonth
                      ? budgets
                      : const <Budget>[],
                ),
        ),
        canonicalCategoriesProvider.overrideWith((ref, userId) => Stream.value(_categories)),
        canonicalAccountsProvider.overrideWith(
          (ref, userId) => Stream.value(const [
            FinanceAccount(id: 'cop-account', name: 'COP', type: 'cash', currency: 'COP'),
            FinanceAccount(id: 'mxn-account', name: 'MXN', type: 'checking', currency: 'MXN'),
          ]),
        ),
        canonicalUserProfileProvider.overrideWith(
          (ref, userId) => Stream.value(
            const UserProfile(
              id: 'user-1',
              locale: 'es',
              countryCode: 'CO',
              timeZone: 'America/Bogota',
              defaultCurrency: 'COP',
              onboardingStatus: 'complete',
              categoryCatalogVersion: 1,
            ),
          ),
        ),
        canonicalMonthlySummaryProvider.overrideWith(
          (ref, input) => Stream.value(
            budgets.isEmpty && !includeUnbudgetedActivity
                ? _emptySummary(input.currency)
                : _summary(input.currency),
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: locale,
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
  }

  void setScreen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('separates currencies and income/expense, and opens category detail', (
    tester,
  ) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('COP · Gasto'), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_tracking_category_food-budget')), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_tracking_progress_COP_expense')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('budget_tracking_actual_COP_expense'))).data,
      contains('32.000'),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('budget_tracking_unbudgeted_amount_COP_expense')),
          )
          .data,
      contains('18.000'),
    );
    expect(find.textContaining('Restante'), findsWidgets);
    expect(find.textContaining('COP'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('budget_tracking_category_food-budget')));
    await tester.pumpAndSettle();
    expect(find.text('Detail food-budget'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('budget_tracking_title')), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_tracking_month')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('MXN · Ingreso'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('MXN · Ingreso'), findsOneWidget);
    expect(find.text('Salario'), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_tracking_progress_MXN_income')), findsOneWidget);
    final incomeRemaining = tester.widget<Text>(
      find.byKey(const ValueKey('budget_tracking_remaining_MXN_income')),
    );
    expect(incomeRemaining.data, contains('200,00'));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('budget_tracking_actual_MXN_income'))).data,
      contains('1.200,00'),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('budget_tracking_unbudgeted_amount_MXN_income')),
          )
          .data,
      contains('300,00'),
    );
  });

  testWidgets('empty state keeps month selection and opens budget creation', (tester) async {
    setScreen(tester, const Size(360, 760));
    await tester.pumpWidget(subject(budgets: const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('budget_tracking_empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_tracking_month')), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_tracking_empty_create')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('budget_tracking_empty_create')));
    await tester.pumpAndSettle();
    expect(find.text('Create budget'), findsOneWidget);
  });

  testWidgets('shows unbudgeted activity even when no budget exists and excludes transfers', (
    tester,
  ) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(subject(budgets: const [], includeUnbudgetedActivity: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('budget_tracking_empty')), findsNothing);
    expect(find.text('COP · Gasto'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('MXN · Ingreso'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('MXN · Ingreso'), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_tracking_review_categories')), findsNWidgets(2));
    // With no budgets, all normal flow activity is shown separately as unbudgeted.
    final incomeRemaining = tester.widget<Text>(
      find.byKey(const ValueKey('budget_tracking_remaining_MXN_income')),
    );
    final actualIncome = tester.widget<Text>(
      find.byKey(const ValueKey('budget_tracking_actual_MXN_income')),
    );
    expect(actualIncome.data, contains('0,00'));
    expect(incomeRemaining.data, contains('Movimientos sin presupuesto'));
    expect(find.byKey(const ValueKey('budget_tracking_progress_MXN_income')), findsNothing);
    final unbudgetedAmounts = tester.widgetList<Text>(
      find.byKey(const ValueKey('budget_tracking_unbudgeted_amount_MXN_income')),
    );
    expect(unbudgetedAmounts.single.data, contains('1.500,00'));
  });

  testWidgets('load failure exposes retry and layout supports Portuguese enlarged text', (
    tester,
  ) async {
    setScreen(tester, const Size(360, 760));
    await tester.pumpWidget(subject(budgetError: true, locale: const Locale('pt'), textScale: 1.5));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('budget_tracking_retry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
