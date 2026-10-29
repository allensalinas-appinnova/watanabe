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
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/firebase/firebase_bootstrap.dart';
import 'package:personal_finance/core/utils/currency_formatter.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Object? initializationError;
  StackTrace? initializationStack;

  Future<void> initializeEmulators() async {
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
    await FirebaseBootstrap.initialize(
      AppEnvironment.dev,
      useEmulators: true,
      emulatorHost: host,
    ).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw StateError('e2e-firebase-bootstrap-timeout'),
    );
    debugPrint('budget_e2e_firebase_ready');
    await configureDependencies(useEmulators: true).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw StateError('e2e-dependencies-timeout'),
    );
    debugPrint('budget_e2e_dependencies_ready');
    await FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).signOut().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw StateError('e2e-auth-signout-timeout'),
    );
    debugPrint('budget_e2e_auth_ready');
  }

  setUpAll(() async {
    try {
      await initializeEmulators().timeout(const Duration(seconds: 75));
    } catch (error, stack) {
      // Report setup failures from the widget test: integrationDriver does not
      // reliably count a failing setUpAll as a failed test.
      initializationError = error;
      initializationStack = stack;
    }
  });

  tearDownAll(() async {
    await FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).signOut();
    await GetIt.I.reset();
  });

  testWidgets('registers and creates expense and income budgets with multiple items', (
    tester,
  ) async {
    if (initializationError != null) {
      Error.throwWithStackTrace(initializationError!, initializationStack!);
    }
    final email = 'budget-${DateTime.now().microsecondsSinceEpoch}@example.test';
    const password = 'ClearBudget-E2E-123';
    await tester.pumpWidget(const ProviderScope(child: PersonalFinanceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.byKey(const ValueKey('auth_signup_tab')));
    await tester.enterText(find.byKey(const ValueKey('auth_email_field')), email);
    await tester.enterText(find.byKey(const ValueKey('auth_password_field')), password);
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('onboarding_account_name')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('onboarding_account_name')), 'Cuenta E2E');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
    await _pumpUntil(tester, find.byKey(const ValueKey('global_add_operation')));

    final uid = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).currentUser!.uid;
    await tester.tap(find.byKey(const ValueKey('finance_nav_budget')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _pumpUntil(tester, find.byKey(const ValueKey('budgets_create_button')));
    await tester.tap(find.byKey(const ValueKey('budgets_create_button')).hitTestable());
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_save')));
    final initialCreateScreenText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .where((text) => text.isNotEmpty)
        .join(' | ');
    expect(
      find.byKey(const ValueKey('budget_save')),
      findsOneWidget,
      reason: 'After opening budget creation, screen text was: $initialCreateScreenText',
    );

    await _createBudget(
      tester,
      categoryLabel: 'Alimentación',
      items: const [('Mercado semanal', '300000'), ('Frutas', '50000')],
    );
    await _pumpUntil(tester, find.byKey(const ValueKey('budgets_create_button')));
    final monthKey = _currentMonthKey();
    final expenseBudgetKey = ValueKey('budget_card_${monthKey}_expense_food_COP');
    final user = FirebaseFirestore.instanceFor(
      app: FirebaseBootstrap.app,
    ).collection('users').doc(uid);
    final expenseId = '${monthKey}_expense_food_COP';
    await _pumpUntil(tester, find.byKey(expenseBudgetKey));
    expect(find.text('Alimentación'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('budget_filter_income')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('budget_filtered_empty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('budget_filter_reset')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(ValueKey('budget_card_tap_${monthKey}_expense_food_COP')),
    );
    await tester.tap(find.byKey(ValueKey('budget_card_tap_${monthKey}_expense_food_COP')));
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_detail_category')));

    final weeklyMarketCard = find.ancestor(
      of: find.text('Mercado semanal'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(
        of: weeklyMarketCard,
        matching: find.byKey(const ValueKey('budget_item_edit')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('budget_item_edit_description')),
      'Mercado quincenal',
    );
    await tester.enterText(find.byKey(const ValueKey('budget_item_edit_amount')), '325000');
    await _selectDayOfMonth(tester, 18);
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_item_edit_save')));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final fruitItemCard = find.ancestor(
      of: find.text('Frutas'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(
        of: fruitItemCard,
        matching: find.byKey(const ValueKey('budget_item_remove')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('confirm_budget_item_delete')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm_budget_item_delete')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await _waitForBudgetItemCount(
      user.collection('budgets').doc(expenseId),
      1,
      tester: tester,
    );
    final editedExpense = await user
        .collection('budgets')
        .doc(expenseId)
        .get(const GetOptions(source: Source.server));
    final editedItems = await user
        .collection('budgets')
        .doc(expenseId)
        .collection('items')
        .get(const GetOptions(source: Source.server));
    expect(editedExpense.data()?['plannedAmountMinor'], 325000);
    expect(editedExpense.data()?['itemCount'], 1);
    final activeEditedItems = editedItems.docs
        .where((doc) => doc.data()['status'] != 'archived')
        .toList();
    expect(activeEditedItems, hasLength(1));
    expect(editedItems.docs, hasLength(2), reason: 'Removed items preserve their history.');
    expect(activeEditedItems.single.data()['description'], 'Mercado quincenal');
    final lastItemDeletion = await getIt<CanonicalFinanceRepository>().deleteBudgetItem(
      uid,
      expenseId,
      activeEditedItems.single.id,
    );
    final lastItemFailure = lastItemDeletion.match((failure) => failure, (_) => null);
    expect(lastItemFailure, isA<ConflictFailure>());
    expect(
      (await activeEditedItems.single.reference.get(
        const GetOptions(source: Source.server),
      )).exists,
      isTrue,
    );
    expect(find.byKey(const ValueKey('budget_item_remove')), findsNothing);
    expect(find.byKey(const ValueKey('budget_last_item_hint')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('budget_detail_back')));
    await tester.pumpAndSettle();
    await _waitForActiveBudgetList(tester);
    await tester.tap(find.byKey(const ValueKey('budgets_create_button')).hitTestable());
    await tester.pumpAndSettle();
    await _createBudget(
      tester,
      categoryLabel: 'Alimentación',
      items: const [('Intento duplicado', '25')],
    );
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_create_error')));
    final duplicateMessage = tester
        .widget<Text>(find.byKey(const ValueKey('budget_create_error')))
        .data!
        .toLowerCase();
    expect(duplicateMessage, anyOf(contains('already'), contains('existe')));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('budget_item_description_0')))
          .controller!
          .text,
      'Intento duplicado',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('budget_create_back')),
      -400,
      scrollable: find.descendant(of: find.byType(Form), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(find.byKey(const ValueKey('budget_create_back')));
    await tester.pumpAndSettle();
    await _waitForActiveBudgetList(tester);

    await tester.tap(find.byKey(const ValueKey('budgets_create_button')).hitTestable());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('budget_type_selector')));
    await tester.tap(find.byKey(const ValueKey('budget_type_selector')));
    await tester.pumpAndSettle();
    final typeSelector = find.byKey(const ValueKey('budget_type_selector'));
    final incomeTypeLabel = AppLocalizations.of(tester.element(typeSelector)).incomeCategories;
    // DropdownButton creates an offstage item in the field and a separate menu
    // item in the route overlay; choose the overlay copy rather than its key.
    await tester.tap(find.text(incomeTypeLabel).last);
    await tester.pumpAndSettle();
    await _createBudget(
      tester,
      categoryLabel: 'Salario',
      items: const [('Salario mensual', '2500000'), ('Bono', '250000')],
    );
    await _pumpUntil(tester, find.byKey(const ValueKey('budgets_create_button')));

    final incomeId = '${monthKey}_income_salary_COP';
    final expense = await user
        .collection('budgets')
        .doc(expenseId)
        .get(
          const GetOptions(source: Source.server),
        );
    final income = await user
        .collection('budgets')
        .doc(incomeId)
        .get(
          const GetOptions(source: Source.server),
        );
    expect(expense.exists, isTrue);
    expect(income.exists, isTrue);
    // This budget was edited and had one item removed earlier in this same flow.
    expect(expense.data()?['plannedAmountMinor'], 325000);
    expect(income.data()?['plannedAmountMinor'], 2750000);
    expect(expense.data()?['flowType'], 'expense');
    expect(income.data()?['flowType'], 'income');

    final expenseItems = await user
        .collection('budgets')
        .doc(expenseId)
        .collection('items')
        .get(const GetOptions(source: Source.server));
    final incomeItems = await user
        .collection('budgets')
        .doc(incomeId)
        .collection('items')
        .get(const GetOptions(source: Source.server));
    final activeExpenseItems = expenseItems.docs
        .where((doc) => doc.data()['status'] != 'archived')
        .toList();
    expect(activeExpenseItems, hasLength(1));
    expect(incomeItems.docs, hasLength(2));
    expect(
      activeExpenseItems.fold<int>(
        0,
        (totalMinor, doc) => totalMinor + (doc.data()['amountMinor'] as int),
      ),
      expense.data()?['plannedAmountMinor'],
    );
    expect(
      incomeItems.docs.fold<int>(
        0,
        (totalMinor, doc) => totalMinor + (doc.data()['amountMinor'] as int),
      ),
      income.data()?['plannedAmountMinor'],
    );
    expect(find.text('Salario'), findsWidgets);
    expect(find.text('Alimentación'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('budget_filter_expenses')));
    await tester.pumpAndSettle();
    expect(find.byKey(expenseBudgetKey), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('budget_filter_income')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('budget_card_${monthKey}_income_salary_COP')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('budget_filter_all')));
    await tester.pumpAndSettle();

    final repository = getIt<CanonicalFinanceRepository>();
    final accounts = await user.collection('accounts').get(const GetOptions(source: Source.server));
    final sourceAccountId = accounts.docs.first.id;
    final destinationResult = await repository.createAccount(
      uid,
      name: 'Cuenta destino E2E',
      type: 'savings',
      currency: 'COP',
      openingBalanceMinor: 0,
    );
    final destinationAccountId = destinationResult
        .getOrElse(
          (failure) => throw StateError(failure.message),
        )
        .id;
    final occurredAt = DateTime.now();
    final expenseOperation = await repository.createOperation(
      uid,
      FinancialOperationDraft(
        type: OperationType.expense,
        amountMinor: 20000,
        currency: 'COP',
        accountId: sourceAccountId,
        categoryId: 'food',
        occurredAt: occurredAt,
        monthKey: monthKey,
        description: 'Compra E2E',
        idempotencyKey: 'budget-e2e-expense-${occurredAt.microsecondsSinceEpoch}',
      ),
    );
    expenseOperation.match(
      (failure) => throw StateError(failure.message),
      (_) {},
    );
    final incomeOperation = await repository.createOperation(
      uid,
      FinancialOperationDraft(
        type: OperationType.income,
        amountMinor: 100000,
        currency: 'COP',
        accountId: sourceAccountId,
        categoryId: 'salary',
        occurredAt: occurredAt,
        monthKey: monthKey,
        description: 'Ingreso E2E',
        idempotencyKey: 'budget-e2e-income-${occurredAt.microsecondsSinceEpoch}',
      ),
    );
    incomeOperation.match(
      (failure) => throw StateError(failure.message),
      (_) {},
    );
    final summaryRef = user.collection('monthlySummaries').doc('${monthKey}_COP');
    await _waitForSummary(summaryRef, expectedFood: -20000, expectedSalary: 100000);
    final beforeTransfer = (await summaryRef.get(const GetOptions(source: Source.server))).data()!;
    final sourceAccountRef = user.collection('accounts').doc(sourceAccountId);
    final destinationAccountRef = user.collection('accounts').doc(destinationAccountId);
    final sourceBalanceBefore =
        (await sourceAccountRef.get(
              const GetOptions(source: Source.server),
            )).data()!['currentBalanceMinor']
            as int;
    final transfer = await repository.createTransfer(
      uid,
      TransferDraft(
        amountMinor: 30000,
        currency: 'COP',
        sourceAccountId: sourceAccountId,
        destinationAccountId: destinationAccountId,
        occurredAt: occurredAt,
        monthKey: monthKey,
        description: 'Ahorro entre cuentas',
        idempotencyKey: 'budget-e2e-transfer-${occurredAt.microsecondsSinceEpoch}',
      ),
    );
    final transferOperation = transfer.getOrElse(
      (failure) => throw StateError(failure.message),
    );
    await _waitForTransferBalances(
      sourceAccountRef,
      destinationAccountRef,
      expectedSource: sourceBalanceBefore - 30000,
      expectedDestination: 30000,
    );
    final afterTransfer = (await summaryRef.get(const GetOptions(source: Source.server))).data()!;
    expect(afterTransfer['incomeMinor'], beforeTransfer['incomeMinor']);
    expect(afterTransfer['expenseMinor'], beforeTransfer['expenseMinor']);
    expect(afterTransfer['byCategory'], beforeTransfer['byCategory']);
    final transferEntries = await user
        .collection('operations')
        .doc(transferOperation.id)
        .collection('entries')
        .get(const GetOptions(source: Source.server));
    expect(transferEntries.docs, hasLength(2));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final expenseActualFinder = find.byKey(
      ValueKey('budget_card_actual_${monthKey}_expense_food_COP'),
    );
    final incomeActualFinder = find.byKey(
      ValueKey('budget_card_actual_${monthKey}_income_salary_COP'),
    );
    expect(expenseActualFinder, findsOneWidget);
    expect(incomeActualFinder, findsOneWidget);
    final locale = Localizations.localeOf(tester.element(expenseActualFinder)).toString();
    expect(
      tester.widget<Text>(expenseActualFinder).data,
      contains(CurrencyFormatter.formatMinor(20000, 'COP', locale: locale)),
    );
    expect(
      tester.widget<Text>(incomeActualFinder).data,
      contains(CurrencyFormatter.formatMinor(100000, 'COP', locale: locale)),
    );

    final expenseCardTap = find.byKey(ValueKey('budget_card_tap_${monthKey}_expense_food_COP'));
    await tester.ensureVisible(expenseCardTap);
    await tester.tap(expenseCardTap);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('budget_archive_button')).hitTestable(),
      400,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('budget_detail_scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_archive_button')).hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('confirm_budget_archive')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm_budget_archive')));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final archivedExpense = await user
        .collection('budgets')
        .doc(expenseId)
        .get(const GetOptions(source: Source.server));
    expect(archivedExpense.data()?['status'], 'archived');
    expect(
      (await user.collection('operations').get(const GetOptions(source: Source.server))).docs,
      hasLength(3),
    );
    expect(find.byKey(expenseBudgetKey), findsNothing);
  });
}

