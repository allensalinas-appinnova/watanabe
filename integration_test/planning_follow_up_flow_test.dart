import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_finance/app.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/firebase/firebase_bootstrap.dart';
import 'package:personal_finance/features/commitments/domain/commitment_repository.dart';
import 'package:personal_finance/features/debts/domain/debt_command.dart';
import 'package:personal_finance/features/debts/domain/debt_repository.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'planned expense and debt share follow-up, preserve money and reopen after cancellation',
    (tester) async {
      if (!const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
        throw StateError('Firebase Emulator required');
      }
      const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '10.0.2.2');
      await FirebaseBootstrap.initialize(
        AppEnvironment.dev,
        useEmulators: true,
        emulatorHost: host,
      );
      if (FirebaseBootstrap.app.options.projectId != 'demo-clearbudget') {
        throw StateError('Synthetic project required');
      }
      await configureDependencies(useEmulators: true);
      final auth = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app);
      await auth.signOut();
      await tester.pumpWidget(const ProviderScope(child: PersonalFinanceApp()));
      await _until(tester, find.byKey(const ValueKey('auth_signup_tab')));
      await tester.tap(find.byKey(const ValueKey('auth_signup_tab')));
      await tester.enterText(
        find.byKey(const ValueKey('auth_email_field')),
        'planning-${DateTime.now().microsecondsSinceEpoch}@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth_password_field')),
        'QA-Planning-2026-Synthetic',
      );
      await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
      await _until(tester, find.byKey(const ValueKey('onboarding_account_name')));
      await tester.enterText(find.byKey(const ValueKey('onboarding_account_name')), 'QA Banco');
      await tester.enterText(find.byKey(const ValueKey('onboarding_current_balance')), '5000000');
      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('onboarding_continue')));
      await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
      await _until(tester, find.byKey(const ValueKey('global_add_operation')));
      final uid = auth.currentUser!.uid;
      final db = FirebaseFirestore.instanceFor(app: FirebaseBootstrap.app);
      final root = db.collection('users').doc(uid);
      final finance = getIt<CanonicalFinanceRepository>();
      final accounts = await finance
          .watchAccounts(uid)
          .firstWhere((rows) => rows.any((account) => account.name == 'QA Banco'))
          .timeout(const Duration(seconds: 20));
      final bank = accounts.singleWhere((account) => account.name == 'QA Banco');
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('global_add_operation'))),
      );
      final today = container.read(planningTodayProvider(uid));
      final month = DateFormatMonth.key(today);
      final budget = (await finance.createBudgetWithItems(
        uid,
        categoryId: 'food',
        flowType: 'expense',
        monthKey: month,
        currency: 'COP',
        items: [
          CanonicalBudgetItemDraft(
            description: 'QA Barbería',
            amountMinor: 50000,
            dayOfMonth: today.day,
          ),
        ],
        requestId: 'qa-planning-budget-001',
      )).fold((failure) => throw StateError(failure.message), (value) => value);
      final item =
          (await finance
                  .watchBudgetItems(uid, budget.id)
                  .firstWhere((rows) => rows.isNotEmpty)
                  .timeout(const Duration(seconds: 20)))
              .single;
      final operation = (await finance.createOperation(
        uid,
        FinancialOperationDraft(
          type: OperationType.expense,
          amountMinor: 25000,
          currency: 'COP',
          accountId: bank.id,
          categoryId: 'food',
          occurredAt: DateTime.now().toUtc(),
          monthKey: month,
          description: 'QA Barber expense',
          idempotencyKey: 'qa-planning-expense-001',
          budgetId: budget.id,
          budgetItemId: item.id,
        ),
      )).fold((failure) => throw StateError(failure.message), (value) => value);
      final debt = (await getIt<DebtRepository>().execute(
        uid,
        DebtCommand(
          requestId: 'qa-planning-loan-001',
          fields: {
            'action': 'create',
            'name': 'QA Vehículo',
            'product': 'bankLoan',
            'currency': 'COP',
            'referenceAt': DateTime.now().toUtc().toIso8601String(),
            'principalMinor': 20000000,
            'chargesMinor': 0,
            'mode': 'existing',
          },
        ),
      )).fold((failure) => throw StateError(failure.message), (value) => value);
      final commitmentId = (await getIt<CommitmentRepository>().execute(uid, {
        'requestId': 'qa-planning-commitment-001',
        'action': 'create',
        'debtAccountId': debt.accountId,
        'currency': 'COP',
        'amountMinor': 2400000,
        'firstDueMonth': month,
        'dueDay': today.day,
        'remindersEnabled': false,
      })).fold((failure) => throw StateError(failure.message), (value) => value);
      final expenseId = 'budget:${budget.id}:${item.id}';
      final debtId = 'debt:$commitmentId:$month';
      final baseline = await _financialSnapshot(
        root,
        bank.id,
        debt.accountId,
        budget.id,
        item.id,
        month,
      );
      debugPrint('planning_follow_up_e2e_seeded');
      await tester.tap(find.byKey(const ValueKey('finance_nav_budget')));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byKey(const ValueKey('planning_month_picker'))),
      );
      await tester.tap(find.text(l10n.planningAgenda).hitTestable());
      await _until(tester, find.byKey(const ValueKey('planning_agenda_entries')));
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('agenda_entry_$expenseId')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('planning_agenda_entries')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await _open(tester, expenseId);
      await tester.tap(find.byKey(const ValueKey('follow_up_completeExpense')));
      await _state(tester, root, expenseId, 'completed');
      expect(
        await _financialSnapshot(root, bank.id, debt.accountId, budget.id, item.id, month),
        baseline,
      );
      expect(find.byKey(ValueKey('agenda_entry_$expenseId')), findsNothing);
      debugPrint('planning_follow_up_e2e_completed');

      await tester.scrollUntilVisible(
        find.text(l10n.planningAll),
        -200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('planning_agenda_entries')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text(l10n.planningAll).hitTestable());
      await tester.pumpAndSettle();
      await _open(tester, expenseId);
      await tester.tap(find.byKey(const ValueKey('follow_up_resume')));
      await _state(tester, root, expenseId, 'open');
      await _open(tester, debtId);
      await tester.tap(find.byKey(const ValueKey('follow_up_dismiss')));
      await _state(tester, root, debtId, 'dismissed');
      expect(
        await _financialSnapshot(root, bank.id, debt.accountId, budget.id, item.id, month),
        baseline,
      );
      await _open(tester, debtId);
      await tester.tap(find.byKey(const ValueKey('follow_up_resume')));
      await _state(tester, root, debtId, 'open');

      await _open(tester, expenseId);
      await tester.tap(find.byKey(const ValueKey('follow_up_snooze')));
      await tester.pumpAndSettle();
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      final picker = find.byType(DatePickerDialog);
      final material = MaterialLocalizations.of(tester.element(picker));
      await tester.tap(find.descendant(of: picker, matching: find.text('${tomorrow.day}')).last);
      await tester.tap(find.text(material.okButtonLabel));
      await _state(tester, root, expenseId, 'snoozed');
      final snoozed = await root
          .collection('planningFollowUps')
          .where('entryId', isEqualTo: expenseId)
          .get(const GetOptions(source: Source.server));
      expect(snoozed.docs.single.data()['remindOn'], DateFormatMonth.day(tomorrow));
      expect(
        await _financialSnapshot(root, bank.id, debt.accountId, budget.id, item.id, month),
        baseline,
      );
      await _open(tester, expenseId);
      await tester.tap(find.byKey(const ValueKey('follow_up_resume')));
      await _state(tester, root, expenseId, 'open');
      await _open(tester, expenseId);
      await tester.tap(find.byKey(const ValueKey('follow_up_completeExpense')));
      await _state(tester, root, expenseId, 'completed');
      debugPrint('planning_follow_up_e2e_snooze_and_resume');

      await tester.tap(find.byKey(ValueKey('agenda_entry_$expenseId')));
      await tester.pumpAndSettle();
      await _until(tester, find.byKey(const ValueKey('planning_item_register')));
      await tester.ensureVisible(find.text(operation.description));
      await tester.pumpAndSettle();
      await tester.tap(find.text(operation.description));
      await tester.pumpAndSettle();
      await _until(tester, find.byKey(const ValueKey('delete_operation')));
      await tester.tap(find.byKey(const ValueKey('delete_operation')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, l10n.deleteOperation).last);
      await _state(tester, root, expenseId, 'open');
      final account =
          (await root
                  .collection('accounts')
                  .doc(bank.id)
                  .get(const GetOptions(source: Source.server)))
              .data()!;
      expect(account['currentBalanceMinor'], 5000000);
      expect(
        (await root.collection('operations').get(const GetOptions(source: Source.server))).docs
            .where((doc) => doc.data()['status'] == 'confirmed' && doc.data()['type'] == 'expense'),
        isEmpty,
      );
      await _until(tester, find.textContaining(l10n.planningFollowUpText('reopened')));
      debugPrint('planning_follow_up_e2e_reopened_and_balances_verified');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  debugPrint(
    'qa_visible_texts: ${tester.allWidgets.whereType<Text>().map((text) => text.data).whereType<String>().take(80).join(' | ')}',
  );
  final uid = FirebaseAuth.instanceFor(app: FirebaseBootstrap.app).currentUser?.uid;
  if (uid != null) {
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp).first));
    final month = DateFormatMonth.key(container.read(planningTodayProvider(uid)));
    final value = container.read(planningAgendaEntriesProvider((userId: uid, monthKey: month)));
    debugPrint('qa_agenda_error: ${value.error}\n${value.stackTrace}');
  }
  expect(finder, findsWidgets, reason: 'Timed out waiting for expected app state');
}

