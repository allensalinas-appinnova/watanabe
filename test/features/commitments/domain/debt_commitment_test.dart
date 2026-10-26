import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/commitments/domain/debt_commitment.dart';

void main() {
  group('DebtCommitment', () {
    test('clamps due days to the final day of shorter months and leap years', () {
      const plan = DebtCommitment(
        id: 'vehicle',
        debtAccountId: 'loan',
        currency: 'COP',
        amountMinor: 240000000,
        firstDueMonth: '2026-01',
        dueDay: 31,
      );
      expect(plan.dueDateFor('2026-02'), DateTime(2026, 2, 28));
      expect(plan.dueDateFor('2024-02'), isNull); // Before the first planned month.
      const leapPlan = DebtCommitment(
        id: 'leap',
        debtAccountId: 'loan',
        currency: 'COP',
        amountMinor: 1,
        firstDueMonth: '2024-01',
        dueDay: 31,
      );
      expect(leapPlan.dueDateFor('2024-02'), DateTime(2024, 2, 29));
    });

    test('occurrence tracks partial, complete and missed payments independently', () {
      const plan = DebtCommitment(
        id: 'vehicle',
        debtAccountId: 'loan',
        currency: 'COP',
        amountMinor: 2400,
        firstDueMonth: '2026-10',
        dueDay: 15,
      );
      const partial = DebtCommitmentOccurrence(
        commitment: plan,
        monthKey: '2026-10',
        paidMinor: 500,
      );
      expect(partial.remainingMinor, 1900);
      expect(partial.statusAt(DateTime(2026, 10, 10)), DebtInstallmentStatus.partiallyPaid);
      const paid = DebtCommitmentOccurrence(commitment: plan, monthKey: '2026-10', paidMinor: 2400);
      expect(paid.statusAt(DateTime(2026, 10, 16)), DebtInstallmentStatus.paid);
      const overdue = DebtCommitmentOccurrence(commitment: plan, monthKey: '2026-10', paidMinor: 0);
      expect(overdue.statusAt(DateTime(2026, 10, 16)), DebtInstallmentStatus.missed);
    });

    test('respects first, last and paused-from months', () {
      const plan = DebtCommitment(
        id: 'vehicle',
        debtAccountId: 'loan',
        currency: 'COP',
        amountMinor: 2400,
        firstDueMonth: '2026-10',
        dueDay: 30,
        lastDueMonth: '2026-12',
        pausedFromMonth: '2026-12',
      );
      expect(plan.dueDateFor('2026-09'), isNull);
      expect(plan.dueDateFor('2026-10'), DateTime(2026, 10, 30));
      expect(plan.dueDateFor('2027-01'), isNull);
      expect(plan.dueDateFor('2026-12'), isNull);
    });

    test('skipped installments no longer count as an amount due', () {
      const plan = DebtCommitment(
        id: 'vehicle',
        debtAccountId: 'loan',
        currency: 'COP',
        amountMinor: 2400,
        firstDueMonth: '2026-10',
        dueDay: 31,
        skippedMonths: {'2026-10'},
      );
      final occurrence = DebtCommitmentOccurrence(
        commitment: plan,
        monthKey: '2026-10',
        paidMinor: 0,
        skipped: plan.isSkipped('2026-10'),
      );
      expect(occurrence.plannedMinor, 0);
      expect(occurrence.remainingMinor, 0);
      expect(occurrence.status, DebtInstallmentStatus.skipped);
    });
  });
}
