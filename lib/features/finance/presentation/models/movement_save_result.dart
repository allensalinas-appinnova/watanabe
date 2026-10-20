import '../../domain/entities/financial_operation.dart';

enum MovementSaveStatus { confirmed, pending }

/// Receipt returned to the section that launched a new movement form.
class MovementSaveResult {
  const MovementSaveResult({
    required this.type,
    required this.status,
    required this.amountMinor,
    required this.currency,
    required this.idempotencyKey,
    required this.occurredAt,
    this.description = '',
    this.accountName,
    this.sourceAccountName,
    this.destinationAccountName,
    this.categoryName,
  });

  final OperationType type;
  final MovementSaveStatus status;
  final int amountMinor;
  final String currency;
  final String idempotencyKey;
  final DateTime occurredAt;
  final String description;
  final String? accountName;
  final String? sourceAccountName;
  final String? destinationAccountName;
  final String? categoryName;
}
