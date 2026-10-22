import '../../domain/entities/financial_operation.dart';

/// Immutable context passed when a movement is started from a budget item.
class BudgetItemMovementPreset {
  const BudgetItemMovementPreset({
    required this.budgetId,
    required this.itemId,
    required this.type,
    required this.categoryId,
    required this.currency,
    required this.description,
    required this.amountMinor,
  });

  final String budgetId;
  final String itemId;
  final OperationType type;
  final String categoryId;
  final String currency;
  final String description;
  final int amountMinor;
}
