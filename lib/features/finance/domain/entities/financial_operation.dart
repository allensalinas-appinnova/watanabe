enum OperationType { income, expense, transfer }

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
    this.description = '',
    this.createdAt,
    this.updatedAt,
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
  final String description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isTransfer => type == OperationType.transfer;
}
