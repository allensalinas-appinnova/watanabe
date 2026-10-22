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
import 'package:personal_finance/features/finance/domain/entities/operation_page.dart';
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
  });

  tearDownAll(() async {
    await FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).signOut();
    await GetIt.I.reset();
  });

  testWidgets(
    'activity type filters preserve cursor pagination and include transfers only in all',
    (
      tester,
    ) async {
      final email = 'activity-${DateTime.now().microsecondsSinceEpoch}@example.test';
      final credential = await FirebaseAuth.instanceFor(app: FirebaseBootstrap.app)
          .createUserWithEmailAndPassword(
            email: email,
            password: 'ClearBudget-E2E-123',
          );
      await credential.user!.getIdToken(true);
      final uid = credential.user!.uid;
      final userRef = FirebaseFirestore.instanceFor(
        app: FirebaseBootstrap.app,
      ).collection('users').doc(uid);
      await userRef.set({
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
        (failure) => fail('Category bootstrap failed: ${failure.message}'),
        (_) {},
      );
      final categorySnapshot = await userRef.collection('categories').get();
      final incomeCategory = categorySnapshot.docs.firstWhere(
        (document) => document.data()['type'] == 'income',
      );
      final expenseCategory = categorySnapshot.docs.firstWhere(
        (document) => document.data()['type'] == 'expense',
      );
      final accountResult = await repository.createAccount(
        uid,
        name: 'Cuenta actividad',
        type: 'cash',
        currency: 'COP',
        openingBalanceMinor: 0,
      );
      final secondAccountResult = await repository.createAccount(
        uid,
        name: 'Ahorros actividad',
        type: 'savings',
        currency: 'COP',
        openingBalanceMinor: 0,
      );
      final account = accountResult.getOrElse((_) => throw StateError('Account creation failed'));
      final secondAccount = secondAccountResult.getOrElse(
        (_) => throw StateError('Second account creation failed'),
      );
      final now = DateTime.now().toUtc();
      final operations = [
        FinancialOperationDraft(
          type: OperationType.income,
          amountMinor: 100,
          currency: 'COP',
          accountId: account.id,
          categoryId: incomeCategory.id,
          monthKey: '2026-10',
          occurredAt: now.subtract(const Duration(minutes: 2)),
          description: 'Ingreso uno',
          idempotencyKey: 'activity-income-one-${now.microsecondsSinceEpoch}',
        ),
        FinancialOperationDraft(
          type: OperationType.income,
          amountMinor: 200,
          currency: 'COP',
          accountId: account.id,
          categoryId: incomeCategory.id,
          monthKey: '2026-10',
          occurredAt: now.subtract(const Duration(minutes: 2)),
          description: 'Ingreso dos',
          idempotencyKey: 'activity-income-two-${now.microsecondsSinceEpoch}',
        ),
        FinancialOperationDraft(
          type: OperationType.expense,
          amountMinor: 30,
          currency: 'COP',
          accountId: account.id,
          categoryId: expenseCategory.id,
          monthKey: '2026-10',
          occurredAt: now.subtract(const Duration(minutes: 1)),
          description: 'Compra',
          idempotencyKey: 'activity-expense-${now.microsecondsSinceEpoch}',
        ),
      ];
      for (final operation in operations) {
        final result = await repository.createOperation(uid, operation);
        result.match(
          (failure) => fail('Operation creation failed: ${failure.message}'),
          (_) {},
        );
      }
      final transfer = await repository.createTransfer(
        uid,
        TransferDraft(
          amountMinor: 15,
          currency: 'COP',
          sourceAccountId: account.id,
          destinationAccountId: secondAccount.id,
          monthKey: '2026-10',
          occurredAt: now,
          description: 'Ahorro',
          idempotencyKey: 'activity-transfer-${now.microsecondsSinceEpoch}',
        ),
      );
      transfer.match(
        (failure) => fail('Transfer creation failed: ${failure.message}'),
        (_) {},
      );

      Future<List<FinancialOperation>> readAllPages({
        OperationType? type,
        String? accountId,
        List<String>? accountIds,
        String? monthKey,
        DateTime? startAt,
        DateTime? endAtExclusive,
      }) async {
        final result = <FinancialOperation>[];
        OperationPageCursor? cursor;
        do {
          final pageResult = await repository.fetchOperationsPage(
            uid,
            type: type,
            accountId: accountId,
            accountIds: accountIds,
            monthKey: monthKey,
            startAt: startAt,
            endAtExclusive: endAtExclusive,
            cursor: cursor,
            pageSize: 1,
          );
          final page = pageResult.getOrElse((failure) => throw StateError(failure.message));
          result.addAll(page.items);
          cursor = page.nextCursor;
        } while (cursor != null);
        return result;
      }

      final all = await readAllPages();
      final incomes = await readAllPages(type: OperationType.income);
      final expenses = await readAllPages(type: OperationType.expense);
      final sourceAccountOperations = await readAllPages(
        accountId: account.id,
        monthKey: '2026-10',
      );
      final destinationAccountOperations = await readAllPages(
        accountId: secondAccount.id,
        monthKey: '2026-10',
      );
      final selectedAccountsOperations = await readAllPages(
        accountIds: [account.id, secondAccount.id],
        monthKey: '2026-10',
      );
      final recentOperations = await readAllPages(
        startAt: now.subtract(const Duration(minutes: 2)),
        endAtExclusive: now.add(const Duration(seconds: 1)),
      );

      expect(all, hasLength(4));
      expect(all.where((operation) => operation.type == OperationType.transfer), hasLength(1));
      expect(
        all
            .where((operation) => operation.occurredAt == now.subtract(const Duration(minutes: 2)))
            .map((operation) => operation.id),
        [operations[1].idempotencyKey, operations[0].idempotencyKey],
        reason: 'Equal timestamps should use a stable descending document-ID cursor order.',
      );
      expect(incomes, hasLength(2));
      expect(incomes.every((operation) => operation.type == OperationType.income), isTrue);
      expect(incomes.map((operation) => operation.id).toSet(), hasLength(2));
      expect(expenses, hasLength(1));
      expect(expenses.single.type, OperationType.expense);
      expect(sourceAccountOperations, hasLength(4));
      expect(
        sourceAccountOperations.where((operation) => operation.type == OperationType.transfer),
        hasLength(1),
      );
      expect(destinationAccountOperations, hasLength(1));
      expect(destinationAccountOperations.single.type, OperationType.transfer);
      expect(selectedAccountsOperations, hasLength(4));
      expect(selectedAccountsOperations.map((operation) => operation.id).toSet(), hasLength(4));
      expect(recentOperations, hasLength(3));

      await tester.pumpWidget(const ProviderScope(child: PersonalFinanceApp()));
      var homeLoaded = false;
      for (var attempt = 0; attempt < 60; attempt++) {
        await tester.pump(const Duration(milliseconds: 250));
        homeLoaded = find.byKey(const ValueKey('global_add_operation')).evaluate().isNotEmpty;
        if (homeLoaded) break;
      }
      expect(homeLoaded, isTrue, reason: 'Authenticated user should reach the app shell.');
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 40; attempt++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (find.text('Ingreso uno').evaluate().isNotEmpty) break;
      }
      expect(find.text('Ingreso uno'), findsOneWidget);
      expect(find.text('Ingreso dos'), findsOneWidget);
      expect(find.text('Compra'), findsOneWidget);
      expect(find.text('Ahorro'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('activity_filter_income')));
      await tester.pumpAndSettle();
      expect(find.text('Ingreso uno'), findsOneWidget);
      expect(find.text('Ingreso dos'), findsOneWidget);
      expect(find.text('Compra'), findsNothing);
      expect(find.text('Ahorro'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('activity_filter_expense')));
      await tester.pumpAndSettle();
      expect(find.text('Compra'), findsOneWidget);
      expect(find.text('Ingreso uno'), findsNothing);
      expect(find.text('Ahorro'), findsNothing);
    },
  );
}
