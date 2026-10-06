import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/domain/entities/budget.dart';
import 'package:personal_finance/features/finance/domain/entities/budget_flow_type.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/usecases/calculate_budget_tracking.dart';

void main() {
  const calculator = CalculateBudgetTracking();
  const budget = Budget(
    id: '2026-10_expense_food_COP',
    categoryId: 'food',
    flowType: BudgetFlowType.expense,
    monthKey: '2026-10',
    currency: 'COP',
    plannedAmountMinor: 500000,
    status: 'active',
  );

  test('counts only confirmed operations matching the budget dimensions', () {
    final result = calculator(budget, [
      _operation('expense', 125000, 'food', '2026-10', 'COP'),
      _operation('expense', 90000, 'transport', '2026-10', 'COP'),
      _operation('income', 300000, 'food', '2026-10', 'COP'),
      _operation('expense', 80000, 'food', '2026-09', 'COP'),
      _operation('expense', 50000, 'food', '2026-10', 'MXN'),
      _operation('expense', 70000, 'food', '2026-10', 'COP', status: OperationStatus.pending),
    ]);

    expect(result.plannedMinor, 500000);
    expect(result.actualMinor, 125000);
    expect(result.remainingMinor, 375000);
    expect(result.isExceeded, isFalse);
  });

  test('includes overages as negative remaining amount', () {
    final result = calculator(
      budget,
      [_operation('expense', 600000, 'food', '2026-10', 'COP')],
    );

    expect(result.remainingMinor, -100000);
    expect(result.isExceeded, isTrue);
  });

  test('never counts transfers as budget actuals', () {
    final result = calculator(budget, [
      _operation('transfer', 200000, 'food', '2026-10', 'COP'),
      _operation('expense', 50000, 'food', '2026-10', 'COP'),
    ]);

    expect(result.actualMinor, 50000);
  });
}

FinancialOperation _operation(
  String type,
  int amountMinor,
  String categoryId,
  String monthKey,
  String currency, {
  OperationStatus status = OperationStatus.confirmed,
}) => FinancialOperation(
  id: '$type-$amountMinor-$categoryId-$monthKey-$currency-${status.name}',
  type: OperationType.values.byName(type),
  amountMinor: amountMinor,
  currency: currency,
  monthKey: monthKey,
  occurredAt: DateTime(2026, 10, 5),
  status: status,
  idempotencyKey: 'operation-$amountMinor',
  categoryId: categoryId,
);