Future<void> _createBudget(
  WidgetTester tester, {
  required String categoryLabel,
  required List<(String, String)> items,
}) async {
  for (var index = 0; index < items.length; index++) {
    if (index > 0) {
      await _revealFormField(tester, find.byKey(const ValueKey('budget_add_item')));
      await tester.tap(find.byKey(const ValueKey('budget_add_item')));
      await tester.pumpAndSettle();
    }
    final description = find.byKey(ValueKey('budget_item_description_$index'));
    final amount = find.byKey(ValueKey('budget_item_amount_$index'));
    await _revealFormField(tester, description);
    await tester.enterText(description, items[index].$1);
    await _revealFormField(tester, amount);
    await tester.enterText(amount, items[index].$2);
    await tester.pumpAndSettle();
  }
  tester.binding.focusManager.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final category = find.byKey(
    ValueKey(
      'budget_category_selector_${categoryLabel == 'Salario' ? 'income' : 'expense'}',
    ),
  );
  await _revealFormField(tester, category);
  await tester.tap(find.byKey(const ValueKey('budget_category_selector_tap')));
  await tester.pumpAndSettle();
  final categoryId = switch (categoryLabel) {
    'Alimentación' => 'food',
    'Salario' => 'salary',
    _ => throw StateError('Unknown E2E category: $categoryLabel'),
  };
  final categoryOption = find.byKey(ValueKey('finance_popup_option_$categoryId'));
  expect(categoryOption, findsOneWidget, reason: 'Expected category $categoryLabel in selector.');
  await tester.tap(find.text(categoryLabel).last);
  await tester.pumpAndSettle();
  expect(find.text(categoryLabel), findsOneWidget);
  final save = find.byKey(const ValueKey('budget_save'));
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _revealFormField(WidgetTester tester, Finder finder) async {
  tester.binding.focusManager.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _selectDayOfMonth(WidgetTester tester, int day) async {
  final selector = find.descendant(
    of: find.byKey(const ValueKey('budget_item_edit_day')),
    matching: find.byType(DropdownButtonFormField<int>),
  );
  expect(selector, findsOneWidget);
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          RegExp('^(Día|Day|Dia) $day\$').hasMatch(
            widget.data ?? widget.textSpan?.toPlainText() ?? '',
          ),
    ),
  );
  await tester.pumpAndSettle();
}

