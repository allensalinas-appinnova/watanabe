enum PlanningEntryKind { income, expense, debt }

class PlanningAgendaEntry {
  const PlanningAgendaEntry({
    required this.id,
    required this.kind,
    required this.date,
    required this.title,
    required this.currency,
    required this.plannedMinor,
    required this.recordedMinor,
    required this.pendingMinor,
    required this.monthKey,
    this.categoryId,
    this.budgetId,
    this.itemId,
    this.commitmentId,
    this.debtAccountId,
    this.bankAccountId,
  });

  final String id;
  final PlanningEntryKind kind;
  final DateTime date;
  final String title;
  final String currency;
  final int plannedMinor;
  final int recordedMinor;
  final int pendingMinor;
  final String monthKey;
  final String? categoryId;
  final String? budgetId;
  final String? itemId;
  final String? commitmentId;
  final String? debtAccountId;
  final String? bankAccountId;
}
