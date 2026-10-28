import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/coach/data/calendar/zoned_coach_calendar.dart';
import 'package:personal_finance/features/coach/domain/entities/coach_models.dart';
import 'package:personal_finance/features/coach/domain/usecases/coach_overview.dart';
import 'package:personal_finance/features/coach/domain/usecases/coach_routine.dart';
import 'package:personal_finance/features/commitments/domain/commitment_repository.dart';
import 'package:personal_finance/features/commitments/domain/debt_commitment.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';

class _Clock implements CoachClock {
  _Clock(this.value);
  final DateTime value;
  @override
  DateTime now() => value;
}

void main() {
  CoachOverview calculate({
    DateTime? now,
    List<DebtCommitment> commitments = const [],
    List<DebtCommitmentPaymentLink> links = const [],
    List<FinancialOperation> unallocated = const [],
    List<CoachBudgetProgress> budgets = const [],
    List<CoachCompletion> completions = const [],
    CoachRoutinePreferences routinePreferences = const CoachRoutinePreferences(),
    CoachPreferences reminderPreferences = const CoachPreferences(),
    CoachPeriodReport? report,
    int rejected = 0,
    CoachFreshness freshness = CoachFreshness.fresh,
  }) {
    final instant = now ?? DateTime(2026, 10, 28, 21);
    final routine = CoachRoutine(ZonedCoachCalendar(), _Clock(instant.toUtc()));
    final start = DateTime(2026, 10, 19);
    return const CoachOverviewCalculator().calculate(
      nowLocal: instant,
      zone: 'America/Bogota',
      routine: routine,
      reminderPreferences: reminderPreferences,
      routinePreferences: routinePreferences,
      completions: completions,
      commitments: commitments,
      paymentLinks: links,
      unallocatedPayments: unallocated,
      budgetProgress: budgets,
      report:
          report ??
          CoachPeriodReport(
            startAt: start,
            endAtExclusive: DateTime(2026, 10, 26),
            operations: const [],
            freshness: CoachFreshness.fresh,
          ),
      rejectedSyncCount: rejected,
      pendingSyncCount: 0,
      paymentFreshness: freshness,
    );
  }

  DebtCommitment commitment({
    String id = 'vehicle',
    int day = 28,
    int amount = 240000,
  }) => DebtCommitment(
    id: id,
    debtAccountId: 'debt-$id',
    currency: 'COP',
    amountMinor: amount,
    firstDueMonth: '2026-01',
    dueDay: day,
  );

  FinancialOperation unallocated(String id, {DateTime? at}) => FinancialOperation(
    id: id,
    type: OperationType.unallocatedDebtPayment,
    amountMinor: 50000,
    currency: 'COP',
    monthKey: '2025-01',
    occurredAt: at ?? DateTime(2025, 1, 5),
    status: OperationStatus.confirmed,
    idempotencyKey: id,
    debtAccountId: 'loan-1',
    allocationStatus: 'unallocated',
  );

  test('rejected sync outranks due installments and all other actions', () {
    final result = calculate(
      commitments: [commitment()],
      rejected: 1,
      routinePreferences: const CoachRoutinePreferences(configured: true),
    );
    expect(result.action.kind, CoachActionKind.syncRejected);
  });

  test('current month due installment outranks an old unallocated payment', () {
    final result = calculate(
      commitments: [commitment()],
      unallocated: [unallocated('old-payment')],
      routinePreferences: const CoachRoutinePreferences(configured: true),
    );
    expect(result.action.kind, CoachActionKind.dueCommitment);
    expect(result.action.remainingMinor, 240000);
    expect(result.paymentItems.map((item) => item.kind), [
      CoachActionKind.dueCommitment,
      CoachActionKind.unallocatedPayment,
    ]);
  });

  test('old unallocated payments are considered regardless of age and outrank upcoming dues', () {
    final result = calculate(
      now: DateTime(2026, 10, 20, 21),
      commitments: [commitment(day: 24)],
      unallocated: [unallocated('old-payment')],
      routinePreferences: const CoachRoutinePreferences(configured: true),
    );
    expect(result.action.kind, CoachActionKind.unallocatedPayment);
    expect(result.action.id, 'old-payment');
    expect(result.paymentItems.last.kind, CoachActionKind.unallocatedPayment);
  });

  test('payment progress is scoped to the month and leaves only the unpaid amount', () {
    final result = calculate(
      commitments: [commitment()],
      links: const [
        DebtCommitmentPaymentLink(
          paymentId: 'payment-1',
          commitmentId: 'vehicle',
          monthKey: '2026-10',
          amountMinor: 90000,
        ),
        DebtCommitmentPaymentLink(
          paymentId: 'payment-prior-month',
          commitmentId: 'vehicle',
          monthKey: '2026-09',
          amountMinor: 240000,
        ),
      ],
      routinePreferences: const CoachRoutinePreferences(configured: true),
    );
    expect(result.action.kind, CoachActionKind.dueCommitment);
    expect(result.action.paidMinor, 90000);
    expect(result.action.remainingMinor, 150000);
  });

  test('next-month installment is included when it falls inside the next seven days', () {
    final result = calculate(
      now: DateTime(2026, 10, 30, 21),
      commitments: [commitment(day: 2)],
      links: const [
        DebtCommitmentPaymentLink(
          paymentId: 'october-payment',
          commitmentId: 'vehicle',
          monthKey: '2026-10',
          amountMinor: 240000,
        ),
      ],
      routinePreferences: const CoachRoutinePreferences(configured: true),
    );
    expect(result.action.kind, CoachActionKind.upcomingCommitment);
    expect(result.action.monthKey, '2026-11');
    expect(result.paymentItems.single.dueDate, DateTime(2026, 11, 2));
  });

  test('budget action requires a positive active expense budget at or above its plan', () {
    final result = calculate(
      budgets: const [
        CoachBudgetProgress(
          budgetId: 'reached',
          categoryId: 'food',
          currency: 'COP',
          plannedMinor: 100000,
          actualMinor: 100000,
          active: true,
        ),
        CoachBudgetProgress(
          budgetId: 'zero',
          categoryId: 'health',
          currency: 'COP',
          plannedMinor: 0,
          actualMinor: 100,
          active: true,
        ),
        CoachBudgetProgress(
          budgetId: 'archived',
          categoryId: 'rent',
          currency: 'COP',
          plannedMinor: 100,
          actualMinor: 100,
          active: false,
        ),
      ],
      routinePreferences: const CoachRoutinePreferences(configured: true),
    );
    expect(result.action.kind, CoachActionKind.budgetReached);
    expect(result.action.budgetId, 'reached');
    expect(
      result.insights.where((item) => item.kind == CoachInsightKind.budgetReached),
      hasLength(1),
    );
  });

  test('routine priorities require selection and the configured local schedule', () {
    final weeklyDue = calculate(
      now: DateTime(2026, 10, 26, 10),
      routinePreferences: const CoachRoutinePreferences(configured: true, weeklyEnabled: true),
      reminderPreferences: const CoachPreferences(weeklyWeekday: 1, weeklyHour: 9),
    );
    expect(weeklyDue.action.kind, CoachActionKind.weeklyReview);
    expect(weeklyDue.weeklyReviewDue, isTrue);

    final beforeDailyTime = calculate(
      now: DateTime(2026, 10, 28, 19),
      routinePreferences: const CoachRoutinePreferences(configured: true, dailyEnabled: true),
      reminderPreferences: const CoachPreferences(dailyHour: 20),
    );
    expect(beforeDailyTime.action.kind, CoachActionKind.current);
    expect(beforeDailyTime.dailyReviewDue, isFalse);
  });

  test('weekly category insight nets refunds and reversals per currency', () {
    final report = CoachPeriodReport(
      startAt: DateTime(2026, 10, 19),
      endAtExclusive: DateTime(2026, 10, 26),
      freshness: CoachFreshness.fresh,
      operations: [
        _expense('food-1', amount: 10000, category: 'food'),
        _expense('food-refund', amount: 2500, category: 'food', type: OperationType.expenseRefund),
        _expense('food-reversal', amount: 1000, category: 'food', direction: -1),
        _expense('rent', amount: 5000, category: 'rent'),
        _expense('usd', amount: 500, category: 'travel', currency: 'USD'),
      ],
    );
    final result = calculate(
      report: report,
      routinePreferences: const CoachRoutinePreferences(configured: true),
    );
    final categories = result.insights
        .where((item) => item.kind == CoachInsightKind.largestWeeklyCategory)
        .toList();
    expect(categories.map((item) => item.currency), ['COP', 'USD']);
    expect(categories.first.categoryId, 'food');
    expect(categories.first.amountMinor, 6500);
  });

  test('cache freshness propagates to overview; a cached empty report is not definitive', () {
    final result = calculate(
      freshness: CoachFreshness.cached,
      routinePreferences: const CoachRoutinePreferences(configured: true),
      report: CoachPeriodReport(
        startAt: DateTime(2026, 10, 19),
        endAtExclusive: DateTime(2026, 10, 26),
        operations: const [],
        freshness: CoachFreshness.cached,
      ),
    );
    expect(result.freshness, CoachFreshness.cached);
  });
}

FinancialOperation _expense(
  String id, {
  required int amount,
  required String category,
  OperationType type = OperationType.expense,
  int direction = 1,
  String currency = 'COP',
}) => FinancialOperation(
  id: id,
  type: type,
  amountMinor: amount,
  currency: currency,
  monthKey: '2026-10',
  occurredAt: DateTime(2026, 10, 21),
  status: OperationStatus.confirmed,
  idempotencyKey: id,
  categoryId: category,
  projectionDirection: direction,
);
