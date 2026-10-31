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
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/widgets/finance_popup_selector.dart';
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
    await GetIt.I.reset();
  });

  testWidgets('creates, edits, removes and archives a budget safely', (tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    if (initializationError != null) {
      Error.throwWithStackTrace(initializationError!, initializationStack!);
    }
    final email = 'budget-items-${DateTime.now().microsecondsSinceEpoch}@example.test';
    const password = 'ClearBudget-E2E-123';
    await tester.pumpWidget(const ProviderScope(child: PersonalFinanceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('auth_signup_tab')));
    await tester.enterText(find.byKey(const ValueKey('auth_email_field')), email);
    await tester.enterText(find.byKey(const ValueKey('auth_password_field')), password);
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.enterText(find.byKey(const ValueKey('onboarding_account_name')), 'Cuenta QA');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
    await _pumpUntil(tester, find.byKey(const ValueKey('global_add_operation')));

    final uid = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).currentUser!.uid;
    await tester.tap(find.byKey(const ValueKey('finance_nav_budget')));
    await tester.pumpAndSettle();
    await _pumpUntil(tester, find.byKey(const ValueKey('budgets_create_button')));

    final monthPicker = find.byKey(const ValueKey('planning_month_picker'));
    String selectedMonthLabel() =>
        tester.widget<Text>(find.descendant(of: monthPicker, matching: find.byType(Text))).data!;
    final currentMonthLabel = selectedMonthLabel();
    final l10n = AppLocalizations.of(tester.element(monthPicker));
    await tester.tap(find.byKey(const ValueKey('planning_next_month')));
    await tester.pumpAndSettle();
    final nextMonthLabel = selectedMonthLabel();
    expect(nextMonthLabel, isNot(currentMonthLabel));

    await tester.tap(find.text(l10n.planningAgenda).hitTestable());
    await tester.pumpAndSettle();
    await _pumpUntil(tester, find.text(l10n.planningNoEntries));
    expect(selectedMonthLabel(), nextMonthLabel);

    final debtPaymentsTab = find.text(l10n.debtCommitmentsTab);
    await tester.ensureVisible(debtPaymentsTab);
    await tester.pumpAndSettle();
    await tester.tap(debtPaymentsTab);
    await tester.pumpAndSettle();
    await _pumpUntil(tester, find.byKey(const ValueKey('debt_commitment_count')));
    expect(selectedMonthLabel(), nextMonthLabel);

    final budgetsTab = find.text(l10n.budgetsTab);
    await tester.ensureVisible(budgetsTab);
    await tester.pumpAndSettle();
    await tester.tap(budgetsTab);
    await tester.pumpAndSettle();
    await _pumpUntil(tester, find.byKey(const ValueKey('budgets_create_button')));
    expect(selectedMonthLabel(), nextMonthLabel);

    await tester.tap(find.byKey(const ValueKey('planning_this_month')));
    await tester.pumpAndSettle();
    expect(selectedMonthLabel(), currentMonthLabel);

    await tester.tap(find.byKey(const ValueKey('budgets_create_button')).hitTestable());
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_save')));
    await _createBudget(
      tester,
      items: const [('Mercado semanal', '300000'), ('Frutas', '50000')],
    );

    final monthKey = _currentMonthKey();
    final budgetId = '${monthKey}_expense_food_COP';
    final budgetRef = FirebaseFirestore.instanceFor(
      app: FirebaseBootstrap.app,
    ).collection('users').doc(uid).collection('budgets').doc(budgetId);
    await _pumpUntil(tester, find.byKey(ValueKey('budget_card_$budgetId')));

    await tester.tap(find.byKey(ValueKey('budget_card_tap_$budgetId')));
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_detail_category')));

    final firstItemQuery = await budgetRef
        .collection('items')
        .where('description', isEqualTo: 'Mercado semanal')
        .get(const GetOptions(source: Source.server));
    final linkedItemRef = firstItemQuery.docs.single.reference;
    await tester.tap(find.byKey(ValueKey('budget_item_row_${linkedItemRef.id}')));
    await _pumpUntil(tester, find.byKey(const ValueKey('planning_item_register')));
    await tester.tap(find.byKey(const ValueKey('planning_item_register')));
    await _pumpUntil(tester, find.byKey(const ValueKey('operation_save')));
    final amountField = find.byKey(const ValueKey('operation_amount'));
    expect(tester.widget<TextFormField>(amountField).controller!.text, '300000');
    expect(
      tester
          .widget<FinancePopupSelector<String>>(
            find.byKey(const ValueKey('operation_category_selector')),
          )
          .onSelected,
      isNull,
    );
    await tester.enterText(amountField, '100000');
    await tester.tap(find.byKey(const ValueKey('operation_more_options')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('operation_description')),
      'Mercado del presupuesto',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('operation_save')));
    await tester.pumpAndSettle();
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('operation_save')));
    // Registering from an item now returns to its detail screen. Keep the
    // E2E aligned with that UX before continuing with budget-level actions.
    await _pumpUntil(tester, find.byKey(const ValueKey('planning_item_register')));
    await tester.pageBack();
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_detail_category')));
    await _waitForActualAmount(linkedItemRef, 100000);

    final linkedOperations = await FirebaseFirestore.instanceFor(app: FirebaseBootstrap.app)
        .collection('users')
        .doc(uid)
        .collection('operations')
        .where('budgetId', isEqualTo: budgetId)
        .where('budgetItemId', isEqualTo: linkedItemRef.id)
        .get(const GetOptions(source: Source.server));
    expect(linkedOperations.docs, hasLength(1));
    expect(linkedOperations.docs.single.data()['categoryId'], 'food');
    expect(
      (await linkedItemRef.get(
        const GetOptions(source: Source.server),
      )).data()?['actualAmountMinor'],
      100000,
    );
    final linkedOperationRef = linkedOperations.docs.single.reference;

    final marketCard = find.ancestor(
      of: find.text('Mercado semanal'),
      matching: find.byType(Card),
    );
    final marketEdit = find.descendant(
      of: marketCard,
      matching: find.byKey(ValueKey('budget_item_actions_${linkedItemRef.id}')),
    );
    await tester.ensureVisible(marketEdit);
    await tester.pumpAndSettle();
    // The detail is restored beneath a root-navigator form route. Explicitly
    // pump after revealing the action so its hit-test geometry is current.
    await tester.pumpAndSettle();
    expect(tester.getRect(marketEdit).left, greaterThanOrEqualTo(0));
    expect(
      tester.getRect(marketEdit).right,
      lessThanOrEqualTo(tester.view.physicalSize.width / tester.view.devicePixelRatio),
    );
    await tester.tap(marketEdit);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('budget_item_edit_${linkedItemRef.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('budget_item_edit_description')),
      'Mercado quincenal',
    );
    await tester.enterText(find.byKey(const ValueKey('budget_item_edit_amount')), '325000');
    await _selectDayOfMonth(tester, 18);
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.ensureVisible(find.byKey(const ValueKey('budget_item_edit_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_item_edit_save')).hitTestable());
    await _pumpUntil(tester, find.text('Frutas'));

    final fruitItemQuery = await budgetRef
        .collection('items')
        .where('description', isEqualTo: 'Frutas')
        .get(const GetOptions(source: Source.server));
    final fruitItemId = fruitItemQuery.docs.single.id;
    final fruitCard = find.ancestor(of: find.text('Frutas'), matching: find.byType(Card));
    final fruitRemove = find.descendant(
      of: fruitCard,
      matching: find.byKey(ValueKey('budget_item_actions_$fruitItemId')),
    );
    await tester.ensureVisible(fruitRemove);
    await tester.pumpAndSettle();
    await tester.tap(fruitRemove);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('budget_item_remove_$fruitItemId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_budget_item_delete')));
    await tester.pumpAndSettle();
    await _waitForItemCount(budgetRef, 1);

    final budget = await budgetRef.get(const GetOptions(source: Source.server));
    final items = await budgetRef.collection('items').get(const GetOptions(source: Source.server));
    expect(budget.data()?['plannedAmountMinor'], 325000);
    expect(budget.data()?['itemCount'], 1);
    final activeItems = items.docs.where((doc) => doc.data()['status'] != 'archived').toList();
    expect(activeItems, hasLength(1));
    expect(activeItems.single.data()['description'], 'Mercado quincenal');
    expect(
      items.docs.where((doc) => doc.data()['status'] == 'archived'),
      hasLength(1),
      reason: 'Removed items stay archived so movement history remains associated.',
    );

    final lastActiveItem = activeItems.single;
    final lastItemResult = await getIt<CanonicalFinanceRepository>().deleteBudgetItem(
      uid,
      budgetId,
      lastActiveItem.id,
    );
    expect(lastItemResult.match((failure) => failure, (_) => null), isA<ConflictFailure>());
    expect(
      (await lastActiveItem.reference.get(const GetOptions(source: Source.server))).exists,
      isTrue,
    );
    await tester.pumpAndSettle();
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_last_item_hint')));
    final lastItemActions = find.byKey(ValueKey('budget_item_actions_${lastActiveItem.id}'));
    expect(lastItemActions, findsOneWidget);
    await tester.tap(lastItemActions);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('budget_item_remove_${lastActiveItem.id}')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('budget_last_item_hint')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('budget_add_item_detail')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_add_item_detail')));
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_item_create_save')));
    await tester.enterText(
      find.byKey(const ValueKey('budget_item_create_description')),
      'Servicios públicos',
    );
    await tester.enterText(find.byKey(const ValueKey('budget_item_create_amount')), '45000');
    await _selectCreateDayOfMonth(tester, 12);
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('budget_item_create_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_item_create_save')));
    await _pumpUntil(tester, find.text('Servicios públicos'));
    await _waitForItemCount(budgetRef, 2);

    final updatedBudget = await budgetRef.get(const GetOptions(source: Source.server));
    final updatedItems = await budgetRef
        .collection('items')
        .get(
          const GetOptions(source: Source.server),
        );
    expect(updatedBudget.data()?['plannedAmountMinor'], 370000);
    expect(updatedBudget.data()?['itemCount'], 2);
    expect(
      updatedItems.docs.map((doc) => doc.data()['description']),
      containsAll(['Mercado quincenal', 'Servicios públicos']),
    );

    final servicesItemQuery = await budgetRef
        .collection('items')
        .where('description', isEqualTo: 'Servicios públicos')
        .get(const GetOptions(source: Source.server));
    final servicesItemId = servicesItemQuery.docs.single.id;
    final servicesCard = find.ancestor(
      of: find.text('Servicios públicos'),
      matching: find.byType(Card),
    );
    final servicesRemove = find.descendant(
      of: servicesCard,
      matching: find.byKey(ValueKey('budget_item_actions_$servicesItemId')),
    );
    await tester.ensureVisible(servicesRemove);
    await tester.pumpAndSettle();
    await tester.tap(servicesRemove);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('budget_item_remove_$servicesItemId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_budget_item_delete')));
    await tester.pumpAndSettle();
    await _waitForItemCount(budgetRef, 1);
    final afterRemovingAddedItem = await budgetRef.get(const GetOptions(source: Source.server));
    expect(afterRemovingAddedItem.data()?['plannedAmountMinor'], 325000);

    // Keep another active item so the linked item can be safely archived.
    await tester.ensureVisible(find.byKey(const ValueKey('budget_add_item_detail')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_add_item_detail')));
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_item_create_save')));
    await tester.enterText(find.byKey(const ValueKey('budget_item_create_description')), 'Reserva');
    await tester.enterText(find.byKey(const ValueKey('budget_item_create_amount')), '25000');
    await _selectCreateDayOfMonth(tester, 22);
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('budget_item_create_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_item_create_save')));
    await _waitForItemCount(budgetRef, 2);
    await tester.ensureVisible(find.text('Reserva'));
    await tester.pumpAndSettle();
    expect(find.text('Reserva'), findsOneWidget);

    final linkedCard = find.ancestor(
      of: find.text('Mercado quincenal'),
      matching: find.byType(Card),
    );
    final linkedRemove = find.descendant(
      of: linkedCard,
      matching: find.byKey(ValueKey('budget_item_actions_${linkedItemRef.id}')),
    );
    await tester.ensureVisible(linkedRemove);
    await tester.pumpAndSettle();
    await tester.tap(linkedRemove);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('budget_item_remove_${linkedItemRef.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_budget_item_delete')));
    await _waitForItemCount(budgetRef, 1);
    await tester.tap(find.byKey(const ValueKey('budget_detail_movements_tab')));
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_detail_movements_list')));
    await _pumpUntil(
      tester,
      find.byKey(ValueKey('budget_operation_${linkedOperationRef.id}')),
    );
    expect(find.textContaining('Mercado del presupuesto'), findsOneWidget);
    expect(
      (await linkedOperationRef.get(const GetOptions(source: Source.server))).exists,
      isTrue,
    );
    expect(
      (await linkedItemRef.get(const GetOptions(source: Source.server))).data()?['status'],
      'archived',
    );
    expect(
      (await linkedItemRef.get(
        const GetOptions(source: Source.server),
      )).data()?['actualAmountMinor'],
      100000,
    );
    final afterArchivingLinkedItem = await budgetRef.get(const GetOptions(source: Source.server));
    expect(afterArchivingLinkedItem.data()?['plannedAmountMinor'], 25000);

    final cancellation = await getIt<CanonicalFinanceRepository>().deleteOperation(
      uid,
      linkedOperationRef.id,
    );
    expect(cancellation.match((failure) => failure, (_) => null), isNull);
    await _waitForActualAmount(linkedItemRef, 0);

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_detail_elements_tab')));
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
    await tester.tap(find.byKey(const ValueKey('confirm_budget_archive')));
    await tester.pumpAndSettle();
    final archived = await budgetRef.get(const GetOptions(source: Source.server));
    expect(archived.data()?['status'], 'archived');
    final activeBudgets = await getIt<CanonicalFinanceRepository>()
        .watchBudgets(uid, monthKey)
        .first;
    expect(activeBudgets.any((budget) => budget.id == budgetId), isFalse);

    // Archiving removes the budget from active lists but keeps its deterministic
    // identity for historical item links. Creating the same category/month
    // again should reactivate it with fresh active items, not fail as a duplicate.
    await _pumpUntil(tester, find.byKey(const ValueKey('budgets_create_button')));
    await tester.tap(find.byKey(const ValueKey('budgets_create_button')).hitTestable());
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_save')));
    await _createBudget(tester, items: const [('Mercado nuevo', '75000')]);
    await _pumpUntil(tester, find.byKey(ValueKey('budget_card_$budgetId')));

    final reactivated = await budgetRef.get(const GetOptions(source: Source.server));
    expect(reactivated.data()?['status'], 'active');
    expect(reactivated.data()?['plannedAmountMinor'], 75000);
    expect(reactivated.data()?['itemCount'], 1);
    final itemsAfterReactivation = await budgetRef
        .collection('items')
        .get(const GetOptions(source: Source.server));
    expect(
      itemsAfterReactivation.docs.any(
        (item) =>
            item.id == linkedItemRef.id &&
            item.data()['description'] == 'Mercado quincenal' &&
            item.data()['status'] == 'archived',
      ),
      isTrue,
      reason: 'The previous item and its linked history must remain archived.',
    );
    expect((await linkedOperationRef.get(const GetOptions(source: Source.server))).exists, isTrue);
    expect(
      itemsAfterReactivation.docs.where(
        (item) =>
            item.data()['description'] == 'Mercado nuevo' && item.data()['status'] == 'active',
      ),
      hasLength(1),
    );
  });

  testWidgets('recalculates a budget after archiving items, adding one and recording its expense', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    if (initializationError != null) {
      Error.throwWithStackTrace(initializationError!, initializationStack!);
    }
    final auth = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app);
    await auth.signOut();
    await tester.pumpWidget(const ProviderScope(child: PersonalFinanceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final email = 'budget-aggregate-${DateTime.now().microsecondsSinceEpoch}@example.test';
    await tester.tap(find.byKey(const ValueKey('auth_signup_tab')));
    await tester.enterText(find.byKey(const ValueKey('auth_email_field')), email);
    await tester.enterText(
      find.byKey(const ValueKey('auth_password_field')),
      'ClearBudget-E2E-123',
    );
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    final openingBalance = find.byKey(const ValueKey('onboarding_current_balance'));
    await tester.ensureVisible(openingBalance);
    await tester.enterText(openingBalance, '100000');
    await tester.enterText(find.byKey(const ValueKey('onboarding_account_name')), 'Cuenta QA');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
    await _pumpUntil(tester, find.byKey(const ValueKey('global_add_operation')));

    final uid = auth.currentUser!.uid;
    final firestore = FirebaseFirestore.instanceFor(app: FirebaseBootstrap.app);
    await tester.tap(find.byKey(const ValueKey('finance_nav_budget')));
    await _pumpUntil(tester, find.byKey(const ValueKey('budgets_create_button')));
    final monthKey = _currentMonthKey();
    final budgetId = '${monthKey}_expense_food_COP';
    final budgetRef = firestore.collection('users').doc(uid).collection('budgets').doc(budgetId);
    await tester.tap(find.byKey(const ValueKey('budgets_create_button')).hitTestable());
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_save')));
    await _createBudget(
      tester,
      items: const [
        ('Elemento para archivar A', '250000'),
        ('Elemento para archivar B', '200000'),
        ('Elemento que se conserva', '50000'),
      ],
    );

    await _pumpUntil(tester, find.byKey(ValueKey('budget_card_$budgetId')));
    await tester.tap(find.byKey(ValueKey('budget_card_tap_$budgetId')));
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_detail_category')));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && RegExp(r'500[.,\u00a0\u202f ]000').hasMatch(widget.data ?? ''),
      ),
      findsWidgets,
    );
    await _assertBudgetAggregate(
      budgetRef,
      plannedAmount: 500000,
      itemCount: 3,
      activeDescriptions: const [
        'Elemento para archivar A',
        'Elemento para archivar B',
        'Elemento que se conserva',
      ],
      archivedDescriptions: const [],
    );

    await _archiveBudgetItem(tester, budgetRef, 'Elemento para archivar A');
    await _assertBudgetAggregate(
      budgetRef,
      plannedAmount: 250000,
      itemCount: 2,
      activeDescriptions: const ['Elemento para archivar B', 'Elemento que se conserva'],
      archivedDescriptions: const ['Elemento para archivar A'],
    );
    await _archiveBudgetItem(tester, budgetRef, 'Elemento para archivar B');
    await _assertBudgetAggregate(
      budgetRef,
      plannedAmount: 50000,
      itemCount: 1,
      activeDescriptions: const ['Elemento que se conserva'],
      archivedDescriptions: const ['Elemento para archivar A', 'Elemento para archivar B'],
    );

    await tester.tap(find.byKey(const ValueKey('budget_add_item_detail')));
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_item_create_save')));
    await tester.enterText(
      find.byKey(const ValueKey('budget_item_create_description')),
      'Nuevo elemento de 50 mil',
    );
    await tester.enterText(find.byKey(const ValueKey('budget_item_create_amount')), '50.000');
    await _selectCreateDayOfMonth(tester, 20);
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_item_create_save')));
    await _waitForItemCount(budgetRef, 2);
    await tester.ensureVisible(find.text('Nuevo elemento de 50 mil'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo elemento de 50 mil'), findsOneWidget);
    await _assertBudgetAggregate(
      budgetRef,
      plannedAmount: 100000,
      itemCount: 2,
      activeDescriptions: const ['Elemento que se conserva', 'Nuevo elemento de 50 mil'],
      archivedDescriptions: const ['Elemento para archivar A', 'Elemento para archivar B'],
    );

    final itemQuery = await budgetRef
        .collection('items')
        .where('description', isEqualTo: 'Nuevo elemento de 50 mil')
        .get(const GetOptions(source: Source.server));
    final addedItemRef = itemQuery.docs.single.reference;
    expect(itemQuery.docs.single.data()['amountMinor'], 50000);
    // Callable receipts are intentionally server-only under Firestore rules;
    // their digest/result contract is verified by budget_commands_test.mjs.
    final accountsBeforeExpense = await firestore
        .collection('users')
        .doc(uid)
        .collection('accounts')
        .get(const GetOptions(source: Source.server));
    expect(accountsBeforeExpense.docs, hasLength(1));

    final recordItemAction = find.byKey(ValueKey('budget_item_row_${addedItemRef.id}'));
    await tester.ensureVisible(recordItemAction);
    await tester.pumpAndSettle();
    await tester.tap(recordItemAction);
    await _pumpUntil(tester, find.byKey(const ValueKey('planning_item_register')));
    await tester.tap(find.byKey(const ValueKey('planning_item_register')));
    await _pumpUntil(tester, find.byKey(const ValueKey('operation_save')));
    final amountField = find.byKey(const ValueKey('operation_amount'));
    await tester.enterText(amountField, '25000');
    await tester.tap(find.byKey(const ValueKey('operation_more_options')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('operation_description')),
      'Gasto sintético del elemento',
    );
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.ensureVisible(find.byKey(const ValueKey('operation_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('operation_save')));
    await _pumpUntil(tester, find.byKey(const ValueKey('planning_item_register')));
    await tester.pageBack();
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_detail_category')));
    await _waitForActualAmount(addedItemRef, 25000);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('budget_detail_category')),
      -350,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('budget_detail_scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    final operationQuery = await firestore
        .collection('users')
        .doc(uid)
        .collection('operations')
        .where('budgetId', isEqualTo: budgetId)
        .where('budgetItemId', isEqualTo: addedItemRef.id)
        .get(const GetOptions(source: Source.server));
    expect(operationQuery.docs, hasLength(1));
    expect(operationQuery.docs.single.data()['amountMinor'], 25000);
    expect(
      (await addedItemRef.get(
        const GetOptions(source: Source.server),
      )).data()?['actualAmountMinor'],
      25000,
    );
    final afterExpense = await budgetRef.get(const GetOptions(source: Source.server));
    expect(afterExpense.data()?['plannedAmountMinor'], 100000);
    expect(afterExpense.data()?['itemCount'], 2);
    final cashAccount =
        (await firestore
                .collection('users')
                .doc(uid)
                .collection('accounts')
                .get(const GetOptions(source: Source.server)))
            .docs
            .single;
    expect(cashAccount.data()['currentBalanceMinor'], 75000);
    expect(
      (await firestore
              .collection('users')
              .doc(uid)
              .collection('monthlySummaries')
              .doc('${monthKey}_COP')
              .get(const GetOptions(source: Source.server)))
          .data()?['expenseMinor'],
      25000,
    );
    await _assertBudgetAggregate(
      budgetRef,
      plannedAmount: 100000,
      itemCount: 2,
      activeDescriptions: const ['Elemento que se conserva', 'Nuevo elemento de 50 mil'],
      archivedDescriptions: const ['Elemento para archivar A', 'Elemento para archivar B'],
    );
    expect(
      find.byWidgetPredicate(
        (widget) {
          if (widget is! Text) return false;
          final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
          return RegExp(r'(restante|remaining)', caseSensitive: false).hasMatch(text) &&
              RegExp(r'75[\s.,\u00a0]?000').hasMatch(text);
        },
      ),
      findsOneWidget,
    );
  });

  testWidgets('explains unassociated category movements and links them without reprojecting', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    if (initializationError != null) {
      Error.throwWithStackTrace(initializationError!, initializationStack!);
    }
    final auth = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app);
    await auth.signOut();
    await tester.pumpWidget(const ProviderScope(child: PersonalFinanceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final email = 'budget-association-${DateTime.now().microsecondsSinceEpoch}@example.test';
    await tester.tap(find.byKey(const ValueKey('auth_signup_tab')));
    await tester.enterText(find.byKey(const ValueKey('auth_email_field')), email);
    await tester.enterText(
      find.byKey(const ValueKey('auth_password_field')),
      'ClearBudget-E2E-123',
    );
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.ensureVisible(find.byKey(const ValueKey('onboarding_current_balance')));
    await tester.enterText(find.byKey(const ValueKey('onboarding_current_balance')), '100000');
    await tester.enterText(find.byKey(const ValueKey('onboarding_account_name')), 'Cuenta QA');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
    await _pumpUntil(tester, find.byKey(const ValueKey('global_add_operation')));

    final uid = auth.currentUser!.uid;
    final firestore = FirebaseFirestore.instanceFor(app: FirebaseBootstrap.app);
    await tester.tap(find.byKey(const ValueKey('finance_nav_budget')));
    await _pumpUntil(tester, find.byKey(const ValueKey('budgets_create_button')));
    final monthKey = _currentMonthKey();
    final budgetId = '${monthKey}_expense_food_COP';
    final userRef = firestore.collection('users').doc(uid);
    final budgetRef = userRef.collection('budgets').doc(budgetId);
    await tester.tap(find.byKey(const ValueKey('budgets_create_button')).hitTestable());
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_save')));
    await _createBudget(tester, items: const [('Gasto de mercado', '50000')]);

    final itemSnapshot = await budgetRef
        .collection('items')
        .where('description', isEqualTo: 'Gasto de mercado')
        .get(const GetOptions(source: Source.server));
    final itemRef = itemSnapshot.docs.single.reference;
    final accountDocs = await userRef
        .collection('accounts')
        .get(const GetOptions(source: Source.server));
    final accountId = accountDocs.docs.single.id;
    final repository = getIt<CanonicalFinanceRepository>();
    final localNow = DateTime.now();
    final occurredAt = DateTime(localNow.year, localNow.month, localNow.day, 12).toUtc();
    final operationIds = ['associated-market', 'unassociated-market'];
    final descriptions = ['Compra ya asociada', 'Compra sin elemento'];
    final amounts = [20000, 25000];
    for (var index = 0; index < operationIds.length; index++) {
      final result = await repository.createOperation(
        uid,
        FinancialOperationDraft(
          type: OperationType.expense,
          amountMinor: amounts[index],
          currency: 'COP',
          accountId: accountId,
          occurredAt: occurredAt,
          monthKey: monthKey,
          description: descriptions[index],
          idempotencyKey: operationIds[index],
          categoryId: 'food',
          budgetId: index == 0 ? budgetId : null,
          budgetItemId: index == 0 ? itemRef.id : null,
        ),
      );
      expect(result.isRight(), isTrue);
    }

    await _pumpUntil(tester, find.byKey(ValueKey('budget_card_$budgetId')));
    await tester.tap(find.byKey(ValueKey('budget_card_tap_$budgetId')));
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_detail_category')));

    final operationCollection = userRef.collection('operations');
    final linkedQuery = await operationCollection
        .where('idempotencyKey', isEqualTo: operationIds.first)
        .get(const GetOptions(source: Source.server));
    final unlinkedQuery = await operationCollection
        .where('idempotencyKey', isEqualTo: operationIds.last)
        .get(const GetOptions(source: Source.server));
    expect(linkedQuery.docs, hasLength(1));
    expect(unlinkedQuery.docs, hasLength(1));
    final unlinkedRef = unlinkedQuery.docs.single.reference;

    final accountBeforeLink = (await accountDocs.docs.single.reference.get(
      const GetOptions(source: Source.server),
    )).data()?['currentBalanceMinor'];
    final summaryRef = userRef.collection('monthlySummaries').doc('${monthKey}_COP');
    final summaryBeforeLink = (await summaryRef.get(
      const GetOptions(source: Source.server),
    )).data()!['expenseMinor'];
    expect(accountBeforeLink, 55000);
    expect(summaryBeforeLink, 45000);
    expect(
      (await itemRef.get(const GetOptions(source: Source.server))).data()?['actualAmountMinor'],
      20000,
    );

    await tester.tap(find.byKey(const ValueKey('budget_detail_movements_tab')));
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_detail_movements_list')));
    await _pumpUntil(
      tester,
      find.byKey(ValueKey('budget_operation_${linkedQuery.docs.single.id}')),
    );
    expect(find.text('Compra ya asociada'), findsOneWidget);
    expect(find.text('Compra sin elemento'), findsOneWidget);
    final movementCard = find.byKey(ValueKey('budget_operation_${unlinkedRef.id}'));
    final l10n = AppLocalizations.of(tester.element(movementCard));
    final movementTile = tester.widget<ListTile>(
      find.descendant(of: movementCard, matching: find.byType(ListTile)),
    );
    final attribution = (movementTile.subtitle! as Text).data!;
    expect(
      attribution,
      contains(l10n.budgetMovementUnassociated),
      reason: 'Unexpected attribution for locale ${l10n.localeName}: $attribution',
    );
    final linkButton = find.byKey(ValueKey('budget_operation_associate_${unlinkedRef.id}'));
    await tester.ensureVisible(linkButton);
    await tester.tap(linkButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('budget_association_item_${itemRef.id}')));
    await tester.pumpAndSettle();
    await _waitForActualAmount(itemRef, 45000);

    expect(
      (await unlinkedRef.get(const GetOptions(source: Source.server))).data()?['budgetItemId'],
      itemRef.id,
    );
    expect(
      (await itemRef.get(const GetOptions(source: Source.server))).data()?['actualAmountMinor'],
      45000,
    );
    expect(
      (await accountDocs.docs.single.reference.get(
        const GetOptions(source: Source.server),
      )).data()?['currentBalanceMinor'],
      accountBeforeLink,
    );
    expect(
      (await summaryRef.get(const GetOptions(source: Source.server))).data()?['expenseMinor'],
      summaryBeforeLink,
    );
    final matchingOperations = await operationCollection
        .where('idempotencyKey', whereIn: operationIds)
        .get(const GetOptions(source: Source.server));
    expect(matchingOperations.docs, hasLength(2));
  });

  testWidgets('duplicate category opens its budget and preserves the creation draft', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    if (initializationError != null) {
      Error.throwWithStackTrace(initializationError!, initializationStack!);
    }
    final email = 'budget-duplicate-${DateTime.now().microsecondsSinceEpoch}@example.test';
    const password = 'ClearBudget-E2E-123';
    await tester.pumpWidget(const ProviderScope(child: PersonalFinanceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('auth_signup_tab')));
    await tester.enterText(find.byKey(const ValueKey('auth_email_field')), email);
    await tester.enterText(find.byKey(const ValueKey('auth_password_field')), password);
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.enterText(find.byKey(const ValueKey('onboarding_account_name')), 'Cuenta QA');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
    await _pumpUntil(tester, find.byKey(const ValueKey('global_add_operation')));

    final uid = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).currentUser!.uid;
    await tester.tap(find.byKey(const ValueKey('finance_nav_budget')));
    await tester.pumpAndSettle();
    await _pumpUntil(tester, find.byKey(const ValueKey('budgets_create_button')));
    await tester.tap(find.byKey(const ValueKey('budgets_create_button')).hitTestable());
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_save')));
    await _createBudget(tester, items: const [('Mercado existente', '50000')]);

    final monthKey = _currentMonthKey();
    final budgetId = '${monthKey}_expense_food_COP';
    final budgetRef = FirebaseFirestore.instanceFor(
      app: FirebaseBootstrap.app,
    ).collection('users').doc(uid).collection('budgets').doc(budgetId);
    await _pumpUntil(tester, find.byKey(ValueKey('budget_card_$budgetId')));

    await tester.tap(find.byKey(const ValueKey('budgets_create_button')).hitTestable());
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_save')));
    await _revealFormField(tester, find.byKey(const ValueKey('budget_item_description_0')), 300);
    await tester.enterText(
      find.byKey(const ValueKey('budget_item_description_0')),
      'Borrador duplicado QA',
    );
    await _revealFormField(tester, find.byKey(const ValueKey('budget_item_amount_0')), 300);
    await tester.enterText(find.byKey(const ValueKey('budget_item_amount_0')), '10000');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _revealFormField(
      tester,
      find.byKey(const ValueKey('budget_category_selector_expense')),
      -300,
    );
    await tester.tap(find.byKey(const ValueKey('budget_category_selector_tap')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alimentación').last);
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byKey(const ValueKey('budget_save'))));
    expect(find.text(l10n.budgetAlreadyExists), findsOneWidget);
    await tester.tap(find.text(l10n.openExistingBudget));
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_detail_category')));
    expect(
      (await budgetRef.collection('items').get(const GetOptions(source: Source.server))).docs,
      hasLength(1),
    );
    await tester.tap(find.byKey(const ValueKey('budget_detail_back')));
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_save')));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('budget_item_description_0')))
          .controller!
          .text,
      'Borrador duplicado QA',
    );
  });
}

