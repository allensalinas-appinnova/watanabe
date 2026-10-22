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
import 'package:personal_finance/features/finance/presentation/screens/canonical_accounts_screen.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_activity_screen.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_budget_tracking_screen.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_budgets_screen.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_categories_screen.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_operation_form_screen.dart';
import 'package:personal_finance/features/finance/presentation/screens/canonical_transfer_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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
    await configureDependencies();
    await FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).signOut();
  });

  tearDownAll(() async {
    await FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).signOut();
    await GetIt.I.reset();
  });

  testWidgets('captures the Android P0 screens for visual acceptance', (tester) async {
    await FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).signOut();
    debugPrint('VQA checkpoint: pump login');
    await tester.pumpWidget(const ProviderScope(child: PersonalFinanceApp()));
    await _waitFor(tester, find.byKey(const ValueKey('auth_guest_button')));
    debugPrint('VQA checkpoint: login visible');
    await binding.convertFlutterSurfaceToImage();
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
    await _waitFor(tester, find.byKey(const ValueKey('global_add_operation')));
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
    debugPrint('VQA checkpoint: demo finance data seeded');

    await tester.pump(const Duration(seconds: 2));
    await _capture(tester, binding, '03_home');
    debugPrint('VQA checkpoint: home captured');

    await _selectTab(tester, 1, find.byType(CanonicalActivityScreen));
    await _capture(tester, binding, '04_activity');
    await _selectTab(tester, 3, find.byType(CanonicalAccountsScreen));
    await _waitFor(tester, find.byKey(ValueKey('account_row_${mainAccount.id}')).hitTestable());
    await _waitFor(tester, find.byKey(ValueKey('account_row_${secondAccount.id}')).hitTestable());
    await _capture(tester, binding, '05_accounts');
    await _go(tester, '/categories', find.byType(CanonicalCategoriesScreen));
    await _capture(tester, binding, '06_categories');
    await tester.tap(find.byKey(ValueKey('category_edit_${expenseCategory.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_icon_change')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_icon_option_health')));
    await tester.tap(find.byKey(const ValueKey('category_icon_use')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_edit_save')));
    await tester.pumpAndSettle();
    final persistedCategory = await userRef.collection('categories').doc(expenseCategory.id).get();
    expect(persistedCategory.data()?['icon'], 'health');
    await _go(tester, '/operations/new?type=income', find.byType(CanonicalOperationFormScreen));
    await _capture(tester, binding, '07_add_income');
    await _go(tester, '/operations/new?type=expense', find.byType(CanonicalOperationFormScreen));
    await _capture(tester, binding, '08_add_expense');
    await _go(tester, '/transfers/new', find.byType(CanonicalTransferScreen));
    await _capture(tester, binding, '09_transfer');
    await _captureTransferConfirmation(tester, binding);
    await _go(tester, '/budgets', find.byType(CanonicalBudgetsScreen));
    await _capture(tester, binding, '11_budgets');
    await tester.tap(find.byType(FloatingActionButton).last);
    await _waitFor(tester, find.byType(AlertDialog));
    await _capture(tester, binding, '12_budget_create');
    await tester.tap(find.byType(TextButton).last);
    await tester.pump(const Duration(milliseconds: 500));
    await _go(tester, '/budget-tracking', find.byType(CanonicalBudgetTrackingScreen));
    await _capture(tester, binding, '13_budget_tracking');
    debugPrint('VQA checkpoint: all P0 screenshots captured');
  });
}

Future<void> _captureTransferConfirmation(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.pump(const Duration(milliseconds: 200));
    final fields = tester.widgetList<DropdownButton<String>>(find.byType(DropdownButton<String>));
    if (fields.length == 2 && fields.every((field) => field.items?.length == 2)) break;
  }
  final dropdowns = find.byType(DropdownButtonFormField<String>);
  expect(dropdowns, findsNWidgets(2));
  final fields = tester.widgetList<DropdownButton<String>>(find.byType(DropdownButton<String>));
  expect(
    fields.length == 2 && fields.every((field) => field.items?.length == 2),
    isTrue,
    reason: 'Both accounts should be loaded before presenting transfer choices.',
  );
  await tester.tap(dropdowns.at(0));
  await tester.pumpAndSettle();
  await tester.tap(find.text('QA Ahorros (COP)').last);
  await tester.pumpAndSettle();
  await tester.tap(dropdowns.at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cuenta secundaria').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('transfer_amount')), '100');
  tester.binding.focusManager.primaryFocus?.unfocus();
  await tester.tap(find.byKey(const ValueKey('transfer_confirm')));
  await _waitFor(tester, find.byType(AlertDialog));
  await _capture(tester, binding, '10_transfer_confirmation');
  await tester.tap(find.byType(TextButton).last);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _go(WidgetTester tester, String route, Finder ready) async {
  appRouter.go(route);
  await _waitFor(tester, ready.hitTestable());
}

Future<void> _selectTab(WidgetTester tester, int index, Finder ready) async {
  final icon = switch (index) {
    0 => Icons.home_outlined,
    1 => Icons.list_alt_outlined,
    2 => Icons.pie_chart_outline,
    3 => Icons.account_balance_wallet_outlined,
    _ => throw ArgumentError.value(index, 'index'),
  };
  debugPrint('VQA navigation: tap tab $index from ${appRouter.routeInformationProvider.value.uri}');
  await tester.tap(find.byIcon(icon));
  await tester.pump(const Duration(milliseconds: 300));
  debugPrint('VQA navigation: tapped, uri ${appRouter.routeInformationProvider.value.uri}');
  await _waitFor(tester, ready);
  expect(
    tester
        .widget<NavigationBar>(
          find.byKey(const ValueKey('finance_bottom_navigation')),
        )
        .selectedIndex,
    index,
    reason: 'The selected navigation tab should match the captured P0 screen.',
  );
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
  final image = await binding.takeScreenshot(name);
  debugPrint('VQA checkpoint: screenshot bytes $name=${image.length}');
  expect(image, isNotEmpty, reason: 'Screenshot $name should contain PNG bytes.');
}
