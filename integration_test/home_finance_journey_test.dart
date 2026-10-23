import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/firebase/firebase_bootstrap.dart';
import 'package:personal_finance/core/utils/currency_formatter.dart';
import 'package:personal_finance/features/debts/domain/debt_command.dart';
import 'package:personal_finance/features/debts/domain/debt_repository.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';

/// Full financial journey against Auth, Firestore and Functions emulators.
///
/// Run with:
/// `E2E_TEST_FILE=integration_test/home_finance_journey_test.dart tool/run_emulator_e2e.sh <device>`
/// The initial account and user are created through the app UI. Additional
/// resources and operations use the same repositories/callables as the UI so
/// every server projection is exercised, while Home remains mounted to verify
/// each resulting balance and both budget ratios.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      throw StateError('This journey must run against Firebase Emulator.');
    }
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '10.0.2.2');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final response = await client
          .getUrl(Uri(scheme: 'http', host: host, port: 59199))
          .then((request) => request.close());
      await response.drain<void>();
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('Auth Emulator is unavailable: ${response.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
    await FirebaseBootstrap.initialize(
      AppEnvironment.dev,
      useEmulators: true,
      emulatorHost: host,
    );
    if (FirebaseBootstrap.app.options.projectId != 'demo-clearbudget') {
      throw StateError('Refusing E2E run outside the synthetic demo-clearbudget project.');
    }
    await configureDependencies(useEmulators: true);
    await FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).signOut();
  });

  tearDownAll(() async {
    await FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).signOut();
    await GetIt.I.reset();
  });

  testWidgets(
    'creates a complete financial profile and keeps Home balances and budget ratios current',
    (tester) async {
      final email = 'home-journey-${DateTime.now().microsecondsSinceEpoch}@example.test';
      const password = 'LumioMoney-E2E-123';
      await tester.pumpWidget(const ProviderScope(child: PersonalFinanceApp()));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.byKey(const ValueKey('auth_signup_tab')));
      await tester.enterText(find.byKey(const ValueKey('auth_email_field')), email);
      await tester.enterText(find.byKey(const ValueKey('auth_password_field')), password);
      await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
      await _pumpUntil(tester, find.byKey(const ValueKey('onboarding_account_name')));
      await tester.enterText(
        find.byKey(const ValueKey('onboarding_account_name')),
        'Cuenta E2E 1',
      );
      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
      await _pumpUntil(tester, find.byKey(const ValueKey('home_balance_card')));

      final user = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).currentUser;
      expect(user, isNotNull, reason: 'The test must create a Firebase Auth user.');
      final uid = user!.uid;
      final firestore = FirebaseFirestore.instanceFor(app: FirebaseBootstrap.app);
      final userDocument = firestore.collection('users').doc(uid);
      final repository = getIt<CanonicalFinanceRepository>();
      final debtRepository = getIt<DebtRepository>();

      final accountNames = ['Cuenta E2E 1', 'Cuenta E2E 2', 'Cuenta E2E 3'];
      final accountIds = <String>[];
      for (final name in accountNames) {
        if (name == accountNames.first) {
          final account = await _waitForAccount(userDocument, name);
          accountIds.add(account.id);
          expect(account.data()['currentBalanceMinor'], 0);
          continue;
        }
        final result = await repository.createAccount(
          uid,
          name: name,
          type: 'checking',
          currency: 'COP',
          openingBalanceMinor: 0,
        );
        final account = result.match(
          (failure) => throw StateError('Could not create $name: ${failure.message}'),
          (value) => value,
        );
        accountIds.add(account.id);
      }
      expect(accountIds, hasLength(3));

      final now = DateTime.now();
      final referenceAt = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final debtIds = <String>[];
      for (var index = 1; index <= 2; index++) {
        final result = await debtRepository.execute(
          uid,
          DebtCommand(
            requestId: 'e2e_card_${now.microsecondsSinceEpoch}_$index',
            fields: {
              'action': 'create',
              'name': 'Tarjeta E2E $index',
              'product': 'creditCard',
              'currency': 'COP',
              'mode': 'existing',
              'referenceAt': referenceAt,
              'debtMinor': 0,
            },
          ),
        );
        debtIds.add(
          result.match(
            (failure) => throw StateError('Could not create card $index: ${failure.message}'),
            (value) => value.accountId,
          ),
        );
      }
      final loanResult = await debtRepository.execute(
        uid,
        DebtCommand(
          requestId: 'e2e_loan_${now.microsecondsSinceEpoch}',
          fields: {
            'action': 'create',
            'name': 'Crédito E2E',
            'product': 'bankLoan',
            'currency': 'COP',
            'mode': 'existing',
            'referenceAt': referenceAt,
            'principalMinor': 100000,
            'chargesMinor': 0,
          },
        ),
      );
      debtIds.add(
        loanResult.match(
          (failure) => throw StateError('Could not create loan: ${failure.message}'),
          (value) => value.accountId,
        ),
      );
      expect(debtIds, hasLength(3));
      final debtAccounts = await userDocument
          .collection('accounts')
          .where('nature', isEqualTo: 'debt')
          .get(const GetOptions(source: Source.server));
      expect(debtAccounts.docs, hasLength(3), reason: 'Two cards and one loan must exist.');

      final month = DateTime(now.year, now.month);
      final monthKey = DateFormat('yyyy-MM').format(month);
      final budgetSpecs = [
        ('expense', 'food', 300),
        ('expense', 'transport', 300),
        ('income', 'salary', 600),
        ('income', 'freelance', 600),
      ];
      for (final (flowType, categoryId, amount) in budgetSpecs) {
        final result = await repository.createBudgetWithItems(
          uid,
          categoryId: categoryId,
          flowType: flowType,
          monthKey: monthKey,
          currency: 'COP',
          requestId: 'e2e_budget_${now.microsecondsSinceEpoch}_${flowType}_$categoryId',
          items: [
            CanonicalBudgetItemDraft(
              description: 'Plan E2E $categoryId',
              amountMinor: amount,
              dayOfMonth: now.day,
            ),
          ],
        );
        result.match(
          (failure) => throw StateError(
            'Could not create $flowType budget for $categoryId: ${failure.message}',
          ),
          (_) {},
        );
      }
      final budgets = await userDocument
          .collection('budgets')
          .where('monthKey', isEqualTo: monthKey)
          .get(const GetOptions(source: Source.server));
      expect(budgets.docs.where((doc) => doc.data()['flowType'] == 'expense'), hasLength(2));
      expect(budgets.docs.where((doc) => doc.data()['flowType'] == 'income'), hasLength(2));

      var expectedHomeBalance = 0;
      final accountBalancesById = {for (final id in accountIds) id: 0};
      await _expectHomeBalance(tester, expectedHomeBalance);
      var operationNumber = 0;
      for (var index = 0; index < accountIds.length; index++) {
        final accountId = accountIds[index];
        final movements = [
          (OperationType.income, 'other_income', 10, 'Sin presupuesto ingreso'),
          (OperationType.expense, 'other_expense', 5, 'Sin presupuesto gasto'),
          (OperationType.income, 'salary', 200, 'Ingreso presupuestado'),
          (OperationType.expense, 'food', 100, 'Gasto presupuestado'),
        ];
        for (final (type, categoryId, amount, description) in movements) {
          final result = await repository.createOperation(
            uid,
            FinancialOperationDraft(
              type: type,
              amountMinor: amount,
              currency: 'COP',
              accountId: accountId,
              categoryId: categoryId,
              occurredAt: DateTime.now(),
              description: '$description ${index + 1}',
              idempotencyKey: 'homejourney-${now.microsecondsSinceEpoch}-${operationNumber++}',
            ),
          );
          result.match(
            (failure) => throw StateError('Movement failed: ${failure.message}'),
            (_) {},
          );
          expectedHomeBalance += type == OperationType.income ? amount : -amount;
          accountBalancesById[accountId] =
              accountBalancesById[accountId]! + (type == OperationType.income ? amount : -amount);
          await _waitForAccountBalance(
            userDocument,
            accountId: accountId,
            expectedBalance: accountBalancesById[accountId]!,
          );
          await _expectHomeBalance(tester, expectedHomeBalance);
        }
      }

      // Debt-account actions also remain visible in Home without changing the
      // cash total. Purchases/charges are expenses; no debt action is treated
      // as income or as a bank-account movement.
      var debtExpenseMinor = 0;
      for (var index = 0; index < debtIds.length; index++) {
        final action = index < 2 ? 'purchase' : 'charge';
        final debtAccountId = debtIds[index];
        final movements = [
          ('other_expense', 5, 'Gasto sin presupuesto'),
          ('other_expense', 5, 'Segundo gasto sin presupuesto'),
          ('food', 100, 'Primer gasto presupuestado'),
          ('food', 100, 'Segundo gasto presupuestado'),
        ];
        for (var movementIndex = 0; movementIndex < movements.length; movementIndex++) {
          final (categoryId, amount, description) = movements[movementIndex];
          final previousBalance = await _readAccountBalance(userDocument, debtAccountId);
          final result = await debtRepository.execute(
            uid,
            DebtCommand(
              requestId: 'e2e_debt_move_${now.microsecondsSinceEpoch}_${index}_$movementIndex',
              fields: {
                'action': action,
                'accountId': debtAccountId,
                'occurredAt': DateTime.now().toUtc().toIso8601String(),
                'amountMinor': amount,
                'categoryId': categoryId,
                'description': '$description ${index + 1}',
              },
            ),
          );
          result.match(
            (failure) => throw StateError('Debt movement failed: ${failure.message}'),
            (_) {},
          );
          debtExpenseMinor += amount;
          await _waitForChangedAccountBalance(userDocument, debtAccountId, previousBalance);
          await _expectHomeBalance(tester, expectedHomeBalance);
        }
      }

      final totalExpenseMinor = 315 + debtExpenseMinor;
      await _waitForMonthlySummary(
        userDocument,
        monthKey,
        income: 630,
        expense: totalExpenseMinor,
      );
      await _expectBudgetRatio(tester, 'home_expense_budget_percent', totalExpenseMinor / 600);
      await _expectBudgetRatio(tester, 'home_income_budget_percent', 630 / 1200);

      final beforeTransfers = expectedHomeBalance;
      final transferSpecs = [
        (accountIds[0], accountIds[1], 25),
        (accountIds[1], accountIds[2], 10),
      ];
      for (var index = 0; index < transferSpecs.length; index++) {
        final (source, destination, amount) = transferSpecs[index];
        final sourceBalance = accountBalancesById[source]!;
        final destinationBalance = accountBalancesById[destination]!;
        final result = await repository.createTransfer(
          uid,
          TransferDraft(
            amountMinor: amount,
            currency: 'COP',
            sourceAccountId: source,
            destinationAccountId: destination,
            occurredAt: DateTime.now(),
            description: 'Transferencia E2E ${index + 1}',
            idempotencyKey: 'homejourney-transfer-${now.microsecondsSinceEpoch}-$index',
          ),
        );
        result.match(
          (failure) => throw StateError('Transfer failed: ${failure.message}'),
          (_) {},
        );
        accountBalancesById[source] = sourceBalance - amount;
        accountBalancesById[destination] = destinationBalance + amount;
        await _waitForAccountBalance(
          userDocument,
          accountId: source,
          expectedBalance: accountBalancesById[source]!,
        );
        await _waitForAccountBalance(
          userDocument,
          accountId: destination,
          expectedBalance: accountBalancesById[destination]!,
        );
        await _expectHomeBalance(tester, beforeTransfers);
      }

      final accountBalances = <int>[];
      for (final accountId in accountIds) {
        accountBalances.add(await _readAccountBalance(userDocument, accountId));
      }
      expect(accountBalances, [80, 120, 115]);
      expect(accountBalances.fold<int>(0, (total, balance) => total + balance), beforeTransfers);
      expect(
        (await userDocument.collection('operations').get(const GetOptions(source: Source.server)))
            .docs
            .where((doc) => doc.data()['type'] == 'transfer'),
        hasLength(2),
      );
    },
  );
}

