enum PlanningFollowUpState { open, completed, dismissed, snoozed }

enum PlanningFollowUpAction { completeExpense, dismiss, snooze, resume }

enum PlanningSourceKind { expense, debt }

class PlanningSource {
  const PlanningSource({
    required this.kind,
    required this.monthKey,
    this.budgetId,
    this.itemId,
    this.commitmentId,
  });
  final PlanningSourceKind kind;
  final String monthKey;
  final String? budgetId;
  final String? itemId;
  final String? commitmentId;
  String get entryId => kind == PlanningSourceKind.expense
      ? 'budget:$budgetId:$itemId'
      : 'debt:$commitmentId:$monthKey';
}

class PlanningFollowUp {
  const PlanningFollowUp({
    required this.source,
    required this.state,
    required this.version,
    required this.dataGeneration,
    this.remindOn,
    this.reason,
  });
  final PlanningSource source;
  final PlanningFollowUpState state;
  final int version;
  final int dataGeneration;
  final String? remindOn;
  final String? reason;
  String get entryId => source.entryId;
}

class PlanningFollowUpSnapshot {
  const PlanningFollowUpSnapshot({
    this.items = const [],
    this.fromCache = false,
    this.pendingWrites = false,
  });
  final List<PlanningFollowUp> items;
  final bool fromCache;
  final bool pendingWrites;
}

class PlanningFollowUpCommand {
  const PlanningFollowUpCommand({
    required this.source,
    required this.action,
    required this.requestId,
    required this.expectedGeneration,
    required this.expectedVersion,
    this.remindOn,
  });
  final PlanningSource source;
  final PlanningFollowUpAction action;
  final String requestId;
  final int expectedGeneration;
  final int expectedVersion;
  final String? remindOn;
}
