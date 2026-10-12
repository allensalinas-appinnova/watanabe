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

  testWidgets('registers, creates three account types, and edits their names', (tester) async {
    final email = 'accounts-${DateTime.now().microsecondsSinceEpoch}@example.test';
    const password = 'ClearBudget-E2E-123';
    await tester.pumpWidget(const ProviderScope(child: PersonalFinanceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.byKey(const ValueKey('auth_signup_tab')));
    await tester.enterText(find.byKey(const ValueKey('auth_email_field')), email);
    await tester.enterText(find.byKey(const ValueKey('auth_password_field')), password);
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byKey(const ValueKey('onboarding_account_name')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('onboarding_account_name')), 'Cuenta inicial');
    await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
    await _pumpUntil(tester, find.byKey(const ValueKey('home_add_income')));

    final userId = FirebaseAuth.instance.currentUser!.uid;
    await tester.tap(find.byKey(const ValueKey('home_accounts_nav')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    const cases = [
      (
        name: 'Efectivo E2E',
        type: 'cash',
        currency: 'COP',
        balance: '125000',
        minor: 125000,
      ),
      (
        name: 'Corriente E2E',
        type: 'checking',
        currency: 'MXN',
        balance: '250.50',
        minor: 25050,
      ),
      (
        name: 'Ahorros E2E',
        type: 'savings',
        currency: 'BRL',
        balance: '1000,75',
        minor: 100075,
      ),
    ];
    final ids = <String, String>{};
    for (final accountCase in cases) {
      await tester.tap(find.byKey(const ValueKey('accounts_add_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('account_name_field')),
        accountCase.name,
      );
      if (accountCase.type != 'cash') {
        await _selectDropdown(
          tester,
          'account_type_selector',
          'account_type_option_${accountCase.type}',
        );
      }
      if (accountCase.currency != 'COP') {
        await _selectDropdown(
          tester,
          'account_currency_selector',
          'account_currency_option_${accountCase.currency}',
        );
      }
      await tester.enterText(
        find.byKey(const ValueKey('account_initial_balance_field')),
        accountCase.balance,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('account_save')));
      await tester.tap(find.byKey(const ValueKey('account_save')));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await _pumpUntil(tester, find.text(accountCase.name));
      ids[accountCase.name] = await _waitForAccount(
        userId,
        name: accountCase.name,
        expectedType: accountCase.type,
        expectedCurrency: accountCase.currency,
        expectedBalanceMinor: accountCase.minor,
      );
    }

    for (final accountCase in cases) {
      final id = ids[accountCase.name]!;
      await tester.tap(find.byKey(ValueKey('account_menu_$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account_edit_action')));
      await tester.pumpAndSettle();
      final editedName = '${accountCase.name} Editada';
      await tester.enterText(find.byKey(const ValueKey('account_name_field')), editedName);
      await tester.tap(find.byKey(const ValueKey('account_save')));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await _pumpUntil(tester, find.text(editedName));
      await _waitForAccount(
        userId,
        name: editedName,
        expectedType: accountCase.type,
        expectedCurrency: accountCase.currency,
        expectedBalanceMinor: accountCase.minor,
      );
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('accounts')
        .get(const GetOptions(source: Source.server));
    expect(
      snapshot.docs,
      hasLength(4),
      reason: 'One onboarding account plus exactly three created accounts.',
    );
    for (final accountCase in cases) {
      final matches = snapshot.docs.where(
        (doc) => doc.data()['name'] == '${accountCase.name} Editada',
      );
      expect(matches, hasLength(1), reason: 'Expected exactly one edited account.');
      final data = matches.single.data();
      expect(data['type'], accountCase.type);
      expect(data['currency'], accountCase.currency);
      expect(data['openingBalanceMinor'], accountCase.minor);
      expect(data['currentBalanceMinor'], accountCase.minor);
      expect(data['status'], 'active');
      expect(find.text('${accountCase.name} Editada'), findsOneWidget);
      expect(find.text(accountCase.name), findsNothing);
    }
  });
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}

Future<void> _selectDropdown(WidgetTester tester, String selectorKey, String optionKey) async {
  await tester.ensureVisible(find.byKey(ValueKey(selectorKey)));
  await tester.tap(find.byKey(ValueKey(selectorKey)));
  await tester.pumpAndSettle();
  final optionFinder = find.byKey(ValueKey(optionKey));
  expect(optionFinder, findsOneWidget, reason: 'Missing account option: $optionKey');
  await tester.tap(optionFinder);
  await tester.pumpAndSettle();
}

Future<String> _waitForAccount(
  String userId, {
  required String name,
  required String expectedType,
  required String expectedCurrency,
  required int expectedBalanceMinor,
}) async {
  final query = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('accounts')
      .where('name', isEqualTo: name)
      .limit(2);
  for (var attempt = 0; attempt < 30; attempt++) {
    final snapshot = await query.get(const GetOptions(source: Source.server));
    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.single.data();
      expect(data['type'], expectedType);
      expect(data['currency'], expectedCurrency);
      expect(data['openingBalanceMinor'], expectedBalanceMinor);
      expect(data['currentBalanceMinor'], expectedBalanceMinor);
      return snapshot.docs.single.id;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  fail('Timed out waiting for account "$name" in Firestore.');
}