Future<QueryDocumentSnapshot<Map<String, dynamic>>> _waitForAccount(
  DocumentReference<Map<String, dynamic>> userDocument,
  String name,
) async {
  final query = userDocument.collection('accounts').where('name', isEqualTo: name).limit(1);
  for (var attempt = 0; attempt < 30; attempt++) {
    final snapshot = await query.get(const GetOptions(source: Source.server));
    if (snapshot.docs.isNotEmpty) return snapshot.docs.single;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  fail('Timed out waiting for account $name.');
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget, reason: 'Timed out waiting for the expected UI state.');
}

Future<int> _readAccountBalance(
  DocumentReference<Map<String, dynamic>> userDocument,
  String accountId,
) async {
  final snapshot = await userDocument
      .collection('accounts')
      .doc(accountId)
      .get(const GetOptions(source: Source.server));
  return snapshot.data()?['currentBalanceMinor'] as int? ??
      (snapshot.data()?['openingBalanceMinor'] as int? ?? 0);
}

Future<void> _waitForChangedAccountBalance(
  DocumentReference<Map<String, dynamic>> userDocument,
  String accountId,
  int previousBalance,
) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    if (await _readAccountBalance(userDocument, accountId) != previousBalance) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  fail('Debt account $accountId balance did not change after a confirmed command.');
}