String _currentMonthKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (finder.evaluate().isNotEmpty) return;
  }
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .where((text) => text.isNotEmpty)
      .join(' | ');
  expect(finder, findsOneWidget, reason: 'Visible text when waiting failed: $visibleText');
}

Future<void> _waitForActiveBudgetList(WidgetTester tester) async {
  final createButton = find.byKey(const ValueKey('budgets_create_button')).hitTestable();
  await _pumpUntil(tester, createButton);
  final navigation = tester.widget<NavigationBar>(
    find.byKey(const ValueKey('finance_bottom_navigation')),
  );
  expect(navigation.selectedIndex, 3, reason: 'Budget branch should be selected after pop.');
  expect(
    createButton,
    findsOneWidget,
    reason: 'Budget create action must be onstage and tappable.',
  );
}

Future<void> _waitForSummary(
  DocumentReference<Map<String, dynamic>> summaryRef, {
  required int expectedFood,
  required int expectedSalary,
}) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final snapshot = await summaryRef.get(const GetOptions(source: Source.server));
    final byCategory = Map<String, dynamic>.from(
      snapshot.data()?['byCategory'] as Map? ?? const {},
    );
    if (byCategory['food'] == expectedFood && byCategory['salary'] == expectedSalary) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('Monthly summary did not reflect the expected operation totals.');
}

