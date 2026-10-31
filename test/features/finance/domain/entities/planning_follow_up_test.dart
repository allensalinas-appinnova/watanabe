import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/commitments/domain/commitment_repository.dart';
import 'package:personal_finance/features/commitments/domain/debt_commitment.dart';
import 'package:personal_finance/features/commitments/domain/debt_reminder_plan.dart';
import 'package:personal_finance/features/finance/domain/entities/home_dashboard_preferences.dart';
import 'package:personal_finance/features/finance/domain/entities/planning_agenda_entry.dart';
import 'package:personal_finance/features/finance/domain/entities/planning_follow_up.dart';

PlanningAgendaEntry entry(PlanningFollowUpState state, {String? remindOn}) => PlanningAgendaEntry(
  id: 'budget:barber:one',
  kind: PlanningEntryKind.expense,
  date: DateTime(2026, 10, 15),
  title: 'QA Barber',
  currency: 'COP',
  plannedMinor: 50000,
  recordedMinor: 25000,
  pendingMinor: 25000,
  monthKey: '2026-10',
  budgetId: 'barber',
  itemId: 'one',
  followUpState: state,
  remindOn: remindOn,
);

void main() {
  test(
    'a partial expense remains open until explicitly finished; dismiss and finish preserve its amounts',
    () {
      expect(entry(PlanningFollowUpState.open).needsAttention(DateTime(2026, 10, 31)), isTrue);
      for (final state in [PlanningFollowUpState.completed, PlanningFollowUpState.dismissed]) {
        final row = entry(state);
        expect(row.needsAttention(DateTime(2026, 10, 31)), isFalse);
        expect(row.plannedMinor, 50000);
        expect(row.recordedMinor, 25000);
        expect(row.pendingMinor, 25000);
      }
    },
  );
  test('snoozed previous-period expense returns on the chosen calendar day', () {
    final row = entry(PlanningFollowUpState.snoozed, remindOn: '2026-11-01');
    expect(row.needsAttention(DateTime(2026, 10, 31, 23, 59)), isFalse);
    expect(row.needsAttention(DateTime(2026, 11, 1)), isTrue);
    expect(row.monthKey, '2026-10');
  });
  test('legacy Home visibility merges either old card while preserving the both-hidden case', () {
    for (final visible in [
      {'coachNextStep'},
      {'debtCommitments'},
      {'coachNextStep', 'debtCommitments'},
    ]) {
      expect(
        HomeDashboardPreferences(visibleWidgets: visible).shows(HomeDashboardWidget.coachNextStep),
        isTrue,
      );
    }
    expect(
      const HomeDashboardPreferences(visibleWidgets: {}).shows(HomeDashboardWidget.coachNextStep),
      isFalse,
    );
  });
  group('joint reminder plan', () {
    const plan = DebtCommitment(
      id: 'vehicle',
      debtAccountId: 'loan',
      currency: 'COP',
      amountMinor: 2400000,
      firstDueMonth: '2026-10',
      lastDueMonth: '2026-10',
      dueDay: 31,
      remindersEnabled: true,
    );
    const source = PlanningSource(
      kind: PlanningSourceKind.debt,
      commitmentId: 'vehicle',
      monthKey: '2026-10',
    );
    List<DebtReminderCandidate> schedule(
      PlanningFollowUpState state, {
      List<DebtCommitmentPaymentLink> payments = const [],
    }) => planDebtReminders(
      today: DateTime(2026, 10, 29),
      commitments: [plan],
      payments: payments,
      followUps: [
        PlanningFollowUp(
          source: source,
          state: state,
          version: 1,
          dataGeneration: 0,
          remindOn: '2026-11-02',
        ),
      ],
    );
    test('snooze replaces the two due-date reminders and retains original period', () {
      expect(schedule(PlanningFollowUpState.open).map((n) => n.date), [
        DateTime(2026, 10, 30),
        DateTime(2026, 10, 31),
      ]);
      final later = schedule(PlanningFollowUpState.snoozed);
      expect(later.single.date, DateTime(2026, 11, 2));
      expect(later.single.monthKey, '2026-10');
      expect(schedule(PlanningFollowUpState.dismissed), isEmpty);
    });
    test('payment during snooze cancels the remaining reminder', () {
      expect(
        schedule(
          PlanningFollowUpState.snoozed,
          payments: const [
            DebtCommitmentPaymentLink(
              paymentId: 'paid',
              commitmentId: 'vehicle',
              monthKey: '2026-10',
              amountMinor: 2400000,
            ),
          ],
        ),
        isEmpty,
      );
    });
    test('resuming after the due day never schedules an overdue notice', () {
      expect(
        planDebtReminders(
          today: DateTime(2026, 11, 1),
          commitments: [plan],
          payments: const [],
          followUps: const [],
        ),
        isEmpty,
      );
    });
    test('skip and pause cancel even a snoozed installment', () {
      for (final paused in [false, true]) {
        final inactive = DebtCommitment(
          id: plan.id,
          debtAccountId: plan.debtAccountId,
          currency: plan.currency,
          amountMinor: plan.amountMinor,
          firstDueMonth: plan.firstDueMonth,
          dueDay: plan.dueDay,
          remindersEnabled: true,
          lastDueMonth: plan.lastDueMonth,
          pausedFromMonth: paused ? '2026-10' : null,
          skippedMonths: paused ? const {} : const {'2026-10'},
        );
        expect(
          planDebtReminders(
            today: DateTime(2026, 10, 29),
            commitments: [inactive],
            payments: const [],
            followUps: const [
              PlanningFollowUp(
                source: source,
                state: PlanningFollowUpState.snoozed,
                version: 1,
                dataGeneration: 0,
                remindOn: '2026-11-02',
              ),
            ],
          ),
          isEmpty,
        );
      }
    });
    test('effective terms and one-month overrides preserve historical amounts and dates', () {
      const versioned = DebtCommitment(
        id: 'versioned',
        debtAccountId: 'loan',
        currency: 'COP',
        amountMinor: 500,
        firstDueMonth: '2026-01',
        dueDay: 20,
        versions: [
          DebtCommitmentTerms(
            version: 1,
            effectiveFromMonth: '2026-01',
            amountMinor: 100,
            dueDay: 31,
            remindersEnabled: false,
          ),
          DebtCommitmentTerms(
            version: 2,
            effectiveFromMonth: '2026-11',
            amountMinor: 500,
            dueDay: 20,
            remindersEnabled: true,
          ),
        ],
        occurrenceOverrides: {
          '2026-10': DebtCommitmentTerms(
            version: 1,
            effectiveFromMonth: '2026-10',
            amountMinor: 200,
            dueDay: 15,
            remindersEnabled: false,
          ),
        },
      );
      expect(versioned.forMonth('2026-09').amountMinor, 100);
      expect(versioned.forMonth('2026-10').amountMinor, 200);
      expect(versioned.dueDateFor('2026-10'), DateTime(2026, 10, 15));
      expect(versioned.forMonth('2026-11').amountMinor, 500);
      expect(versioned.dueDateFor('2026-11'), DateTime(2026, 11, 20));
    });
  });
}
