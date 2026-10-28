import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/coach/domain/usecases/coach_overview.dart';
import 'package:personal_finance/features/coach/presentation/coach_action_presentation.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';

void main() {
  test('unallocated payment route carries its stable payment ID', () {
    final operation = FinancialOperation(
      id: 'debt_payment-request_0',
      type: OperationType.unallocatedDebtPayment,
      amountMinor: 2400000,
      currency: 'COP',
      monthKey: '2026-10',
      occurredAt: DateTime(2026, 10, 28),
      status: OperationStatus.confirmed,
      idempotencyKey: 'debt_payment-request_0',
      paymentId: 'payment-request',
      debtCommandId: 'payment-request',
      debtAccountId: 'loan',
      debtKind: 'payUnallocated',
      allocationStatus: 'unallocated',
    );
    final action = CoachAction(
      kind: CoachActionKind.unallocatedPayment,
      id: operation.id,
      debtAccountId: 'loan',
      operation: operation,
    );

    expect(
      coachActionRoute(action),
      '/debts/loan/actions/allocatePayment?paymentId=payment-request',
    );
  });
}
