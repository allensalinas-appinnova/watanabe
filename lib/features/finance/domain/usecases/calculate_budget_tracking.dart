import '../entities/budget.dart';
import '../entities/budget_flow_type.dart';
import '../entities/financial_operation.dart';

class BudgetTracking {
  const BudgetTracking({required this.plannedMinor, required this.actualMinor})
    : remainingMinor = plannedMinor - actualMinor;

  final int plannedMinor;
  final int actualMinor;
  final int remainingMinor;

  bool get isExceeded => remainingMinor < 0;
  bool get isEmpty => plannedMinor == 0 && actualMinor == 0;
}

class CalculateBudgetTracking {
  const CalculateBudgetTracking();

  BudgetTracking call(Budget budget, Iterable<FinancialOperation> operations) {
    final actual = operations
        .where(
          (operation) =>
              operation.monthKey == budget.monthKey &&
              operation.currency == budget.currency &&
              operation.categoryId == budget.categoryId &&
              operation.type.name == budget.flowType.value &&
              operation.status == OperationStatus.confirmed,
        )
        .fold<int>(0, (total, operation) => total + operation.amountMinor);
    return BudgetTracking(plannedMinor: budget.plannedAmountMinor, actualMinor: actual);
  }
}
