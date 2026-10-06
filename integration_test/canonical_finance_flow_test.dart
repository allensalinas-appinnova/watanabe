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
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
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

  testWidgets('fresh user completes localized onboarding in the UI', (tester) async {
    await FirebaseAuth.instance.signOut();
    await tester.pumpWidget(const ProviderScope(child: PersonalFinanceApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('auth_guest_button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('auth_guest_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byKey(const ValueKey('onboarding_account_name')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('onboarding_account_name')),
      'Cuenta UI',
    );
    await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
    for (var attempt = 0; attempt < 10; attempt++) {
      await tester.pump(const Duration(seconds: 1));
      if (find.byKey(const ValueKey('home_add_income')).evaluate().isNotEmpty) break;
    }

    expect(find.byKey(const ValueKey('home_add_income')), findsOneWidget);
  });

  testWidgets('canonical income, expense, transfer and itemized budget flow', (tester) async {
    await FirebaseAuth.instance.signOut();
    final email = 'canonical-${DateTime.now().microsecondsSinceEpoch}@example.test';
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: 'ClearBudget-E2E-123',
    );
    await credential.user!.getIdToken(true);
    final uid = credential.user!.uid;
    final firestore = FirebaseFirestore.instance;
    final user = firestore.collection('users').doc(uid);
    await user.set({
      'locale': 'es',
      'countryCode': 'CO',
      'timeZone': 'America/Bogota',
      'defaultCurrency': 'COP',
      'onboardingStatus': 'complete',
      'categoryCatalogVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final repository = getIt<CanonicalFinanceRepository>();
    final bootstrap = await repository.ensureDefaultCategories(
      uid,
      locale: 'es',
      countryCode: 'CO',
    );
    bootstrap.match(
      (failure) => fail('Default category bootstrap failed: ${failure.message}'),
      (_) {},
    );
    final account = await repository.createAccount(
      uid,
      name: 'Cuenta principal',
      type: 'cash',
      currency: 'COP',
      openingBalanceMinor: 1000000,
    );
    final savings = await repository.createAccount(
      uid,
      name: 'Ahorros',
      type: 'cash',
      currency: 'COP',
      openingBalanceMinor: 0,
    );
    final accountId = account.getOrElse((_) => throw StateError('Account creation failed')).id;
    final savingsId = savings.getOrElse((_) => throw StateError('Savings creation failed')).id;
    final date = DateTime.utc(2026, 10, 5, 12);

    await repository.createOperation(
      uid,
      FinancialOperationDraft(
        type: OperationType.income,
        amountMinor: 250000,
        currency: 'COP',
        accountId: accountId,
        categoryId: 'salary',
        occurredAt: date,
        description: 'Pago',
        idempotencyKey: 'income-${date.millisecondsSinceEpoch}',
      ),
    );
    await repository.createOperation(
      uid,
      FinancialOperationDraft(
        type: OperationType.expense,
        amountMinor: 35000,
        currency: 'COP',
        accountId: accountId,
        categoryId: 'food',
        occurredAt: date,
        description: 'Almuerzo',
        idempotencyKey: 'expense-${date.millisecondsSinceEpoch}',
      ),
    );
    await repository.createTransfer(
      uid,
      TransferDraft(
        amountMinor: 50000,
        currency: 'COP',
        sourceAccountId: accountId,
        destinationAccountId: savingsId,
        occurredAt: date,
        description: 'Ahorro',
        idempotencyKey: 'transfer-${date.millisecondsSinceEpoch}',
      ),
    );
    await repository.createBudgetWithItems(
      uid,
      categoryId: 'food',
      flowType: 'expense',
      monthKey: '2026-10',
      currency: 'COP',
      items: const [
        CanonicalBudgetItemDraft(description: 'Comidas', amountMinor: 100000, dayOfMonth: 15),
      ],
    );

    final operations = await user.collection('operations').get();
    final entries = await user.collection('ledgerEntries').get();
    final budget = await user.collection('budgets').doc('2026-10_expense_food_COP').get();
    expect(operations.docs, hasLength(3));
    expect(entries.docs, hasLength(4));
    expect(budget.data()?['plannedAmountMinor'], 100000);
    expect(operations.docs.where((doc) => doc.data()['type'] == 'transfer'), hasLength(1));
  });
}
