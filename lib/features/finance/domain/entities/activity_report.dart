import 'balance_adjustment.dart';
import 'financial_operation.dart';

class ActivityCurrencyTotals {
  const ActivityCurrencyTotals({
    required this.currency,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final String currency;
  final int incomeMinor;
  final int expenseMinor;

  int get netMinor => incomeMinor - expenseMinor;
}

class ActivityReport {
  ActivityReport._({
    required this.operations,
    required this.totalsByCurrency,
    required this.adjustments,
  });

  factory ActivityReport.fromOperations(
    Iterable<FinancialOperation> operations, {
    Iterable<BalanceAdjustmentActivityEntry> adjustments = const [],
  }) {
    final visibleOperations = operations
        .where((operation) => operation.status != OperationStatus.rejected)
        .toList(growable: false);
    final incomeByCurrency = <String, int>{};
    final expenseByCurrency = <String, int>{};

    for (final operation in visibleOperations) {
      if (operation.status != OperationStatus.confirmed) continue;
      switch (operation.type) {
        case OperationType.income:
          incomeByCurrency.update(
            operation.currency,
            (amount) => amount + operation.recognizedIncomeMinor,
            ifAbsent: () => operation.recognizedIncomeMinor,
          );
        case OperationType.expense:
        case OperationType.expenseRefund:
          expenseByCurrency.update(
            operation.currency,
            (amount) => amount + operation.recognizedExpenseMinor,
            ifAbsent: () => operation.recognizedExpenseMinor,
          );
        case OperationType.transfer:
        case OperationType.debtAdjustment:
          // Transfers move money between accounts; they are not income or expense.
          break;
      }
    }

    final currencies = {...incomeByCurrency.keys, ...expenseByCurrency.keys}.toList()..sort();
    return ActivityReport._(
      operations: visibleOperations,
      adjustments: adjustments.toList(growable: false),
      totalsByCurrency: {
        for (final currency in currencies)
          currency: ActivityCurrencyTotals(
            currency: currency,
            incomeMinor: incomeByCurrency[currency] ?? 0,
            expenseMinor: expenseByCurrency[currency] ?? 0,
          ),
      },
    );
  }

  /// Every non-rejected operation matching the activity filters, across pages.
  final List<FinancialOperation> operations;

  /// Balance corrections are a separate activity type, never income/expense.
  final List<BalanceAdjustmentActivityEntry> adjustments;

  /// Confirmed income/expense totals, kept separate for each currency.
  final Map<String, ActivityCurrencyTotals> totalsByCurrency;

  static List<List<FinancialOperation>> groupOperations(Iterable<FinancialOperation> operations) {
    final groups = <String, List<FinancialOperation>>{};
    for (final operation in operations) {
      groups
          .putIfAbsent(
            operation.debtCommandId == null
                ? 'operation:${operation.id}'
                : 'command:${operation.debtCommandId}',
            () => [],
          )
          .add(operation);
    }
    return groups.values.toList(growable: false);
  }

  int get confirmedOperationCount => groupOperations(
    operations.where((operation) => operation.status == OperationStatus.confirmed),
  ).length;

  int get pendingOperationCount =>
      operations.where((operation) => operation.status == OperationStatus.pending).length;
}
