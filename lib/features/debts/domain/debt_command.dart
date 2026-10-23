import 'dart:collection';

enum DebtProduct { creditCard, bankLoan, personalLoan }

class DebtPaymentSplit {
  const DebtPaymentSplit({
    required this.principalMinor,
    required this.previousChargesMinor,
    required this.newChargesMinor,
  });
  final int principalMinor;
  final int previousChargesMinor;
  final int newChargesMinor;
  int get totalMinor => principalMinor + previousChargesMinor + newChargesMinor;
  bool matches(int total) =>
      principalMinor >= 0 &&
      previousChargesMinor >= 0 &&
      newChargesMinor >= 0 &&
      total > 0 &&
      totalMinor == total;
}

/// Immutable command envelope; the same request ID is retained by a draft on retries.
class DebtCommand {
  DebtCommand({required this.requestId, required Map<String, Object?> fields})
    : fields = UnmodifiableMapView(Map.of(fields));
  final String requestId;
  final Map<String, Object?> fields;
  Map<String, Object?> toMap() => {...fields, 'requestId': requestId};
}

class DebtCommandResult {
  DebtCommandResult({
    required this.accountId,
    required List<String> operationIds,
    required this.overLimit,
  }) : operationIds = List.unmodifiable(operationIds);
  final String accountId;
  final List<String> operationIds;
  final bool overLimit;
}