Future<void> _waitForAccountBalance(
  DocumentReference<Map<String, dynamic>> userDocument, {
  required String accountId,
  required int expectedBalance,
}) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    if (await _readAccountBalance(userDocument, accountId) == expectedBalance) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  fail('Timed out waiting for account $accountId balance $expectedBalance.');
}

Future<void> _waitForMonthlySummary(
  DocumentReference<Map<String, dynamic>> userDocument,
  String monthKey, {
  required int income,
  required int expense,
}) async {
  final query = userDocument.collection('monthlySummaries').doc('${monthKey}_COP');
  for (var attempt = 0; attempt < 60; attempt++) {
    final snapshot = await query.get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data?['incomeMinor'] == income && data?['expenseMinor'] == expense) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  final snapshot = await query.get(const GetOptions(source: Source.server));
  fail('Monthly summary did not converge: ${snapshot.data()}');
}

Future<void> _expectHomeBalance(WidgetTester tester, int expected) async {
  final card = find.byKey(const ValueKey('home_balance_card'));
  await tester.scrollUntilVisible(
    card,
    -400,
    scrollable: find.byType(Scrollable).first,
  );
  final expectedText = CurrencyFormatter.formatMinor(expected, 'COP');
  for (var attempt = 0; attempt < 60; attempt++) {
    await tester.pump(const Duration(milliseconds: 250));
    final visibleValues = tester
        .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .toList(growable: false);
    if (visibleValues.contains(expectedText)) return;
  }
  final visibleValues = tester
      .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .toList(growable: false);
  fail('Home balance did not show $expectedText. Home balance card: $visibleValues');
}

Future<void> _expectBudgetRatio(WidgetTester tester, String key, double ratio) async {
  final finder = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    finder,
    400,
    scrollable: find.byType(Scrollable).first,
  );
  final locale = Localizations.localeOf(tester.element(finder)).toString();
  final expected = NumberFormat.percentPattern(locale).format(ratio).replaceAll(RegExp(r'\s+'), '');
  for (var attempt = 0; attempt < 60; attempt++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty &&
        tester.widget<Text>(finder).data?.replaceAll(RegExp(r'\s+'), '') == expected) {
      return;
    }
  }
  expect(finder, findsOneWidget);
  expect(
    tester.widget<Text>(finder).data?.replaceAll(RegExp(r'\s+'), ''),
    expected,
  );
}
