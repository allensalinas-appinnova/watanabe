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
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';

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

  testWidgets('creates, edits, removes and archives a budget safely', (tester) async {
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
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_empty_create')));
    await tester.tap(find.byKey(const ValueKey('budget_empty_create')));
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
    await tester.tap(find.byKey(ValueKey('budget_item_record_${linkedItemRef.id}')));
    await _pumpUntil(tester, find.byKey(const ValueKey('operation_save')));
    final amountField = find.byKey(const ValueKey('operation_amount'));
    expect(tester.widget<TextFormField>(amountField).controller!.text, '300000');
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('operation_category_selector')),
          )
          .onChanged,
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
      matching: find.byKey(const ValueKey('budget_item_edit')),
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
    await tester.enterText(
      find.byKey(const ValueKey('budget_item_edit_description')),
      'Mercado quincenal',
    );
    await tester.enterText(find.byKey(const ValueKey('budget_item_edit_amount')), '325000');
    await tester.enterText(find.byKey(const ValueKey('budget_item_edit_day')), '18');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_item_edit_save')));
    await _pumpUntil(tester, find.text('Frutas'));

    final fruitCard = find.ancestor(of: find.text('Frutas'), matching: find.byType(Card));
    final fruitRemove = find.descendant(
      of: fruitCard,
      matching: find.byKey(const ValueKey('budget_item_remove')),
    );
    await tester.ensureVisible(fruitRemove);
    await tester.pumpAndSettle();
    await tester.tap(fruitRemove);
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
    expect(find.byKey(const ValueKey('budget_item_remove')), findsNothing);
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
    await tester.enterText(find.byKey(const ValueKey('budget_item_create_day')), '12');
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

    final servicesCard = find.ancestor(
      of: find.text('Servicios públicos'),
      matching: find.byType(Card),
    );
    final servicesRemove = find.descendant(
      of: servicesCard,
      matching: find.byKey(const ValueKey('budget_item_remove')),
    );
    await tester.ensureVisible(servicesRemove);
    await tester.pumpAndSettle();
    await tester.tap(servicesRemove);
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
    await tester.enterText(find.byKey(const ValueKey('budget_item_create_day')), '22');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('budget_item_create_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_item_create_save')));
    await _pumpUntil(tester, find.text('Reserva'));

    final linkedCard = find.ancestor(
      of: find.text('Mercado quincenal'),
      matching: find.byType(Card),
    );
    final linkedRemove = find.descendant(
      of: linkedCard,
      matching: find.byKey(const ValueKey('budget_item_remove')),
    );
    await tester.ensureVisible(linkedRemove);
    await tester.pumpAndSettle();
    await tester.tap(linkedRemove);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_budget_item_delete')));
    await _pumpUntil(
      tester,
      find.byKey(ValueKey('budget_linked_operation_${linkedOperationRef.id}')),
    );
    await _waitForItemCount(budgetRef, 1);
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

    await linkedOperationRef.update({'status': 'rejected', 'updatedAt': Timestamp.now()});
    await _waitForActualAmount(linkedItemRef, 0);

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
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_empty_create')));
    await tester.tap(find.byKey(const ValueKey('budget_empty_create')));
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
  final category = find.byKey(const ValueKey('budget_category_selector'));
  await _revealFormField(tester, category, -300);
  await tester.tap(category);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Alimentación').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('budget_save')));
  await tester.pumpAndSettle();
}

Future<void> _revealFormField(WidgetTester tester, Finder finder, double delta) async {
  await tester.scrollUntilVisible(
    finder.hitTestable(),
    delta,
    scrollable: find.descendant(of: find.byType(Form), matching: find.byType(Scrollable)).first,
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
