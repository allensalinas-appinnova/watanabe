import '../../finance/domain/entities/planning_follow_up.dart';
import 'commitment_repository.dart';
import 'debt_commitment.dart';

class DebtReminderCandidate {
  const DebtReminderCandidate({required this.date, required this.monthKey, required this.before});
  final DateTime date;
  final String monthKey;
  final bool before;
}

List<DebtReminderCandidate> planDebtReminders({
  required DateTime today,
  required List<DebtCommitment> commitments,
  required List<DebtCommitmentPaymentLink> payments,
  required List<PlanningFollowUp> followUps,
}) {
  String month(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
  final start = DateTime(today.year, today.month, today.day);
  final end = DateTime(today.year, today.month, today.day + 28);
  final tracking = {for (final followUp in followUps) followUp.entryId: followUp};
  final months = {
    for (var offset = 0; offset <= 29; offset++)
      month(DateTime(today.year, today.month, today.day + offset)),
    for (final followUp in followUps)
      if (followUp.source.kind == PlanningSourceKind.debt &&
          followUp.state == PlanningFollowUpState.snoozed)
        followUp.source.monthKey,
  };
  final result = <DebtReminderCandidate>[];
  for (final original in commitments) {
    for (final key in months) {
      final plan = original.forMonth(key);
      final due = plan.dueDateFor(key);
      if (due == null || plan.isSkipped(key) || !plan.remindersEnabled) continue;
      final paid = payments
          .where((link) => link.commitmentId == plan.id && link.monthKey == key)
          .fold<int>(0, (total, link) => total + link.amountMinor);
      if (paid >= plan.amountMinor) continue;
      final followUp = tracking['debt:${plan.id}:$key'];
      if (followUp?.state == PlanningFollowUpState.dismissed ||
          followUp?.state == PlanningFollowUpState.completed) {
        continue;
      }
      final snoozed = followUp?.state == PlanningFollowUpState.snoozed;
      final later = DateTime.tryParse(followUp?.remindOn ?? '');
      final dates = snoozed
          ? [if (later != null) (later, false)]
          : [(DateTime(due.year, due.month, due.day - 1), true), (due, false)];
      for (final (date, before) in dates) {
        if (!date.isBefore(start) && !date.isAfter(end)) {
          result.add(DebtReminderCandidate(date: date, monthKey: key, before: before));
        }
      }
    }
  }
  result.sort((a, b) {
    final date = a.date.compareTo(b.date);
    return date != 0 ? date : a.monthKey.compareTo(b.monthKey);
  });
  return List.unmodifiable(result);
}
