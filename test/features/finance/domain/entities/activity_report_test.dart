import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/domain/entities/activity_report.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';

void main() {
  FinancialOperation operation({
    required String id,
    required OperationType type,
    required String currency,
    required int amount,
    OperationStatus status = OperationStatus.confirmed,
  }) => FinancialOperation(
    id: id,
    type: type,
    amountMinor: amount,
    currency: currency,
    monthKey: '2026-10',
    occurredAt: DateTime(2026, 10, 1),
    status: status,
    idempotencyKey: id,
  );

  test('sums confirmed income and expenses by currency, excluding transfers', () {
    final report = ActivityReport.fromOperations([
      operation(id: 'in1', type: OperationType.income, currency: 'COP', amount: 1000),
      operation(id: 'in2', type: OperationType.income, currency: 'COP', amount: 500),
      operation(id: 'out', type: OperationType.expense, currency: 'COP', amount: 300),
      operation(id: 'usd', type: OperationType.expense, currency: 'USD', amount: 25),
      operation(id: 'transfer', type: OperationType.transfer, currency: 'COP', amount: 9000),
      operation(
        id: 'pending',
        type: OperationType.expense,
        currency: 'COP',
        amount: 700,
        status: OperationStatus.pending,
      ),
      operation(
        id: 'rejected',
        type: OperationType.income,
        currency: 'COP',
        amount: 10000,
        status: OperationStatus.rejected,
      ),
    ]);

    expect(report.totalsByCurrency['COP']!.incomeMinor, 1500);
    expect(report.totalsByCurrency['COP']!.expenseMinor, 300);
    expect(report.totalsByCurrency['COP']!.netMinor, 1200);
    expect(report.totalsByCurrency['USD']!.netMinor, -25);
    expect(report.pendingOperationCount, 1);
    expect(report.operations.map((item) => item.id), isNot(contains('rejected')));
    expect(report.operations.map((item) => item.id), contains('transfer'));
  });

  test('does not create zero-only currency totals for transfers or pending rows', () {
    final report = ActivityReport.fromOperations([
      operation(id: 'transfer', type: OperationType.transfer, currency: 'COP', amount: 100),
      operation(
        id: 'pending',
        type: OperationType.income,
        currency: 'USD',
        amount: 100,
        status: OperationStatus.pending,
      ),
    ]);

    expect(report.totalsByCurrency, isEmpty);
  });
}
