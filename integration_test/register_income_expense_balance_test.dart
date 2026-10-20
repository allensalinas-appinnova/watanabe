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

/// Verifies the real UI path for a new user, account, income, and expense.
///
/// Run with [tool/run_emulator_e2e.sh] so Auth, Firestore, Storage and
/// Functions are available and the derived account balance can be verified.
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

  testWidgets('registers a user and verifies income minus expense balance', (tester) async {
    final email = 'balance-${DateTime.now().microsecondsSinceEpoch}@example.test';
    const password = 'ClearBudget-E2E-123';

    await tester.pumpWidget(const ProviderScope(child: PersonalFinanceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('auth_signup_tab')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('auth_signup_tab')));
    await tester.enterText(find.byKey(const ValueKey('auth_email_field')), email);
    await tester.enterText(find.byKey(const ValueKey('auth_password_field')), password);
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byKey(const ValueKey('onboarding_account_name')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('onboarding_account_name')),
      'Cuenta inicial',
    );
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
    await _pumpUntil(tester, find.byKey(const ValueKey('global_add_operation')));

    final uid = FirebaseAuth.instance.currentUser?.uid;
    expect(uid, isNotNull, reason: 'The registration flow must leave an authenticated user.');

    await tester.tap(find.byKey(const ValueKey('finance_nav_accounts')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('accounts_add_button')));
    await _pumpUntil(tester, find.byKey(const ValueKey('account_name_field')));
    await tester.enterText(find.byKey(const ValueKey('account_name_field')), 'Banco1 Ahorros');
    await tester.enterText(find.byKey(const ValueKey('account_initial_balance_field')), '0');
    await tester.tap(find.byKey(const ValueKey('account_save')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Banco1 Ahorros'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('finance_nav_home')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('global_add_operation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_movement_income')));
    await tester.pumpAndSettle();
    await _selectDropdown(tester, 'operation_account_selector', 'Banco1 Ahorros (COP)');
    await _selectDropdown(tester, 'operation_category_selector', 'Salario');
    await tester.tap(find.byKey(const ValueKey('operation_more_options')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('operation_amount')), '100');
    await tester.enterText(find.byKey(const ValueKey('operation_description')), 'Salario');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final incomeSave = find.byKey(const ValueKey('operation_save'));
    final operationScrollable = find
        .ancestor(
          of: find.byKey(const ValueKey('operation_amount')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      incomeSave,
      240,
      scrollable: operationScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(incomeSave);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final accountId = await _waitForAccountBalance(
      uid!,
      name: 'Banco1 Ahorros',
      expectedBalanceMinor: 100,
    );
    expect(accountId, isNotEmpty);

    await tester.tap(find.byKey(const ValueKey('global_add_operation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_movement_expense')));
    await tester.pumpAndSettle();
    await _selectDropdown(tester, 'operation_account_selector', 'Banco1 Ahorros (COP)');
    await _selectDropdown(tester, 'operation_category_selector', 'Alimentación');
    await tester.tap(find.byKey(const ValueKey('operation_more_options')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('operation_amount')), '80');
    await tester.enterText(find.byKey(const ValueKey('operation_description')), 'Mercado');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final expenseSave = find.byKey(const ValueKey('operation_save'));
    final expenseScrollable = find
        .ancestor(
          of: find.byKey(const ValueKey('operation_amount')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      expenseSave,
      240,
      scrollable: expenseScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(expenseSave);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await _waitForAccountBalance(
      uid,
      name: 'Banco1 Ahorros',
      expectedBalanceMinor: 20,
    );

    await tester.tap(find.byKey(const ValueKey('finance_nav_accounts')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final row = find.byKey(ValueKey('account_row_$accountId'));
    expect(row, findsOneWidget);
    expect(find.byKey(ValueKey('account_balance_$accountId')), findsOneWidget);
    final balanceText = tester.widget<Text>(find.byKey(ValueKey('account_balance_$accountId')));
    expect(balanceText.data, contains('20'));
  });
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}

Future<void> _selectDropdown(WidgetTester tester, String key, String option) async {
  final exact = find.byKey(ValueKey(key));
  final finder = exact.evaluate().isNotEmpty
      ? exact
      : find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey && '${(widget.key! as ValueKey).value}'.startsWith(key),
        );
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
  final optionFinder = find.text(option);
  expect(optionFinder, findsWidgets, reason: 'Missing dropdown option: $option');
  await tester.tap(optionFinder.last);
  await tester.pumpAndSettle();
}

Future<String> _waitForAccountBalance(
  String userId, {
  required String name,
  required int expectedBalanceMinor,
}) async {
  final query = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('accounts')
      .where('name', isEqualTo: name)
      .limit(1);
  for (var attempt = 0; attempt < 30; attempt++) {
    final snapshot = await query.get(const GetOptions(source: Source.server));
    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.single.data();
      if (data['currentBalanceMinor'] == expectedBalanceMinor) return snapshot.docs.single.id;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  final snapshot = await query.get(const GetOptions(source: Source.server));
  final actual = snapshot.docs.isEmpty ? null : snapshot.docs.single.data()['currentBalanceMinor'];
  final operations = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('operations')
      .get(const GetOptions(source: Source.server));
  fail(
    'Timed out waiting for $name balance $expectedBalanceMinor; actual=$actual; '
    'operations=${operations.docs.map((doc) => doc.data()).toList()}',
  );
}
