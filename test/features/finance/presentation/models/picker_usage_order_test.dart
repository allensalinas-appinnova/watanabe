import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/presentation/models/picker_usage_order.dart';

void main() {
  test('ranks confirmed usage first, breaks ties by recency, and caps frequent items at five', () {
    final now = DateTime(2026, 10, 23);
    final operations = [
      _operation('beta-new', accountId: 'beta', at: now),
      _operation('alpha-new', accountId: 'alpha', at: now.subtract(const Duration(minutes: 1))),
      _operation('beta-old', accountId: 'beta', at: now.subtract(const Duration(minutes: 2))),
      _operation('alpha-old', accountId: 'alpha', at: now.subtract(const Duration(minutes: 3))),
      _operation(
        'ignored-pending',
        accountId: 'gamma',
        status: OperationStatus.pending,
        at: now,
      ),
      _operation(
        'ignored-rejected',
        accountId: 'delta',
        status: OperationStatus.rejected,
        at: now,
      ),
    ];

    final result = orderPickerOptionsByUsage(
      options: const ['gamma', 'zeta', 'alpha', 'beta', 'epsilon', 'delta', 'eta'],
      recentOperations: operations,
      idOf: (id) => id,
      usageIdsOf: accountUsageIds,
      compareAlphabetically: (left, right) => left.compareTo(right),
    );

    expect(result.frequent, ['beta', 'alpha']);
    expect(result.ordered, ['beta', 'alpha', 'delta', 'epsilon', 'eta', 'gamma', 'zeta']);
  });

  test('counts both transfer accounts and keeps category frequency specific to movement type', () {
    final operations = [
      _operation(
        'transfer-1',
        type: OperationType.transfer,
        sourceAccountId: 'cash',
        destinationAccountId: 'bank',
      ),
      _operation(
        'transfer-2',
        type: OperationType.transfer,
        sourceAccountId: 'cash',
        destinationAccountId: 'bank',
      ),
      _operation('income-1', type: OperationType.income, categoryId: 'salary'),
      _operation('income-2', type: OperationType.income, categoryId: 'salary'),
      _operation('expense-1', type: OperationType.expense, categoryId: 'food'),
      _operation('expense-2', type: OperationType.expense, categoryId: 'food'),
    ];

    final accounts = orderPickerOptionsByUsage(
      options: const ['cash', 'bank', 'wallet'],
      recentOperations: operations,
      idOf: (id) => id,
      usageIdsOf: accountUsageIds,
      compareAlphabetically: (left, right) => left.compareTo(right),
    );
    final expenses = orderPickerOptionsByUsage(
      options: const ['food', 'shopping', 'salary'],
      recentOperations: operations,
      idOf: (id) => id,
      usageIdsOf: (operation) => categoryUsageIds(operation, OperationType.expense),
      compareAlphabetically: (left, right) => left.compareTo(right),
    );
    final incomes = orderPickerOptionsByUsage(
      options: const ['food', 'shopping', 'salary'],
      recentOperations: operations,
      idOf: (id) => id,
      usageIdsOf: (operation) => categoryUsageIds(operation, OperationType.income),
      compareAlphabetically: (left, right) => left.compareTo(right),
    );

    expect(accounts.frequent, ['bank', 'cash']);
    expect(expenses.frequent, ['food']);
    expect(incomes.frequent, ['salary']);
  });

  test('falls back to alphabetical order when no item has repeated confirmed use', () {
    final result = orderPickerOptionsByUsage(
      options: const ['Zulu', 'Alpha'],
      recentOperations: [_operation('one-use', accountId: 'Zulu')],
      idOf: (value) => value,
      usageIdsOf: accountUsageIds,
      compareAlphabetically: (left, right) => left.compareTo(right),
    );

    expect(result.frequent, isEmpty);
    expect(result.ordered, ['Alpha', 'Zulu']);
  });

  test('shows at most five frequent options and returns the rest alphabetically', () {
    final recentIds = ['g', 'f', 'e', 'd', 'c', 'b', 'a', 'g', 'f', 'e', 'd', 'c', 'b', 'a'];
    final result = orderPickerOptionsByUsage(
      options: const ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
      recentOperations: [
        for (var index = 0; index < recentIds.length; index++)
          _operation('usage-$index', accountId: recentIds[index]),
      ],
      idOf: (id) => id,
      usageIdsOf: accountUsageIds,
      compareAlphabetically: (left, right) => left.compareTo(right),
    );

    expect(result.frequent, ['g', 'f', 'e', 'd', 'c']);
    expect(result.ordered, ['g', 'f', 'e', 'd', 'c', 'a', 'b']);
  });
}

FinancialOperation _operation(
  String id, {
  OperationType type = OperationType.expense,
  OperationStatus status = OperationStatus.confirmed,
  String? accountId,
  String? sourceAccountId,
  String? destinationAccountId,
  String? categoryId,
  DateTime? at,
}) => FinancialOperation(
  id: id,
  type: type,
  amountMinor: 100,
  currency: 'COP',
  monthKey: '2026-10',
  occurredAt: at ?? DateTime(2026, 10, 1),
  status: status,
  idempotencyKey: 'key-$id',
  accountId: accountId,
  sourceAccountId: sourceAccountId,
  destinationAccountId: destinationAccountId,
  categoryId: categoryId,
);
