import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/guest_account_upgrade_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/session_recovery_screen.dart';
import '../../features/coach/domain/entities/coach_models.dart';
import '../../features/coach/presentation/screens/coach_home_screen.dart';
import '../../features/coach/presentation/screens/coach_review_screen.dart';
import '../../features/coach/presentation/screens/coach_settings_screen.dart';
import '../../features/commitments/presentation/debt_commitments_screen.dart';
import '../../features/debts/presentation/debt_detail_screen.dart';
import '../../features/debts/presentation/debt_form_screen.dart';
import '../../features/debts/presentation/debt_payment_picker_screen.dart';
import '../../features/devices/presentation/my_devices_screen.dart';
import '../../features/finance/domain/entities/budget_item.dart';
import '../../features/finance/domain/entities/finance_account.dart';
import '../../features/finance/domain/entities/financial_operation.dart';
import '../../features/finance/domain/entities/user_profile.dart';
import '../../features/finance/domain/repositories/canonical_finance_repository.dart';
import '../../features/finance/presentation/models/budget_item_movement_preset.dart';
import '../../features/finance/presentation/screens/account_form_screen.dart';
import '../../features/finance/presentation/screens/activity_filters_screen.dart';
import '../../features/finance/presentation/screens/appearance_settings_screen.dart';
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
import '../../features/finance/presentation/screens/home_dashboard_preferences_screen.dart';
import '../../features/finance/presentation/screens/money_account_detail_screen.dart';
import '../../features/finance/presentation/screens/operation_edit_route_screen.dart';
import '../../features/finance/presentation/screens/user_data_reset_screen.dart';
import '../di/injection.dart';
import '../firebase/firebase_bootstrap.dart';
import 'app_shell.dart';
import 'authenticated_route_resolver.dart';

class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable(
    Stream<User?> stream, {
    required Stream<UserProfile?> Function(String userId) profileStream,
  }) : _profileStream = profileStream {
    _subscription = stream.listen(_onAuthChanged);
  }

  final Stream<UserProfile?> Function(String userId) _profileStream;
  late final StreamSubscription<User?> _subscription;
  StreamSubscription<UserProfile?>? _profileSubscription;

  void _onAuthChanged(User? user) {
    _profileSubscription?.cancel();
    _profileSubscription = user == null
        ? null
        : _profileStream(user.uid).listen(
            (_) {
              invalidateCachedUserProfile(user.uid);
              notifyListeners();
            },
            onError: (Object _) {
              // The route resolver owns recovery UI for profile read failures.
              notifyListeners();
            },
          );
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _profileSubscription?.cancel();
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
    FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).userChanges(),
    profileStream: (userId) => getIt<CanonicalFinanceRepository>().watchUserProfile(userId),
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
      path: '/coach/daily',
      name: 'coach-daily',
      builder: (context, state) => CoachReviewScreen(
        kind: CoachReviewKind.daily,
        periodKey: state.uri.queryParameters['date'],
      ),
    ),
    GoRoute(
      path: '/coach/weekly',
      name: 'coach-weekly',
      builder: (context, state) => CoachReviewScreen(
        kind: CoachReviewKind.weekly,
        periodKey: state.uri.queryParameters['date'],
      ),
    ),
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
    GoRoute(
      path: '/settings/reset-in-progress',
      name: 'reset-in-progress',
      builder: (context, state) => const UserDataResetScreen(resumeOnly: true),
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
              path: '/accounts',
              name: 'accounts',
              builder: (context, state) => CanonicalAccountsScreen(
                initialSection: state.uri.queryParameters['section'],
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  name: 'new-account',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => AccountFormScreen(
                    initialCurrency: state.uri.queryParameters['currency'],
                  ),
                ),
                GoRoute(
                  path: ':id/debt',
                  builder: (context, state) =>
                      DebtDetailScreen(accountId: state.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'pay-debt',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const DebtPaymentPickerScreen(),
                ),
                GoRoute(
                  path: ':id',
                  name: 'money-account-detail',
                  builder: (context, state) => MoneyAccountDetailScreen(
                    accountId: state.pathParameters['id']!,
                  ),
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
                  path: 'debt-payments',
                  name: 'debt-commitments',
                  builder: (context, state) => DebtCommitmentsScreen(
                    initialMonthKey: state.uri.queryParameters['month'],
                  ),
                  routes: [
                    GoRoute(
                      path: 'new',
                      name: 'new-debt-commitment',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) => DebtCommitmentFormScreen(
                        initialDebtAccountId: state.uri.queryParameters['debtAccountId'],
                      ),
                    ),
                  ],
                ),
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
                  builder: (context, state) =>
                      CanonicalBudgetDetailScreen(budgetId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'items/new',
                      name: 'new-budget-item',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) =>
                          CanonicalBudgetItemEditScreen(budgetId: state.pathParameters['id']!),
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
              path: '/coach',
              name: 'coach',
              builder: (context, state) => const CoachHomeScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/debts/new', builder: (context, state) => const DebtFormScreen()),
    GoRoute(
      path: '/debts/:id/actions/:action',
      builder: (context, state) => DebtFormScreen(
        accountId: state.pathParameters['id'],
        action: state.pathParameters['action']!,
        originalOperationId: state.uri.queryParameters['original'],
        commitmentId: state.uri.queryParameters['commitmentId'],
        commitmentMonth: state.uri.queryParameters['month'],
        commitmentAmountMinor: int.tryParse(state.uri.queryParameters['amountMinor'] ?? ''),
        commitmentBankAccountId: state.uri.queryParameters['bankAccountId'],
        initialComponents: state.extra is List<FinancialOperation>
            ? state.extra! as List<FinancialOperation>
            : const [],
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
        initialOccurredAt: DateTime.tryParse(state.uri.queryParameters['occurredAt'] ?? ''),
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
      redirect: (context, state) => state.uri.replace(path: '/settings').toString(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const CanonicalMoreScreen(),
    ),
    GoRoute(
      path: '/settings/appearance',
      name: 'settings-appearance',
      builder: (context, state) => const AppearanceSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/devices',
      name: 'settings-devices',
      builder: (context, state) => const MyDevicesScreen(),
    ),
    GoRoute(
      path: '/settings/secure-account',
      name: 'settings-secure-account',
      builder: (context, state) => const GuestAccountUpgradeScreen(),
    ),
    GoRoute(
      path: '/settings/reset-data',
      name: 'reset-user-data',
      builder: (context, state) => const UserDataResetScreen(),
    ),
    GoRoute(
      path: '/coach/settings',
      name: 'coach-settings',
      builder: (context, state) => const CoachSettingsScreen(),
    ),
    GoRoute(
      path: '/categories',
      name: 'categories',
      builder: (context, state) => const CanonicalCategoriesScreen(),
    ),
    GoRoute(
      path: '/home-preferences',
      name: 'home-preferences',
      builder: (context, state) => const HomeDashboardPreferencesScreen(),
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
        initialOccurredAt: DateTime.tryParse(state.uri.queryParameters['occurredAt'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/operations/:id/edit',
      name: 'edit-operation',
      builder: (context, state) => OperationEditRouteScreen(
        operationId: state.pathParameters['id']!,
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
        initialOccurredAt: DateTime.tryParse(state.uri.queryParameters['occurredAt'] ?? ''),
      ),
    ),
  ],
);
