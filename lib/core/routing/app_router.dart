import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/finance/domain/entities/budget_item.dart';
import '../../features/finance/domain/entities/finance_account.dart';
import '../../features/finance/domain/entities/financial_operation.dart';
import '../../features/finance/presentation/screens/account_form_screen.dart';
import '../../features/finance/presentation/screens/canonical_accounts_screen.dart';
import '../../features/finance/presentation/screens/canonical_activity_screen.dart';
import '../../features/finance/presentation/screens/canonical_budget_create_screen.dart';
import '../../features/finance/presentation/screens/canonical_budget_detail_screen.dart';
import '../../features/finance/presentation/screens/canonical_budget_item_edit_screen.dart';
import '../../features/finance/presentation/screens/canonical_budget_tracking_screen.dart';
import '../../features/finance/presentation/screens/canonical_budgets_screen.dart';
import '../../features/finance/presentation/screens/canonical_categories_screen.dart';
import '../../features/finance/presentation/screens/canonical_home_screen.dart';
import '../../features/finance/presentation/screens/canonical_onboarding_screen.dart';
import '../../features/finance/presentation/screens/canonical_operation_form_screen.dart';
import '../../features/finance/presentation/screens/canonical_transfer_screen.dart';
import 'app_shell.dart';

class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable(Stream<User?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter? _router;
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNavigator');

GoRouter get appRouter => _router ??= _buildAppRouter();

GoRouter _buildAppRouter() => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  refreshListenable: AuthRefreshListenable(FirebaseAuth.instance.authStateChanges()),
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final authenticated = user != null;
    final isLogin = state.matchedLocation == '/login';
    if (!authenticated && !isLogin) return '/login';
    final isOnboarding = state.matchedLocation == '/onboarding';
    if (user != null && !isLogin) {
      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final onboardingComplete = profile.data()?['onboardingStatus'] == 'complete';
      if (!onboardingComplete && !isOnboarding) return '/onboarding';
      if (onboardingComplete && isOnboarding) return '/home';
    } else if (user != null && isLogin) {
      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (profile.data()?['onboardingStatus'] == 'complete') return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const CanonicalHomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/activity',
              name: 'activity',
              builder: (context, state) => const CanonicalActivityScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/budgets',
              name: 'budgets',
              builder: (context, state) => const CanonicalBudgetsScreen(),
              routes: [
                GoRoute(
                  path: 'tracking',
                  name: 'budget-tracking',
                  builder: (context, state) => CanonicalBudgetTrackingScreen(
                    initialMonthKey: state.uri.queryParameters['month'],
                  ),
                ),
                GoRoute(
                  path: 'new',
                  name: 'new-budget',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const CanonicalBudgetCreateScreen(),
                ),
                GoRoute(
                  path: ':id',
                  name: 'budget-detail',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => CanonicalBudgetDetailScreen(
                    budgetId: state.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'items/new',
                      name: 'new-budget-item',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) => CanonicalBudgetItemEditScreen(
                        budgetId: state.pathParameters['id']!,
                      ),
                    ),
                    GoRoute(
                      path: 'items/:itemId/edit',
                      name: 'edit-budget-item',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) => CanonicalBudgetItemEditScreen(
                        budgetId: state.pathParameters['id']!,
                        itemId: state.pathParameters['itemId']!,
                        initialItem: state.extra is BudgetItem ? state.extra! as BudgetItem : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/accounts',
              name: 'accounts',
              builder: (context, state) => const CanonicalAccountsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/accounts/new',
      name: 'new-account',
      builder: (context, state) => const AccountFormScreen(),
    ),
    GoRoute(
      path: '/accounts/:id/edit',
      name: 'edit-account',
      builder: (context, state) => AccountFormScreen(
        accountId: state.pathParameters['id'],
        initialAccount: state.extra is FinanceAccount ? state.extra! as FinanceAccount : null,
      ),
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
      redirect: (context, state) => state.uri.replace(path: '/budgets/tracking').toString(),
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
      path: '/operations/:id/edit',
      name: 'edit-operation',
      builder: (context, state) => CanonicalOperationFormScreen(
        initialOperation: state.extra is FinancialOperation
            ? state.extra! as FinancialOperation
            : null,
      ),
    ),
    GoRoute(
      path: '/transfers/new',
      name: 'new-transfer',
      builder: (context, state) => const CanonicalTransferScreen(),
    ),
  ],
);
