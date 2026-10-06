import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/finance/domain/entities/financial_operation.dart';
import '../../features/finance/presentation/screens/canonical_accounts_screen.dart';
import '../../features/finance/presentation/screens/canonical_budget_detail_screen.dart';
import '../../features/finance/presentation/screens/canonical_budget_tracking_screen.dart';
import '../../features/finance/presentation/screens/canonical_budgets_screen.dart';
import '../../features/finance/presentation/screens/canonical_categories_screen.dart';
import '../../features/finance/presentation/screens/canonical_home_screen.dart';
import '../../features/finance/presentation/screens/canonical_onboarding_screen.dart';
import '../../features/finance/presentation/screens/canonical_operation_form_screen.dart';
import '../../features/finance/presentation/screens/canonical_transfer_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const CanonicalHomeScreen(),
    ),
    GoRoute(
      path: '/activity',
      name: 'activity',
      builder: (context, state) => const CanonicalHomeScreen(),
    ),
    GoRoute(
      path: '/budgets',
      name: 'budgets',
      builder: (context, state) => const CanonicalBudgetsScreen(),
    ),
    GoRoute(
      path: '/budgets/:id',
      name: 'budget-detail',
      builder: (context, state) => CanonicalBudgetDetailScreen(
        budgetId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/accounts',
      name: 'accounts',
      builder: (context, state) => const CanonicalAccountsScreen(),
    ),
    GoRoute(
      path: '/expense/new',
      name: 'new-expense',
      builder: (context, state) => CanonicalOperationFormScreen(
        initialType: state.uri.queryParameters['type'] == 'income'
            ? OperationType.income
            : OperationType.expense,
      ),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const CanonicalOnboardingScreen(),
    ),
    GoRoute(
      path: '/categories',
      name: 'categories',
      builder: (context, state) => const CanonicalCategoriesScreen(),
    ),
    GoRoute(
      path: '/budget-tracking',
      name: 'budget-tracking',
      builder: (context, state) => const CanonicalBudgetTrackingScreen(),
    ),
    GoRoute(
      path: '/operations/new',
      name: 'new-operation',
      builder: (context, state) => CanonicalOperationFormScreen(
        initialType: state.uri.queryParameters['type'] == 'income'
            ? OperationType.income
            : OperationType.expense,
      ),
    ),
    GoRoute(
      path: '/transfers/new',
      name: 'new-transfer',
      builder: (context, state) => const CanonicalTransferScreen(),
    ),
  ],
);
