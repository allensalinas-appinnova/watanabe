import '../../domain/entities/financial_operation.dart';
import 'firestore_date_mapper.dart';

/// Shared Firestore mapping for finance screens and Coach reports.
abstract final class FinancialOperationFirestoreMapper {
  static FinancialOperation fromMap(
    String id,
    Map<String, dynamic> data, {
    bool pending = false,
    bool requireDate = false,
  }) {
    final occurredAt = FirestoreDateMapper.toDateTime(data['occurredAt']);
    if (requireDate && occurredAt == null) {
      throw const FormatException('invalid-operation-date');
    }
    final monthKey =
        data['monthKey'] as String? ??
        (occurredAt == null
            ? ''
            : '${occurredAt.year.toString().padLeft(4, '0')}-${occurredAt.month.toString().padLeft(2, '0')}');
    return FinancialOperation(
      id: id,
      type: OperationType.values.byName(data['type'] as String),
      amountMinor: data['amountMinor'] as int,
      currency: data['currency'] as String,
      monthKey: monthKey,
      occurredAt: occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      status: pending
          ? OperationStatus.pending
          : OperationStatus.values.byName(data['status'] as String? ?? 'confirmed'),
      idempotencyKey: data['idempotencyKey'] as String? ?? id,
      categoryId: data['categoryId'] as String?,
      accountId: data['accountId'] as String?,
      sourceAccountId: data['sourceAccountId'] as String?,
      destinationAccountId: data['destinationAccountId'] as String?,
      budgetId: data['budgetId'] as String?,
      budgetItemId: data['budgetItemId'] as String?,
      description: data['description'] as String? ?? '',
      debtCommandId: data['debtCommandId'] as String?,
      debtAccountId: data['debtAccountId'] as String?,
      debtKind: data['debtKind'] as String?,
      originalOperationId: data['originalOperationId'] as String?,
      reversalOf: data['reversalOf'] as String?,
      projectionDirection: (data['projectionDirection'] as num? ?? 1).toInt(),
      principalDeltaMinor: (data['principalDeltaMinor'] as num? ?? 0).toInt(),
      chargesDeltaMinor: (data['chargesDeltaMinor'] as num? ?? 0).toInt(),
      balanceDeltaMinor: (data['balanceDeltaMinor'] as num?)?.toInt(),
      previousBalanceMinor: (data['previousBalanceMinor'] as num?)?.toInt(),
      targetBalanceMinor: (data['targetBalanceMinor'] as num?)?.toInt(),
      paymentId: data['paymentId'] as String?,
      allocationStatus: data['allocationStatus'] as String?,
      revision: (data['revision'] as num? ?? 0).toInt(),
      createdAt: FirestoreDateMapper.toDateTime(data['createdAt']),
      updatedAt: FirestoreDateMapper.toDateTime(data['updatedAt']),
    );
  }
}