Future<void> _open(WidgetTester tester, String entryId) async {
  final action = find.byKey(ValueKey('planning_follow_up_$entryId'));
  if (action.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      action,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('planning_agenda_entries')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await _until(tester, action);
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Future<void> _state(
  WidgetTester tester,
  DocumentReference<Map<String, dynamic>> root,
  String entryId,
  String state,
) async {
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    final rows = await root
        .collection('planningFollowUps')
        .where('entryId', isEqualTo: entryId)
        .get(const GetOptions(source: Source.server));
    if (rows.docs.isNotEmpty && rows.docs.single.data()['state'] == state) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Expected follow-up state $state');
}

Future<Map<String, Object?>> _financialSnapshot(
  DocumentReference<Map<String, dynamic>> root,
  String bank,
  String debt,
  String budget,
  String item,
  String month,
) async {
  Future<Map<String, dynamic>?> data(String path) async =>
      (await root.firestore.doc('${root.path}/$path').get(const GetOptions(source: Source.server)))
          .data();
  return {
    'bank': await data('accounts/$bank'),
    'debt': await data('accounts/$debt'),
    'budget': await data('budgets/$budget'),
    'item': await data('budgets/$budget/items/$item'),
    'summary': await data('monthlySummaries/${month}_COP'),
    'operations': (await root.collection('operations').get(const GetOptions(source: Source.server)))
        .docs
        .map((doc) => doc.data())
        .toList(),
  };
}
