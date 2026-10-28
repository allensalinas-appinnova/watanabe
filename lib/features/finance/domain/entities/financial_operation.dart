enum OperationType {
  income,
  expense,
  transfer,
  expenseRefund,
  debtAdjustment,
  unallocatedDebtPayment,
}

enum OperationStatus { pending, confirmed, rejected }

class FinancialOperation {
  const FinancialOperation({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.currency,
    required this.monthKey,
    required this.occurredAt,
    required this.status,
    required this.idempotencyKey,
    this.categoryId,
    this.accountId,
    this.sourceAccountId,
    this.destinationAccountId,
    this.budgetId,
    this.budgetItemId,
    this.description = '',
    this.createdAt,
    this.updatedAt,
    this.debtCommandId,
    this.debtAccountId,
    this.debtKind,
    this.originalOperationId,
    this.reversalOf,
    this.projectionDirection = 1,
    this.principalDeltaMinor = 0,
    this.chargesDeltaMinor = 0,
    this.balanceDeltaMinor,
    this.previousBalanceMinor,
    this.targetBalanceMinor,
    this.paymentId,
    this.allocationStatus,
    this.revision = 0,
  });

  final String id;
  final OperationType type;
  final int amountMinor;
  final String currency;
  final String monthKey;
  final DateTime occurredAt;
  final OperationStatus status;
  final String idempotencyKey;
  final String? categoryId;
  final String? accountId;
  final String? sourceAccountId;
  final String? destinationAccountId;
  final String? budgetId;
  final String? budgetItemId;
  final String description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? debtCommandId;
  final String? debtAccountId;
  final String? debtKind;
  final String? originalOperationId;
  final String? reversalOf;
  final int projectionDirection;
  final int principalDeltaMinor;
  final int chargesDeltaMinor;
  final int? balanceDeltaMinor;
  final int? previousBalanceMinor;
  final int? targetBalanceMinor;
  final String? paymentId;
  final String? allocationStatus;
  final int revision;

  int get recognizedIncomeMinor =>
      type == OperationType.income ? amountMinor * projectionDirection : 0;
  int get recognizedExpenseMinor => switch (type) {
    OperationType.expense => amountMinor * projectionDirection,
    OperationType.expenseRefund => -amountMinor * projectionDirection,
    _ => 0,
  };

  bool get isTransfer => type == OperationType.transfer;

  bool get isDebtPaymentComponent =>
      debtCommandId != null && const {'pay', 'newChargePaid', 'payUnallocated'}.contains(debtKind);
}
