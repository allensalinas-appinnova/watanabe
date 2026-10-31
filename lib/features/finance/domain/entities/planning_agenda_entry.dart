import 'planning_follow_up.dart';

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
    this.followUpState = PlanningFollowUpState.open,
    this.followUpVersion = 0,
    this.remindOn,
    this.followUpReason,
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
  final PlanningFollowUpState followUpState;
  final int followUpVersion;
  final String? remindOn;
  final String? followUpReason;
  PlanningSource get source => PlanningSource(
    kind: kind == PlanningEntryKind.debt ? PlanningSourceKind.debt : PlanningSourceKind.expense,
    monthKey: monthKey,
    budgetId: budgetId,
    itemId: itemId,
    commitmentId: commitmentId,
  );
  bool needsAttention(DateTime today) {
    if (pendingMinor <= 0 ||
        followUpState == PlanningFollowUpState.completed ||
        followUpState == PlanningFollowUpState.dismissed) {
      return false;
    }
    if (followUpState == PlanningFollowUpState.snoozed) {
      final remind = DateTime.tryParse(remindOn ?? '');
      if (remind == null || DateTime(today.year, today.month, today.day).isBefore(remind)) {
        return false;
      }
    }
    return true;
  }
}