Future<void> _waitForBudgetItemCount(
  DocumentReference<Map<String, dynamic>> budgetRef,
  int expectedCount, {
  required WidgetTester tester,
}) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final snapshot = await budgetRef.get(const GetOptions(source: Source.server));
    if (snapshot.data()?['itemCount'] == expectedCount) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  final snapshot = await budgetRef.get(const GetOptions(source: Source.server));
  final items = await budgetRef.collection('items').get(const GetOptions(source: Source.server));
  final feedback = tester
      .widgetList<Text>(find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)))
      .map((widget) => widget.data ?? '')
      .join(' | ');
  final screenText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .where((text) => text.isNotEmpty)
      .join(' | ');
  throw StateError(
    'Budget item count did not reach $expectedCount after the UI action. '
    'Budget: ${snapshot.data()}, item amounts: '
    '${items.docs.map((item) => item.data()['amountMinor']).toList()}. '
    'Feedback: $feedback. Screen: $screenText',
  );
}

Future<void> _waitForTransferBalances(
  DocumentReference<Map<String, dynamic>> sourceRef,
  DocumentReference<Map<String, dynamic>> destinationRef, {
  required int expectedSource,
  required int expectedDestination,
}) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final source = await sourceRef.get(const GetOptions(source: Source.server));
    final destination = await destinationRef.get(const GetOptions(source: Source.server));
    if (source.data()?['currentBalanceMinor'] == expectedSource &&
        destination.data()?['currentBalanceMinor'] == expectedDestination) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('The transfer was not applied atomically to both account balances.');
}