Future<void> _createBudget(
  WidgetTester tester, {
  required List<(String, String)> items,
}) async {
  for (var index = 0; index < items.length; index++) {
    if (index > 0) {
      await _revealFormField(tester, find.byKey(const ValueKey('budget_add_item')), -300);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('budget_add_item')));
      await tester.pumpAndSettle();
    }
    final description = find.byKey(ValueKey('budget_item_description_$index'));
    final amount = find.byKey(ValueKey('budget_item_amount_$index'));
    await _revealFormField(tester, description, 300);
    await tester.pumpAndSettle();
    await tester.enterText(description, items[index].$1);
    await _revealFormField(tester, amount, 300);
    await tester.pumpAndSettle();
    await tester.enterText(amount, items[index].$2);
    await tester.pumpAndSettle();
  }
  tester.binding.focusManager.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final category = find.byKey(const ValueKey('budget_category_selector_expense'));
  await _revealFormField(tester, category, -300);
  await tester.tap(find.byKey(const ValueKey('budget_category_selector_tap')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('finance_popup_option_food')), findsOneWidget);
  await tester.tap(find.text('Alimentación').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('budget_save')));
  await tester.pumpAndSettle();
}

Future<void> _revealFormField(WidgetTester tester, Finder finder, double delta) async {
  await tester.scrollUntilVisible(
    finder.hitTestable(),
    delta,
    scrollable: find.byType(Scrollable).first,
  );
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
  final option = _dayOption(day);
  await tester.scrollUntilVisible(
    option,
    -220,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(option.last);
  await tester.pumpAndSettle();
}

Future<void> _selectCreateDayOfMonth(WidgetTester tester, int day) async {
  final selector = find.descendant(
    of: find.byKey(const ValueKey('budget_item_create_day')),
    matching: find.byType(DropdownButtonFormField<int>),
  );
  expect(selector, findsOneWidget);
  await tester.tap(selector);
  await tester.pumpAndSettle();
  final option = _dayOption(day);
  await tester.scrollUntilVisible(
    option,
    -220,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(option.last);
  await tester.pumpAndSettle();
}

Finder _dayOption(int day) => find.byWidgetPredicate((widget) {
  if (widget is! Text) return false;
  final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
  return RegExp('^(Día|Day|Dia) $day\$').hasMatch(text);
});

Future<void> _archiveBudgetItem(
  WidgetTester tester,
  DocumentReference<Map<String, dynamic>> budgetRef,
  String description,
) async {
  final itemQuery = await budgetRef
      .collection('items')
      .where('description', isEqualTo: description)
      .get(const GetOptions(source: Source.server));
  final itemId = itemQuery.docs.single.id;
  final card = find.ancestor(of: find.text(description), matching: find.byType(Card)).first;
  final remove = find.descendant(
    of: card,
    matching: find.byKey(ValueKey('budget_item_actions_$itemId')),
  );
  await tester.ensureVisible(remove);
  await tester.pumpAndSettle();
  await tester.tap(remove);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('budget_item_remove_$itemId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('confirm_budget_item_delete')));
  await tester.pumpAndSettle();
}

Future<void> _assertBudgetAggregate(
  DocumentReference<Map<String, dynamic>> budgetRef, {
  required int plannedAmount,
  required int itemCount,
  required List<String> activeDescriptions,
  required List<String> archivedDescriptions,
}) async {
  DocumentSnapshot<Map<String, dynamic>>? budget;
  QuerySnapshot<Map<String, dynamic>>? items;
  for (var attempt = 0; attempt < 40; attempt++) {
    budget = await budgetRef.get(const GetOptions(source: Source.server));
    items = await budgetRef.collection('items').get(const GetOptions(source: Source.server));
    final currentActive = items.docs.where((item) => item.data()['status'] != 'archived').toList();
    final currentTotal = currentActive.fold<int>(
      0,
      (total, item) => total + ((item.data()['amountMinor'] as num?) ?? 0).toInt(),
    );
    if (budget.data()?['plannedAmountMinor'] == plannedAmount &&
        budget.data()?['itemCount'] == itemCount &&
        currentTotal == plannedAmount &&
        currentActive.length == itemCount) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  expect(budget!.data()?['plannedAmountMinor'], plannedAmount);
  expect(budget.data()?['itemCount'], itemCount);
  final active = items!.docs.where((item) => item.data()['status'] != 'archived').toList();
  final archived = items.docs.where((item) => item.data()['status'] == 'archived').toList();
  expect(active.map((item) => item.data()['description']), unorderedEquals(activeDescriptions));
  expect(archived.map((item) => item.data()['description']), unorderedEquals(archivedDescriptions));
  expect(
    active.fold<int>(0, (total, item) => total + (item.data()['amountMinor'] as num).toInt()),
    plannedAmount,
  );
}

String _currentMonthKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (finder.hitTestable().evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  expect(
    finder.hitTestable(),
    findsOneWidget,
    reason: 'The target must be visible and interactive.',
  );
}

Future<void> _waitForItemCount(
  DocumentReference<Map<String, dynamic>> budgetRef,
  int expectedCount,
) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final snapshot = await budgetRef.get(const GetOptions(source: Source.server));
    if (snapshot.data()?['itemCount'] == expectedCount) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError('Budget item count did not reach $expectedCount.');
}

Future<void> _waitForActualAmount(
  DocumentReference<Map<String, dynamic>> itemRef,
  int expectedAmount,
) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final snapshot = await itemRef.get(const GetOptions(source: Source.server));
    if ((snapshot.data()?['actualAmountMinor'] as num? ?? 0).toInt() == expectedAmount) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError('Budget item actual amount did not reach $expectedAmount.');
}
