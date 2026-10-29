import '../../../commitments/domain/commitment_repository.dart';
import '../../../commitments/domain/debt_commitment.dart';
import '../../../finance/domain/entities/financial_operation.dart';
import '../entities/coach_models.dart';
import 'coach_routine.dart';

enum CoachActionKind {
  syncRejected,
  dueCommitment,
  unallocatedPayment,
  dueBudgetExpense,
  upcomingCommitment,
  upcomingBudgetExpense,
  budgetReached,
  weeklyReview,
  dailyReview,
  configureRoutines,
  current,
}

enum CoachInsightKind { incompleteInformation, largestWeeklyCategory, budgetReached }

class CoachAction {
  const CoachAction({
    required this.kind,
    required this.id,
    this.debtAccountId,
    this.bankAccountId,
    this.commitmentId,
    this.budgetId,
    this.budgetItemId,
    this.description,
    this.monthKey,
    this.periodKey,
    this.currency,
    this.plannedMinor,
    this.paidMinor,
    this.remainingMinor,
    this.dueDate,
    this.operation,
  });

  final CoachActionKind kind;
  final String id;
  final String? debtAccountId;
  final String? bankAccountId;
  final String? commitmentId;
  final String? budgetId;
  final String? budgetItemId;
  final String? description;
  final String? monthKey;
  final String? periodKey;
  final String? currency;
  final int? plannedMinor;
  final int? paidMinor;
  final int? remainingMinor;
  final DateTime? dueDate;
  final FinancialOperation? operation;
}

class CoachInsight {
  const CoachInsight({
    required this.kind,
    required this.id,
    this.currency,
    this.categoryId,
    this.budgetId,
    this.amountMinor,
    this.periodKey,
  });
  final CoachInsightKind kind;
  final String id;
  final String? currency;
  final String? categoryId;
  final String? budgetId;
  final int? amountMinor;
  final String? periodKey;
}

class CoachPaymentReviewItem {
  const CoachPaymentReviewItem({
    required this.id,
    required this.dueDate,
    required this.kind,
    this.commitmentId,
    this.debtAccountId,
    this.bankAccountId,
    this.monthKey,
    this.currency,
    this.plannedMinor,
    this.paidMinor,
    this.remainingMinor,
    this.operation,
  });
  final String id;
  final DateTime dueDate;
  final CoachActionKind kind;
  final String? commitmentId;
  final String? debtAccountId;
  final String? bankAccountId;
  final String? monthKey;
  final String? currency;
  final int? plannedMinor;
  final int? paidMinor;
  final int? remainingMinor;
  final FinancialOperation? operation;
}

class CoachOverview {
  const CoachOverview({
    required this.action,
    required this.paymentItems,
    required this.insights,
    required this.today,
    required this.weekStart,
    required this.weekEndExclusive,
    required this.hasPendingOperations,
    required this.hasUnallocatedPayments,
    required this.freshness,
    required this.dailyReviewDue,
    required this.weeklyReviewDue,
    this.plannedExpenses = const [],
    this.availability = const CoachOverviewAvailability(),
  });
  final CoachAction? action;
  final List<CoachPaymentReviewItem> paymentItems;
  final List<CoachInsight> insights;
  final DateTime today;
  final DateTime weekStart;
  final DateTime weekEndExclusive;
  final bool hasPendingOperations;
  final bool hasUnallocatedPayments;
  final CoachFreshness freshness;
  final bool dailyReviewDue;
  final bool weeklyReviewDue;
  final List<CoachPlannedExpense> plannedExpenses;
  final CoachOverviewAvailability availability;
}

/// Identifies which inputs are backed by an initial value rather than a
/// loading/error placeholder. Missing inputs must never be interpreted as an
/// empty financial collection.
class CoachOverviewAvailability {
  const CoachOverviewAvailability({
    this.profile = true,
    this.reminderPreferences = true,
    this.routinePreferences = true,
    this.completions = true,
    this.commitments = true,
    this.paymentLinks = true,
    this.unallocatedPayments = true,
    this.budgetProgress = true,
    this.pendingOperations = true,
    this.report = true,
    this.planningEntries = true,
  });

  final bool profile;
  final bool reminderPreferences;
  final bool routinePreferences;
  final bool completions;
  final bool commitments;
  final bool paymentLinks;
  final bool unallocatedPayments;
  final bool budgetProgress;
  final bool pendingOperations;
  final bool report;
  final bool planningEntries;

