import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/session_recovery_screen.dart';
import '../../features/finance/domain/entities/budget_item.dart';
import '../../features/finance/domain/entities/finance_account.dart';
import '../../features/finance/domain/entities/financial_operation.dart';
import '../../features/finance/domain/repositories/canonical_finance_repository.dart';
import '../../features/finance/presentation/models/budget_item_movement_preset.dart';
import '../../features/finance/presentation/screens/account_form_screen.dart';
import '../../features/finance/presentation/screens/activity_filters_screen.dart';
import '../../features/finance/presentation/screens/canonical_accounts_screen.dart';
import '../../features/finance/presentation/screens/canonical_activity_screen.dart';
import '../../features/finance/presentation/screens/canonical_budget_create_screen.dart';
import '../../features/finance/presentation/screens/canonical_budget_detail_screen.dart';
import '../../features/finance/presentation/screens/canonical_budget_item_edit_screen.dart';
import '../../features/finance/presentation/screens/canonical_budget_tracking_screen.dart';
import '../../features/finance/presentation/screens/canonical_budgets_screen.dart';
import '../../features/finance/presentation/screens/canonical_categories_screen.dart';
import '../../features/finance/presentation/screens/canonical_home_screen.dart';
import '../../features/finance/presentation/screens/canonical_more_screen.dart';
import '../../features/finance/presentation/screens/canonical_onboarding_screen.dart';
import '../../features/finance/presentation/screens/canonical_operation_form_screen.dart';
import '../../features/finance/presentation/screens/canonical_transfer_screen.dart';
import '../di/injection.dart';
import '../firebase/firebase_bootstrap.dart';
import 'app_shell.dart';
import 'authenticated_route_resolver.dart';

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
  refreshListenable: AuthRefreshListenable(
    FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).authStateChanges(),
  ),
  redirect: (context, state) async {
    final user = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).currentUser;
    return resolveAuthenticatedRoute(
      authenticated: user != null,
      matchedLocation: state.matchedLocation,
      loadProfile: () => loadCachedUserProfile(
        user!.uid,
        () => getIt<CanonicalFinanceRepository>().watchUserProfile(user.uid).first,
      ),
    );
  },
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/session-recovery',
      name: 'session-recovery',
      builder: (context, state) => const SessionRecoveryScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(
        navigationShell: navigationShell,
        currentLocation: state.uri.path,
      ),
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
              routes: [
                GoRoute(
                  path: 'filters',
                  name: 'activity-filters',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const ActivityFiltersScreen(),
                ),
              ],
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
                    GoRoute(
                      path: 'items/:itemId/record',
                      name: 'record-budget-item-movement',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) => CanonicalOperationFormScreen(
                        initialType: state.extra is BudgetItemMovementPreset
                            ? (state.extra! as BudgetItemMovementPreset).type
                            : OperationType.expense,
                        initialBudgetItemPreset: state.extra is BudgetItemMovementPreset
                            ? state.extra! as BudgetItemMovementPreset
                            : null,
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
      builder: (context, state) => AccountFormScreen(
        initialCurrency: state.uri.queryParameters['currency'],
      ),
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
        initialAccountId: state.uri.queryParameters['accountId'],
        initialCategoryId: state.uri.queryParameters['categoryId'],
      ),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const CanonicalOnboardingScreen(),
    ),
    GoRoute(
      path: '/more',
      name: 'more',
      builder: (context, state) => const CanonicalMoreScreen(),
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
        initialAccountId: state.uri.queryParameters['accountId'],
        initialCategoryId: state.uri.queryParameters['categoryId'],
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
      builder: (context, state) => CanonicalTransferScreen(
        initialSourceAccountId: state.uri.queryParameters['sourceAccountId'],
      ),
    ),
  ],
);
