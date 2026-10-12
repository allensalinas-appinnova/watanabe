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
    await FirebaseAuth.instance.signOut();
  });

  tearDownAll(() async {
    await FirebaseAuth.instance.signOut();
    await GetIt.I.reset();
  });

  testWidgets('creates, edits, removes and archives a budget safely', (tester) async {
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

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await tester.tap(find.byKey(const ValueKey('nav_budget')));
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
    final budgetRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .doc(budgetId);
    await _pumpUntil(tester, find.byKey(ValueKey('budget_card_$budgetId')));
    await tester.tap(find.byKey(ValueKey('budget_card_tap_$budgetId')));
    await _pumpUntil(tester, find.byKey(const ValueKey('budget_detail_category')));

    final marketCard = find.ancestor(
      of: find.text('Mercado semanal'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: marketCard, matching: find.byKey(const ValueKey('budget_item_edit'))),
    );
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
    await tester.tap(
      find.descendant(of: fruitCard, matching: find.byKey(const ValueKey('budget_item_remove'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_budget_item_delete')));
    await tester.pumpAndSettle();
    await _waitForItemCount(budgetRef, 1);

    final budget = await budgetRef.get(const GetOptions(source: Source.server));
    final items = await budgetRef.collection('items').get(const GetOptions(source: Source.server));
    expect(budget.data()?['plannedAmountMinor'], 325000);
    expect(budget.data()?['itemCount'], 1);
    expect(items.docs, hasLength(1));
    expect(items.docs.single.data()['description'], 'Mercado quincenal');

    final lastItemResult = await getIt<CanonicalFinanceRepository>().deleteBudgetItem(
      uid,
      budgetId,
      items.docs.single.id,
    );
    expect(lastItemResult.match((failure) => failure, (_) => null), isA<ConflictFailure>());
    expect(
      (await items.docs.single.reference.get(const GetOptions(source: Source.server))).exists,
      isTrue,
    );
    expect(find.byKey(const ValueKey('budget_item_remove')), findsNothing);
    expect(find.byKey(const ValueKey('budget_last_item_hint')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('budget_add_item_detail')));
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
    await tester.tap(
      find.descendant(of: servicesCard, matching: find.byKey(const ValueKey('budget_item_remove'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_budget_item_delete')));
    await tester.pumpAndSettle();
    await _waitForItemCount(budgetRef, 1);
    final afterRemovingAddedItem = await budgetRef.get(const GetOptions(source: Source.server));
    expect(afterRemovingAddedItem.data()?['plannedAmountMinor'], 325000);

    await tester.tap(find.byKey(const ValueKey('budget_archive_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_budget_archive')));
    await tester.pumpAndSettle();
    final archived = await budgetRef.get(const GetOptions(source: Source.server));
    expect(archived.data()?['status'], 'archived');
    final activeBudgets = await getIt<CanonicalFinanceRepository>()
        .watchBudgets(uid, monthKey)
        .first;
    expect(activeBudgets.any((budget) => budget.id == budgetId), isFalse);
  });
}

Future<void> _createBudget(
  WidgetTester tester, {
  required List<(String, String)> items,
}) async {
  for (var index = 0; index < items.length; index++) {
    if (index > 0) {
      await tester.ensureVisible(find.byKey(const ValueKey('budget_add_item')));
      await tester.tap(find.byKey(const ValueKey('budget_add_item')));
      await tester.pumpAndSettle();
    }
    final description = find.byKey(ValueKey('budget_item_description_$index'));
    final amount = find.byKey(ValueKey('budget_item_amount_$index'));
    await tester.ensureVisible(description);
    await tester.enterText(description, items[index].$1);
    await tester.ensureVisible(amount);
    await tester.enterText(amount, items[index].$2);
    await tester.pumpAndSettle();
  }
  tester.binding.focusManager.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final category = find.byKey(const ValueKey('budget_category_selector'));
  await tester.ensureVisible(category);
  await tester.tap(category);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Alimentación').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('budget_save')));
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
  expect(finder, findsOneWidget);
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
