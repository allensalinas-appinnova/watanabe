class BalanceAdjustmentDraft {
  const BalanceAdjustmentDraft({
    required this.accountId,
    required this.currency,
    required this.targetBalanceMinor,
  });

  final String accountId;
  final String currency;
  final int targetBalanceMinor;

  Map<String, Object?> toJson() => {
    'accountId': accountId,
    'currency': currency,
    'targetBalanceMinor': targetBalanceMinor,
  };
}

class BalanceAdjustmentRecord {
  const BalanceAdjustmentRecord({
    required this.accountId,
    required this.currency,
    required this.previousBalanceMinor,
    required this.targetBalanceMinor,
    required this.deltaMinor,
  });

  final String accountId;
  final String currency;
  final int previousBalanceMinor;
  final int targetBalanceMinor;
  final int deltaMinor;
}

class BalanceAdjustmentResult {
  const BalanceAdjustmentResult({
    required this.requestId,
    required this.adjustments,
    required this.adjustedAt,
  });

  final String requestId;
  final List<BalanceAdjustmentRecord> adjustments;
  final DateTime adjustedAt;
}

class BalanceAdjustmentEvent {
  const BalanceAdjustmentEvent({
    required this.requestId,
    required this.adjustedAt,
    required this.adjustments,
    this.reason,
  });

  final String requestId;
  final DateTime adjustedAt;
  final List<BalanceAdjustmentRecord> adjustments;
  final String? reason;
}

class BalanceAdjustmentActivityEntry {
  const BalanceAdjustmentActivityEntry({
    required this.requestId,
    required this.adjustedAt,
    required this.adjustment,
  });

  final String requestId;
  final DateTime adjustedAt;
  final BalanceAdjustmentRecord adjustment;
}
