import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/features/commitments/domain/commitment_repository.dart';
import 'package:personal_finance/features/commitments/domain/debt_commitment.dart';
import 'package:personal_finance/features/finance/domain/entities/budget.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_flow_type.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_item.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/operation_page.dart';
import 'package:personal_finance/features/finance/domain/repositories/canonical_finance_repository.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';

class _MockFinanceRepository extends Mock implements CanonicalFinanceRepository {}

class _MockCommitmentRepository extends Mock implements CommitmentRepository {}

void main() {
  final locator = GetIt.instance;

  tearDown(() async {
    if (locator.isRegistered<CommitmentRepository>()) {
      await locator.unregister<CommitmentRepository>();
    }
  });

  test(
    'monthly totals and agenda exclude archived items and skipped or paused installments',
    () async {
      final finance = _MockFinanceRepository();
      final commitments = _MockCommitmentRepository();
      locator.registerSingleton<CommitmentRepository>(commitments);
      const budgets = [
        Budget(
          id: 'expense',
          categoryId: 'food',
          flowType: BudgetFlowType.expense,
          monthKey: '2026-10',
          currency: 'COP',
          plannedAmountMinor: 999999,
          status: 'active',
        ),
        Budget(
          id: 'income',
          categoryId: 'salary',
          flowType: BudgetFlowType.income,
          monthKey: '2026-10',
          currency: 'COP',
          plannedAmountMinor: 999999,
          status: 'active',
        ),
      ];
      when(() => finance.watchBudgets('qa', '2026-10')).thenAnswer((_) => Stream.value(budgets));
      when(() => finance.watchBudgetItems('qa', 'expense')).thenAnswer(
        (_) => Stream.value(const [
          BudgetItem(
            id: 'expense-active',
            description: 'Mercado',
            amountMinor: 50000,
            dayOfMonth: 12,
          ),
          BudgetItem(
            id: 'expense-archived',
            description: 'Archivado',
            amountMinor: 90000,
            dayOfMonth: 5,
            status: 'archived',
          ),
        ]),
      );
      when(() => finance.watchBudgetItems('qa', 'income')).thenAnswer(
        (_) => Stream.value(const [
          BudgetItem(
            id: 'income-active',
            description: 'Salario',
            amountMinor: 25000,
            dayOfMonth: 1,
          ),
        ]),
      );
      const due = DebtCommitment(
        id: 'due',
        debtAccountId: 'vehicle',
        currency: 'COP',
        amountMinor: 20000,
        firstDueMonth: '2026-10',
        dueDay: 31,
      );
      const skipped = DebtCommitment(
        id: 'skipped',
        debtAccountId: 'personal-loan',
        currency: 'COP',
        amountMinor: 30000,
        firstDueMonth: '2026-10',
        dueDay: 15,
        skippedMonths: {'2026-10'},
      );
      const paused = DebtCommitment(
        id: 'paused',
        debtAccountId: 'paused-loan',
        currency: 'COP',
        amountMinor: 40000,
        firstDueMonth: '2026-10',
        dueDay: 10,
        pausedFromMonth: '2026-10',
      );
      when(() => commitments.watch('qa')).thenAnswer((_) => Stream.value([due, skipped, paused]));
      when(() => commitments.watchPayments('qa')).thenAnswer(
        (_) => Stream.value(const [
          DebtCommitmentPaymentLink(
            paymentId: 'paid-part',
            commitmentId: 'due',
            monthKey: '2026-10',
            amountMinor: 5000,
          ),
        ]),
      );

      final container = ProviderContainer(
        overrides: [canonicalFinanceRepositoryProvider.overrideWithValue(finance)],
      );
      addTearDown(container.dispose);
      const key = (userId: 'qa', monthKey: '2026-10');

      final totals = await container.read(planningBudgetTotalsProvider(key).future);
      final entries = await container.read(planningAgendaEntriesProvider(key).future);

      expect(totals.income, {'COP': 25000});
      expect(totals.expense, {'COP': 50000});
      expect(totals.debt, {'COP': 20000});
      expect(
        entries.map((entry) => entry.id),
        containsAll([
          'budget:expense:expense-active',
          'budget:income:income-active',
          'debt:due:2026-10',
        ]),
      );
      expect(entries.map((entry) => entry.id), isNot(contains('debt:skipped:2026-10')));
      expect(entries.map((entry) => entry.id), isNot(contains('debt:paused:2026-10')));
      final debtEntry = entries.singleWhere((entry) => entry.kind.name == 'debt');
      expect(debtEntry.date, DateTime(2026, 10, 31));
      expect(debtEntry.pendingMinor, 15000);
    },
  );

  test(
    'loads all category-operation pages and retains refunds without unrelated categories',
    () async {
      final repository = _MockFinanceRepository();
      final nextCursor = OperationPageCursor(
        occurredAt: DateTime(2026, 10, 1),
        operationId: 'page-one-last',
      );
      final firstPage = List.generate(100, (index) => _operation('expense-$index'));
      final secondPage = [
        ...List.generate(50, (index) => _operation('expense-second-$index')),
        _operation('refund', type: OperationType.expenseRefund, amount: 250),
        _operation('other-category', category: 'transport'),
      ];
      when(
        () => repository.fetchOperationsPage(
          'qa',
          cursor: any(named: 'cursor'),
          monthKey: '2026-10',
          currency: 'COP',
          type: OperationType.expense,
          pageSize: 100,
        ),
      ).thenAnswer((invocation) async {
        final cursor = invocation.namedArguments[#cursor] as OperationPageCursor?;
        return Right(
          cursor == null
              ? OperationPage(items: firstPage, nextCursor: nextCursor)
              : OperationPage(items: secondPage),
        );
      });
      final container = ProviderContainer(
        overrides: [canonicalFinanceRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final operations = await container.read(
        canonicalBudgetCategoryOperationsProvider(
          (
            userId: 'qa',
            budgetId: 'budget',
            categoryId: 'food',
            monthKey: '2026-10',
            currency: 'COP',
            flowType: 'expense',
          ),
        ).future,
      );

      expect(operations, hasLength(151));
      expect(operations.any((operation) => operation.id == 'refund'), isTrue);
      expect(operations.any((operation) => operation.id == 'other-category'), isFalse);
      verify(
        () => repository.fetchOperationsPage(
          'qa',
          cursor: null,
          monthKey: '2026-10',
          currency: 'COP',
          type: OperationType.expense,
          pageSize: 100,
        ),
      ).called(1);
      verify(
        () => repository.fetchOperationsPage(
          'qa',
          cursor: nextCursor,
          monthKey: '2026-10',
          currency: 'COP',
          type: OperationType.expense,
          pageSize: 100,
        ),
      ).called(1);
    },
  );
}

FinancialOperation _operation(
  String id, {
  OperationType type = OperationType.expense,
  String category = 'food',
  int amount = 1000,
}) => FinancialOperation(
  id: id,
  type: type,
  amountMinor: amount,
  currency: 'COP',
  monthKey: '2026-10',
  occurredAt: DateTime(2026, 10, 12),
  status: OperationStatus.confirmed,
  idempotencyKey: id,
  categoryId: category,
);