  bool get commitmentPayments => profile && commitments && paymentLinks;
  bool get routines => profile && reminderPreferences && routinePreferences && completions;
  bool get budgets => profile && budgetProgress;
  bool get weeklyReport => profile && report;

  bool get actionSources =>
      pendingOperations &&
      commitmentPayments &&
      unallocatedPayments &&
      budgets &&
      routines &&
      planningEntries;

  bool get paymentItems => commitmentPayments && unallocatedPayments;
}

/// Pure priority and observation rules. All dates are already localized to
/// the user's profile time zone by the caller.
class CoachOverviewCalculator {
  const CoachOverviewCalculator();

  CoachOverview calculate({
    required DateTime nowLocal,
    required String zone,
    required CoachRoutine routine,
    required CoachPreferences reminderPreferences,
    required CoachRoutinePreferences routinePreferences,
    required List<CoachCompletion> completions,
    required List<DebtCommitment> commitments,
    required List<DebtCommitmentPaymentLink> paymentLinks,
    required List<FinancialOperation> unallocatedPayments,
    required List<CoachBudgetProgress> budgetProgress,
    required CoachPeriodReport report,
    required int rejectedSyncCount,
    required int pendingSyncCount,
    required CoachFreshness paymentFreshness,
    List<CoachPlannedExpense> plannedExpenses = const [],
    CoachOverviewAvailability availability = const CoachOverviewAvailability(),
  }) {
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final todayKey = coachDateKey(today);
    final monthKey = todayKey.substring(0, 7);
    final weekStart = routine.shift(today, zone, 1 - today.weekday);
    final previousWeekStart = routine.shift(weekStart, zone, -7);
    final previousWeekKey = coachDateKey(previousWeekStart);
    final weekEndExclusive = routine.shift(previousWeekStart, zone, 7);

    final nextMonthDate = DateTime(today.year, today.month + 1, 1);
    final nextMonthKey =
        '${nextMonthDate.year.toString().padLeft(4, '0')}-${nextMonthDate.month.toString().padLeft(2, '0')}';
    final dueItems = <CoachPaymentReviewItem>[];
    final upcomingItems = <CoachPaymentReviewItem>[];
    if (availability.commitmentPayments) {
      for (final commitment in commitments) {
        for (final occurrenceMonth in [monthKey, nextMonthKey]) {
          final due = commitment.scheduledDateFor(occurrenceMonth);
          if (due == null ||
              commitment.isSkipped(occurrenceMonth) ||
              commitment.isPausedFor(occurrenceMonth)) {
            continue;
          }
          final paid = paymentLinks
              .where(
                (link) => link.commitmentId == commitment.id && link.monthKey == occurrenceMonth,
              )
              .fold<int>(0, (sum, link) => sum + link.amountMinor);
          final remaining = (commitment.amountMinor - paid).clamp(0, commitment.amountMinor);
          if (remaining == 0) continue;
          final item = CoachPaymentReviewItem(
            id: 'commitment:${commitment.id}:$occurrenceMonth',
            dueDate: due,
            kind: due.isAfter(today)
                ? CoachActionKind.upcomingCommitment
                : CoachActionKind.dueCommitment,
            commitmentId: commitment.id,
            debtAccountId: commitment.debtAccountId,
            bankAccountId: commitment.bankAccountId,
            monthKey: occurrenceMonth,
            currency: commitment.currency,
            plannedMinor: commitment.amountMinor,
            paidMinor: paid,
            remainingMinor: remaining,
          );
          if (occurrenceMonth == monthKey && !due.isAfter(today)) {
            dueItems.add(item);
          } else if (due.isAfter(today) && !due.isAfter(routine.shift(today, zone, 7))) {
            upcomingItems.add(item);
          }
        }
      }
    }
    int comparePayment(CoachPaymentReviewItem a, CoachPaymentReviewItem b) {
      final due = a.dueDate.compareTo(b.dueDate);
      return due == 0 ? a.id.compareTo(b.id) : due;
    }

    dueItems.sort(comparePayment);
    upcomingItems.sort(comparePayment);
    final relevantExpenses = availability.planningEntries
        ? plannedExpenses.where((item) => item.pendingMinor > 0).toList()
        : <CoachPlannedExpense>[];
    final dueExpenses =
        relevantExpenses
            .where((item) => item.monthKey == monthKey && !item.dueDate.isAfter(today))
            .toList()
          ..sort((a, b) {
            final date = a.dueDate.compareTo(b.dueDate);
            return date == 0 ? a.id.compareTo(b.id) : date;
          });
    final nextWeek = routine.shift(today, zone, 7);
    final upcomingExpenses =
        relevantExpenses
            .where((item) => item.dueDate.isAfter(today) && !item.dueDate.isAfter(nextWeek))
            .toList()
          ..sort((a, b) {
            final date = a.dueDate.compareTo(b.dueDate);
            return date == 0 ? a.id.compareTo(b.id) : date;
          });
    final unresolved = availability.unallocatedPayments
        ? (unallocatedPayments
              .where(
                (operation) =>
                    operation.type == OperationType.unallocatedDebtPayment &&
                    operation.status == OperationStatus.confirmed &&
                    operation.allocationStatus == 'unallocated' &&
                    operation.debtAccountId != null &&
                    operation.projectionDirection == 1,
              )
              .toList()
            ..sort((a, b) {
              final date = a.occurredAt.compareTo(b.occurredAt);
              return date == 0 ? a.id.compareTo(b.id) : date;
            }))
        : <FinancialOperation>[];
    final unallocatedItems = unresolved.map(
      (operation) => CoachPaymentReviewItem(
        id: 'unallocated:${operation.id}',
        dueDate: operation.occurredAt,
        kind: CoachActionKind.unallocatedPayment,
        debtAccountId: operation.debtAccountId,
        monthKey: operation.monthKey,
        currency: operation.currency,
        remainingMinor: operation.amountMinor,
        operation: operation,
      ),
    );
    final paymentItems = [
      ...dueItems,
      ...upcomingItems,
      ...unallocatedItems,
    ].toList(growable: false);

    final currentBudget = availability.budgets
        ? (budgetProgress
              .where(
                (budget) =>
                    budget.active &&
                    budget.plannedMinor > 0 &&
                    budget.actualMinor >= budget.plannedMinor,
              )
              .toList()
            ..sort((a, b) {
              final currency = a.currency.compareTo(b.currency);
              return currency == 0 ? a.budgetId.compareTo(b.budgetId) : currency;
            }))
        : <CoachBudgetProgress>[];

    CoachAction? action;
    if (availability.pendingOperations && rejectedSyncCount > 0) {
      action = const CoachAction(kind: CoachActionKind.syncRejected, id: 'sync-rejected');
    } else if (availability.commitmentPayments && dueItems.isNotEmpty) {
      final item = dueItems.first;
      action = _actionFromPayment(item);
    } else if (availability.unallocatedPayments && unresolved.isNotEmpty) {
      final operation = unresolved.first;
      action = CoachAction(
        kind: CoachActionKind.unallocatedPayment,
        id: operation.id,
        debtAccountId: operation.debtAccountId,
        monthKey: operation.monthKey,
        currency: operation.currency,
        remainingMinor: operation.amountMinor,
        operation: operation,
      );
    } else if (availability.planningEntries && dueExpenses.isNotEmpty) {
      final item = dueExpenses.first;
      action = CoachAction(
        kind: CoachActionKind.dueBudgetExpense,
        id: item.id,
        budgetId: item.budgetId,
        budgetItemId: item.itemId,
        description: item.description,
        monthKey: item.monthKey,
        currency: item.currency,
        plannedMinor: item.plannedMinor,
        paidMinor: item.recordedMinor,
        remainingMinor: item.pendingMinor,
        dueDate: item.dueDate,
      );
    } else if (availability.commitmentPayments && upcomingItems.isNotEmpty) {
      final nextCommitment = upcomingItems.first;
      final nextExpense = upcomingExpenses.firstOrNull;
      if (nextExpense != null && nextExpense.dueDate.isBefore(nextCommitment.dueDate)) {
        action = _actionFromPlannedExpense(nextExpense);
      } else {
        action = _actionFromPayment(nextCommitment);
      }
    } else if (availability.planningEntries && upcomingExpenses.isNotEmpty) {
      action = _actionFromPlannedExpense(upcomingExpenses.first);
    } else if (availability.budgets && currentBudget.isNotEmpty) {
      final budget = currentBudget.first;
      action = CoachAction(
        kind: CoachActionKind.budgetReached,
        id: 'budget:${budget.budgetId}',
        budgetId: budget.budgetId,
        monthKey: monthKey,
        currency: budget.currency,
        plannedMinor: budget.plannedMinor,
        paidMinor: budget.actualMinor,
      );
    } else if (availability.routines &&
        routinePreferences.weeklyEnabled &&
        routine.weeklyReviewIsDue(
          today: today,
          nowLocal: nowLocal,
          preferences: reminderPreferences,
          completions: completions,
          periodKey: previousWeekKey,
        )) {
      action = CoachAction(
        kind: CoachActionKind.weeklyReview,
        id: 'weekly:$previousWeekKey',
        periodKey: previousWeekKey,
      );
    } else if (availability.routines &&
        routinePreferences.dailyEnabled &&
        routine.dailyReviewIsDue(
          today: today,
          nowLocal: nowLocal,
          preferences: reminderPreferences,
          completions: completions,
          periodKey: todayKey,
        )) {
      action = CoachAction(
        kind: CoachActionKind.dailyReview,
        id: 'daily:$todayKey',
        periodKey: todayKey,
      );
    } else if (availability.routines && !routinePreferences.configured) {
      action = const CoachAction(kind: CoachActionKind.configureRoutines, id: 'configure-routines');
    } else if (availability.actionSources) {
      action = const CoachAction(kind: CoachActionKind.current, id: 'current');
    }

    final insights = <CoachInsight>[];
    if ((availability.pendingOperations && pendingSyncCount > 0) || unresolved.isNotEmpty) {
      insights.add(
        const CoachInsight(kind: CoachInsightKind.incompleteInformation, id: 'incomplete'),
      );
    }
    final topByCurrency = availability.weeklyReport
        ? report.topCategoriesByCurrency
        : const <String, List<CoachCategoryTotal>>{};
    for (final currency in topByCurrency.keys.toList()..sort()) {
      final top = topByCurrency[currency]?.firstOrNull;
      if (top != null) {
        insights.add(
          CoachInsight(
            kind: CoachInsightKind.largestWeeklyCategory,
            id: 'weekly-category:$currency:${top.categoryId}',
            currency: currency,
            categoryId: top.categoryId,
            amountMinor: top.amountMinor,
            periodKey: previousWeekKey,
          ),
        );
      }
    }
    for (final budget in currentBudget) {
      insights.add(
        CoachInsight(
          kind: CoachInsightKind.budgetReached,
          id: 'budget:${budget.budgetId}',
          currency: budget.currency,
          budgetId: budget.budgetId,
          amountMinor: budget.actualMinor,
        ),
      );
    }
    return CoachOverview(
      action: action,
      paymentItems: paymentItems,
      insights: List.unmodifiable(insights),
      today: today,
      weekStart: previousWeekStart,
      weekEndExclusive: weekEndExclusive,
      hasPendingOperations: availability.pendingOperations && pendingSyncCount > 0,
      hasUnallocatedPayments: unresolved.isNotEmpty,
      freshness:
          paymentFreshness == CoachFreshness.cached ||
              (availability.budgetProgress && budgetProgress.any((value) => value.cached)) ||
              (availability.report && report.freshness == CoachFreshness.cached)
          ? CoachFreshness.cached
          : CoachFreshness.fresh,
      dailyReviewDue:
          availability.routines &&
          routinePreferences.dailyEnabled &&
          routine.dailyReviewIsDue(
            today: today,
            nowLocal: nowLocal,
            preferences: reminderPreferences,
            completions: completions,
            periodKey: todayKey,
          ),
      weeklyReviewDue:
          availability.routines &&
          routinePreferences.weeklyEnabled &&
          routine.weeklyReviewIsDue(
            today: today,
            nowLocal: nowLocal,
            preferences: reminderPreferences,
            completions: completions,
            periodKey: previousWeekKey,
          ),
      plannedExpenses: List.unmodifiable(relevantExpenses),
      availability: availability,
    );
  }

  CoachAction _actionFromPayment(CoachPaymentReviewItem item) => CoachAction(
    kind: item.kind,
    id: item.id,
    debtAccountId: item.debtAccountId,
    bankAccountId: item.bankAccountId,
    commitmentId: item.commitmentId,
    monthKey: item.monthKey,
    currency: item.currency,
    plannedMinor: item.plannedMinor,
    paidMinor: item.paidMinor,
    remainingMinor: item.remainingMinor,
    dueDate: item.dueDate,
    operation: item.operation,
  );

  CoachAction _actionFromPlannedExpense(CoachPlannedExpense item) => CoachAction(
    kind: CoachActionKind.upcomingBudgetExpense,
    id: item.id,
    budgetId: item.budgetId,
    budgetItemId: item.itemId,
    description: item.description,
    monthKey: item.monthKey,
    currency: item.currency,
    plannedMinor: item.plannedMinor,
    paidMinor: item.recordedMinor,
    remainingMinor: item.pendingMinor,
    dueDate: item.dueDate,
  );
}
