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
import 'package:personal_finance/features/finance/presentation/screens/canonical_budgets_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

final _month = DateFormat('yyyy-MM').format(DateTime.now());
const _budgets = [
  Budget(
    id: 'food-budget',
    categoryId: 'food',
    flowType: BudgetFlowType.expense,
    monthKey: 'unused',
    currency: 'COP',
    plannedAmountMinor: 50000,
    status: 'active',
  ),
  Budget(
    id: 'salary-budget',
    categoryId: 'salary',
    flowType: BudgetFlowType.income,
    monthKey: 'unused',
    currency: 'COP',
    plannedAmountMinor: 100000,
    status: 'active',
  ),
  Budget(
    id: 'home-budget',
    categoryId: 'home',
    flowType: BudgetFlowType.expense,
    monthKey: 'unused',
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
  FinanceCategory(
    id: 'home',
    type: CategoryType.expense,
    icon: 'home',
    sortOrder: 3,
    isSystem: true,
    isArchived: false,
    customName: 'Vivienda',
  ),
];

MonthlySummary _summary(String currency) => MonthlySummary(
  monthKey: 'unused',
  currency: currency,
  incomeMinor: 0,
  expenseMinor: 0,
  transferInMinor: 0,
  transferOutMinor: 0,
  byCategory: {'food': -32000, 'salary': 120000, 'home': -120000},
);

void main() {
  Widget subject({
    List<Budget> budgets = _budgets,
    Locale locale = const Locale('es'),
    double textScale = 1,
    bool budgetError = false,
  }) {
    final router = GoRouter(
      initialLocation: '/budgets',
      routes: [
        GoRoute(
          path: '/budgets',
          builder: (context, state) => const CanonicalBudgetsScreen(),
          routes: [
            GoRoute(
              path: 'tracking',
              builder: (context, state) => CanonicalBudgetTrackingScreen(
                initialMonthKey: state.uri.queryParameters['month'],
              ),
            ),
          ],
        ),
        GoRoute(path: '/budgets/new', builder: (context, state) => const Text('Create route')),
        GoRoute(
          path: '/budgets/:id',
          builder: (context, state) => Text('Detail ${state.pathParameters['id']}'),
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
              : Stream.value(input.monthKey == _month ? budgets : const <Budget>[]),
        ),
        canonicalCategoriesProvider.overrideWith((ref, userId) => Stream.value(_categories)),
        canonicalAccountsProvider.overrideWith(
          (ref, userId) => Stream.value(const <FinanceAccount>[]),
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
          (ref, input) => Stream.value(_summary(input.currency)),
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

  testWidgets('shows the empty-month message and a single create action', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(subject(budgets: const []));
    await tester.pumpAndSettle();

    expect(find.text('Tus presupuestos'), findsOneWidget);
    expect(find.text('Aún no tienes presupuestos'), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_empty_create')), findsOneWidget);
    expect(find.byKey(const ValueKey('budgets_manage_categories')), findsOneWidget);
    expect(find.byKey(const ValueKey('budgets_create_button')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('budget_empty_create')));
    await tester.pumpAndSettle();
    expect(find.text('Create route'), findsOneWidget);
  });

  testWidgets('renders independent currency cards with calculated actual and remaining', (
    tester,
  ) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Salario'), findsOneWidget);
    expect(find.text('Vivienda'), findsOneWidget);
    expect(find.textContaining('Gastado'), findsNWidgets(2));
    expect(find.textContaining('Recibido'), findsOneWidget);
    expect(find.textContaining('Restante'), findsOneWidget);
    expect(find.textContaining('Excedido'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('budget_card_progress_food-budget')), findsOneWidget);
    expect(find.byKey(const ValueKey('budgets_manage_categories')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('budget_card_tap_food-budget')));
    await tester.pumpAndSettle();
    expect(find.text('Detail food-budget'), findsOneWidget);
  });

  testWidgets('opens tracking with the selected month from the monthly budget list', (
    tester,
  ) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('budgets_view_tracking')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('budget_tracking_title')), findsOneWidget);
    expect(find.byKey(const ValueKey('budget_tracking_month')), findsOneWidget);
  });

  testWidgets('filters expenses and income and restores all from filter empty', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(subject(budgets: [_budgets[1]]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('budget_filter_expenses')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('budget_filtered_empty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('budget_filter_reset')));
    await tester.pumpAndSettle();
    expect(find.text('Salario'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('budget_filter_income')));
    await tester.pumpAndSettle();
    expect(find.text('Salario'), findsOneWidget);
  });

  testWidgets('month selector reloads empty month; error offers retry', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(subject(budgets: const []));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_list_month')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('budget_empty_title')), findsOneWidget);
  });

  testWidgets('load error offers a recovery action', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(subject(budgetError: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('budgets_retry')), findsOneWidget);
  });

  testWidgets('supports Portuguese, English, compact width and enlarged text', (tester) async {
    setScreen(tester, const Size(360, 760));
    await tester.pumpWidget(subject(locale: const Locale('pt'), textScale: 1.5));
    await tester.pumpAndSettle();
    expect(find.text('Seus orçamentos'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(subject(locale: const Locale('en'), textScale: 1.2));
    await tester.pumpAndSettle();
    expect(find.text('Your budgets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
