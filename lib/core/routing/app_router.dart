import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

GoRouter get appRouter => _router ??= _buildAppRouter();

GoRouter _buildAppRouter() => GoRouter(
  initialLocation: '/login',
  refreshListenable: AuthRefreshListenable(FirebaseAuth.instance.authStateChanges()),
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final authenticated = user != null;
    final isLogin = state.matchedLocation == '/login';
    if (!authenticated && !isLogin) return '/login';
    if (user != null && (isLogin || state.matchedLocation == '/home')) {
      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final onboardingComplete = profile.data()?['onboardingStatus'] == 'complete';
      if (!onboardingComplete && state.matchedLocation != '/onboarding') return '/onboarding';
      if (onboardingComplete && isLogin) return '/home';
    }
    return null;
  },
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
