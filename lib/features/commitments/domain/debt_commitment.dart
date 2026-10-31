enum DebtInstallmentStatus { upcoming, due, partiallyPaid, paid, skipped, paused, missed }

class DebtCommitmentTerms {
  const DebtCommitmentTerms({
    required this.version,
    required this.effectiveFromMonth,
    required this.amountMinor,
    required this.dueDay,
    required this.remindersEnabled,
    this.lastDueMonth,
    this.bankAccountId,
  });
  final int version;
  final String effectiveFromMonth;
  final int amountMinor;
  final int dueDay;
  final bool remindersEnabled;
  final String? lastDueMonth;
  final String? bankAccountId;
}

/// A monthly plan is an intention only: it never creates a payment itself.
class DebtCommitment {
  const DebtCommitment({
    required this.id,
    required this.debtAccountId,
    required this.currency,
    required this.amountMinor,
    required this.firstDueMonth,
    required this.dueDay,
    this.lastDueMonth,
    this.bankAccountId,
    this.remindersEnabled = false,
    this.pausedFromMonth,
    this.skippedMonths = const {},
    this.pauseRanges = const [],
    this.versions = const [],
    this.occurrenceOverrides = const {},
  });

  final String id;
  final String debtAccountId;
  final String currency;
  final int amountMinor;
  final String firstDueMonth;
  final int dueDay;
  final String? lastDueMonth;
  final String? bankAccountId;
  final bool remindersEnabled;
  final String? pausedFromMonth;
  final Set<String> skippedMonths;
  final List<({String fromMonth, String? untilMonth})> pauseRanges;
  final List<DebtCommitmentTerms> versions;
  final Map<String, DebtCommitmentTerms> occurrenceOverrides;

  DebtCommitment forMonth(String monthKey) {
    final candidates =
        versions.where((item) => item.effectiveFromMonth.compareTo(monthKey) <= 0).toList()
          ..sort((a, b) => b.version.compareTo(a.version));
    final terms = occurrenceOverrides[monthKey] ?? candidates.firstOrNull;
    if (terms == null) return this;
    return DebtCommitment(
      id: id,
      debtAccountId: debtAccountId,
      currency: currency,
      amountMinor: terms.amountMinor,
      dueDay: terms.dueDay,
      firstDueMonth: firstDueMonth,
      lastDueMonth: terms.lastDueMonth,
      bankAccountId: terms.bankAccountId,
      remindersEnabled: terms.remindersEnabled,
      pausedFromMonth: pausedFromMonth,
      skippedMonths: skippedMonths,
      pauseRanges: pauseRanges,
    );
  }

  bool isPausedFor(String monthKey) {
    if (pauseRanges.any(
      (range) =>
          monthKey.compareTo(range.fromMonth) >= 0 &&
          (range.untilMonth == null || monthKey.compareTo(range.untilMonth!) < 0),
    )) {
      return true;
    }
    return pausedFromMonth != null && monthKey.compareTo(pausedFromMonth!) >= 0;
  }

  bool isSkipped(String monthKey) => skippedMonths.contains(monthKey);

  DateTime? dueDateFor(String monthKey) {
    if (versions.isNotEmpty || occurrenceOverrides.containsKey(monthKey)) {
      return forMonth(monthKey)._dueDateFor(monthKey);
    }
    return _dueDateFor(monthKey);
  }

  DateTime? _dueDateFor(String monthKey) {
    if (!_validMonth(monthKey) || monthKey.compareTo(firstDueMonth) < 0) return null;
    if (lastDueMonth != null && monthKey.compareTo(lastDueMonth!) > 0) return null;
    if (isPausedFor(monthKey)) return null;
    return scheduledDateFor(monthKey);
  }

  DateTime? scheduledDateFor(String monthKey) {
    if (versions.isNotEmpty || occurrenceOverrides.containsKey(monthKey)) {
      final resolved = forMonth(monthKey);
      if (!identical(resolved, this)) return resolved.scheduledDateFor(monthKey);
    }
    if (!_validMonth(monthKey) || monthKey.compareTo(firstDueMonth) < 0) return null;
    if (lastDueMonth != null && monthKey.compareTo(lastDueMonth!) > 0) return null;
    final year = int.parse(monthKey.substring(0, 4));
    final month = int.parse(monthKey.substring(5));
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, dueDay.clamp(1, lastDay));
  }

  static bool _validMonth(String value) => RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value);
}

class DebtCommitmentOccurrence {
  const DebtCommitmentOccurrence({
    required this.commitment,
    required this.monthKey,
    required this.paidMinor,
    this.skipped = false,
  });

  final DebtCommitment commitment;
  final String monthKey;
  final int paidMinor;
  final bool skipped;

  int get plannedMinor =>
      commitment.dueDateFor(monthKey) == null || skipped ? 0 : commitment.amountMinor;
  int get remainingMinor => (plannedMinor - paidMinor).clamp(0, plannedMinor);
  DateTime? get dueDate => commitment.scheduledDateFor(monthKey);

  DebtInstallmentStatus get status => statusAt(DateTime.now());

  DebtInstallmentStatus statusAt(DateTime now) {
    if (skipped) return DebtInstallmentStatus.skipped;
    if (plannedMinor == 0) return DebtInstallmentStatus.paused;
    if (remainingMinor == 0) return DebtInstallmentStatus.paid;
    if (paidMinor > 0) return DebtInstallmentStatus.partiallyPaid;
    final due = dueDate!;
    final today = DateTime(now.year, now.month, now.day);
    if (today.isAfter(due)) return DebtInstallmentStatus.missed;
    if (today.isAtSameMomentAs(due)) return DebtInstallmentStatus.due;
    return DebtInstallmentStatus.upcoming;
  }
}
