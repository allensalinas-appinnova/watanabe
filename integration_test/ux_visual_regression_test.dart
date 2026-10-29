import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_finance/app.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/firebase/firebase_bootstrap.dart';
import 'package:personal_finance/core/routing/app_router.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_operation_form_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      throw StateError('This visual test requires Firebase Emulator.');
    }
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '127.0.0.1');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final response = await client
          .getUrl(Uri(scheme: 'http', host: host, port: 59199))
          .then((request) => request.close());
      await response.drain<void>();
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('Auth emulator is unavailable: ${response.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
    await FirebaseBootstrap.initialize(AppEnvironment.dev, useEmulators: true, emulatorHost: host);
    if (FirebaseBootstrap.app.options.projectId != 'demo-clearbudget') {
      throw StateError('Visual testing requires the demo-clearbudget project.');
    }
    await configureDependencies(useEmulators: true);
    await FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).signOut();
  });

  tearDownAll(() async {
    // The app router keeps auth-backed listeners alive for the process. The
    // synthetic user is signed out on the next test setup instead.
    await GetIt.I.reset();
  });

  testWidgets('verifies account search and the financial UX journey', (tester) async {
    await FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).signOut();
    debugPrint('VQA checkpoint: pump login');
    await tester.pumpWidget(const ProviderScope(child: PersonalFinanceApp()));
    await _waitFor(tester, find.byKey(const ValueKey('auth_guest_button')));
    debugPrint('VQA checkpoint: login visible');
    if (Platform.isAndroid && const bool.fromEnvironment('CAPTURE_VISUAL')) {
      await binding.convertFlutterSurfaceToImage();
    }
    await _capture(tester, binding, '01_login');
    debugPrint('VQA checkpoint: login captured');

    final credential = await FirebaseAuth.instanceFor(
      app: FirebaseBootstrap.app,
    ).signInAnonymously();
    final userId = credential.user!.uid;
    final userRef = FirebaseFirestore.instanceFor(
      app: FirebaseBootstrap.app,
    ).collection('users').doc(userId);
    await userRef.set({
      'locale': 'es',
      'countryCode': 'CO',
      'timeZone': 'America/Bogota',
      'defaultCurrency': 'COP',
      'onboardingStatus': 'in_progress',
      'categoryCatalogVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    appRouter.go('/onboarding');
    await _waitFor(tester, find.byKey(const ValueKey('onboarding_continue')));
    await _capture(tester, binding, '02_onboarding');
    debugPrint('VQA checkpoint: onboarding captured');

    await userRef.update({
      'onboardingStatus': 'complete',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final repository = getIt<CanonicalFinanceRepository>();
    final categoryResult = await repository.ensureDefaultCategories(
      userId,
      locale: 'es',
      countryCode: 'CO',
    );
    categoryResult.match((failure) => throw StateError(failure.message), (_) {});
    final firstAccount = await repository.createAccount(
      userId,
      name: 'QA Ahorros',
      type: 'savings',
      currency: 'COP',
      openingBalanceMinor: 320000,
    );
    firstAccount.match((failure) => throw StateError(failure.message), (_) {});
    final accountResult = await repository.createAccount(
      userId,
      name: 'Cuenta secundaria',
      type: 'savings',
      currency: 'COP',
      openingBalanceMinor: 0,
    );
    final secondAccount = accountResult.getOrElse((failure) => throw StateError(failure.message));
    appRouter.go('/home');
    await _waitFor(tester, find.byKey(const ValueKey('global_add_operation')).hitTestable());
    debugPrint('VQA checkpoint: onboarding state seeded and home visible');
    final accounts = await FirebaseFirestore.instanceFor(
      app: FirebaseBootstrap.app,
    ).collection('users').doc(userId).collection('accounts').get();
    final mainAccount = accounts.docs.firstWhere((doc) => doc.id != secondAccount.id);
    final categories = await FirebaseFirestore.instanceFor(
      app: FirebaseBootstrap.app,
    ).collection('users').doc(userId).collection('categories').get();
    final incomeCategory = categories.docs.firstWhere((doc) => doc.data()['type'] == 'income');
    final expenseCategory = categories.docs.firstWhere((doc) => doc.data()['type'] == 'expense');
    final now = DateTime.now();

    final income = await repository.createOperation(
      userId,
      FinancialOperationDraft(
        type: OperationType.income,
        amountMinor: 320000,
        currency: 'COP',
        accountId: mainAccount.id,
        categoryId: incomeCategory.id,
        occurredAt: now,
        description: 'Ingreso QA',
        idempotencyKey: 'visual-income-${now.microsecondsSinceEpoch}',
      ),
    );
    income.match((failure) => throw StateError(failure.message), (_) {});
    final expense = await repository.createOperation(
      userId,
      FinancialOperationDraft(
        type: OperationType.expense,
        amountMinor: 45000,
        currency: 'COP',
        accountId: mainAccount.id,
        categoryId: expenseCategory.id,
        occurredAt: now,
        description: 'Gasto QA',
        idempotencyKey: 'visual-expense-${now.microsecondsSinceEpoch}',
      ),
    );
    expense.match((failure) => throw StateError(failure.message), (_) {});
    final transfer = await repository.createTransfer(
      userId,
      TransferDraft(
        amountMinor: 25000,
        currency: 'COP',
        sourceAccountId: mainAccount.id,
        destinationAccountId: secondAccount.id,
        occurredAt: now,
        monthKey: '${now.year}-${now.month.toString().padLeft(2, '0')}',
        description: 'Ahorro QA',
        idempotencyKey: 'visual-transfer-${now.microsecondsSinceEpoch}',
      ),
    );
    transfer.match((failure) => throw StateError(failure.message), (_) {});
    final budget = await repository.createBudgetWithItems(
      userId,
      categoryId: expenseCategory.id,
      flowType: 'expense',
      monthKey: '${now.year}-${now.month.toString().padLeft(2, '0')}',
      currency: 'COP',
      items: const [
        CanonicalBudgetItemDraft(description: 'Mercado QA', amountMinor: 120000, dayOfMonth: 15),
      ],
    );
    budget.match((failure) => throw StateError(failure.message), (_) {});

    for (var i = 1; i <= 12; i++) {
      final created = await repository.createAccount(
        userId,
        name: 'Cuenta sintética $i',
        type: 'savings',
        currency: 'COP',
        openingBalanceMinor: i * 100000,
      );
      final account = created.getOrElse((failure) => throw StateError(failure.message));
      final operation = await repository.createOperation(
        userId,
        FinancialOperationDraft(
          type: OperationType.expense,
          amountMinor: i * 10000,
          currency: 'COP',
          accountId: account.id,
          categoryId: expenseCategory.id,
          occurredAt: now,
          description: 'Movimiento sintético $i',
          idempotencyKey: 'visual-${now.microsecondsSinceEpoch}-$i',
        ),
      );
      operation.match((failure) => throw StateError(failure.message), (_) {});
    }
    debugPrint('VQA checkpoint: demo finance data seeded');

    await tester.pump(const Duration(seconds: 2));
    await _capture(tester, binding, '03_home');
    debugPrint('VQA checkpoint: home captured');

    await tester.tap(find.byKey(const ValueKey('finance_nav_accounts')));
    await _waitFor(tester, find.byKey(const ValueKey('accounts_search')));
    await _capture(tester, binding, '04_accounts');
    await tester.enterText(find.byKey(const ValueKey('accounts_search')), 'sintetica 12');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Cuenta sintética 12'), findsOneWidget);
    await _capture(tester, binding, '05_accounts_search');
    await tester.tap(find.byKey(const ValueKey('accounts_search_clear')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('accounts_add_button')));
    await _waitFor(tester, find.byKey(const ValueKey('accounts_create_money')));
    await tester.tap(find.byKey(const ValueKey('accounts_create_money')));
    await _waitFor(tester, find.byKey(const ValueKey('account_initial_balance_field')));
    await _capture(tester, binding, '06_new_account');
    appRouter.go('/home');
    await _waitFor(tester, find.byKey(const ValueKey('global_add_operation')).hitTestable());
    await tester.tap(find.byKey(const ValueKey('global_add_operation')));
    await _waitFor(tester, find.byKey(const ValueKey('add_movement_expense')));
    await tester.tap(find.byKey(const ValueKey('add_movement_expense')));
    await _waitFor(tester, find.byType(CanonicalOperationFormScreen));
    await _capture(tester, binding, '07_expense');
    appRouter.go('/budgets/tracking');
    await _waitFor(tester, find.byKey(const ValueKey('budget_tracking_title')));
    await tester.pump(const Duration(seconds: 2));
    await _capture(tester, binding, '08_budget_tracking');
    debugPrint('VQA checkpoint: UX journey completed');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget, reason: 'Expected the screen marker to become visible.');
}

Future<void> _capture(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await tester.pump(const Duration(milliseconds: 400));
  debugPrint('VQA capture-ready $name');
  if (const bool.fromEnvironment('MANUAL_CAPTURE')) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
  }
  if (!const bool.fromEnvironment('CAPTURE_VISUAL')) return;
  final image = await binding.takeScreenshot(name);
  debugPrint('VQA checkpoint: screenshot bytes $name=${image.length}');
  expect(image, isNotEmpty, reason: 'Screenshot $name should contain PNG bytes.');
}
