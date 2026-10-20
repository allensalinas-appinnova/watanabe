import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/finance/domain/entities/budget.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_flow_type.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_category.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/monthly_summary.dart';
import 'package:personal_finance/features/finance/domain/entities/operation_page.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_home_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('renders the home dashboard with distinct balance, budget and recent activity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final providers = ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(id: 'u1', isAnonymous: false)),
        ),
        pendingOperationAutoSyncProvider.overrideWith((ref) {}),
        pendingOperationsProvider.overrideWith((ref) => Stream.value(const [])),
        canonicalAccountsProvider('u1').overrideWith(
          (ref) => Stream.value([
            const FinanceAccount(
              id: 'bank',
              name: 'Banco1',
              type: 'savings',
              currency: 'COP',
              currentBalanceMinor: 2000,
            ),
          ]),
        ),
        canonicalCategoriesProvider('u1').overrideWith(
          (ref) => Stream.value([
            const FinanceCategory(
              id: 'food',
              type: CategoryType.expense,
              icon: 'food',
              sortOrder: 0,
              isSystem: true,
              isArchived: false,
              customName: 'Comida',
            ),
            const FinanceCategory(
              id: 'salary',
              type: CategoryType.income,
              icon: 'salary',
              sortOrder: 1,
              isSystem: true,
              isArchived: false,
              customName: 'Salario',
            ),
          ]),
        ),
        canonicalMonthlySummaryProvider((
          userId: 'u1',
          monthKey: monthKey,
          currency: 'COP',
        )).overrideWith(
          (ref) => Stream.value(
            MonthlySummary(
              monthKey: monthKey,
              currency: 'COP',
              incomeMinor: 10000,
              expenseMinor: 8000,
              transferInMinor: 0,
              transferOutMinor: 0,
              byCategory: const {'food': -8000},
            ),
          ),
        ),
        canonicalBudgetsProvider((userId: 'u1', monthKey: monthKey)).overrideWith(
          (ref) => Stream.value([
            Budget(
              id: 'food-budget',
              categoryId: 'food',
              flowType: BudgetFlowType.expense,
              monthKey: monthKey,
              currency: 'COP',
              plannedAmountMinor: 10000,
              status: 'active',
            ),
          ]),
        ),
        canonicalOperationsPageProvider((
          userId: 'u1',
          cursor: null,
          monthKey: null,
          currency: null,
          type: null,
          accountIds: null,
          pageSize: 10,
        )).overrideWith(
          (ref) async => OperationPage(
            items: [
              FinancialOperation(
                id: 'op-1',
                type: OperationType.income,
                amountMinor: 10000,
                currency: 'COP',
                monthKey: monthKey,
                occurredAt: now,
                status: OperationStatus.confirmed,
                idempotencyKey: 'i1',
                categoryId: 'salary',
                accountId: 'bank',
                description: 'Salario',
              ),
            ],
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.25)),
          child: child!,
        ),
        home: const CanonicalHomeScreen(),
      ),
    );

    await tester.pumpWidget(providers);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_dashboard_title')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_balance_card')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_income_summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_expense_summary')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('home_budget_preview')));
    expect(find.byKey(const ValueKey('home_budget_preview')), findsOneWidget);
    expect(find.text('Presupuesto del mes'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('home_view_all_activity')));
    expect(find.byKey(const ValueKey('home_view_all_activity')), findsOneWidget);
    expect(find.text('Actividad reciente'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('home_toggle_amount_visibility')));
    await tester.tap(find.byKey(const ValueKey('home_toggle_amount_visibility')));
    await tester.pumpAndSettle();
    expect(find.text('••••••'), findsAtLeastNWidgets(1));
    expect(find.byKey(const ValueKey('home_toggle_amount_visibility')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('home_toggle_amount_visibility')));
    await tester.tap(find.byKey(const ValueKey('home_toggle_amount_visibility')));
    await tester.pumpAndSettle();
    expect(find.text('••••••'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
