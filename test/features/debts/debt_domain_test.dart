import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/coach/domain/entities/coach_models.dart';
import 'package:personal_finance/features/debts/domain/debt_command.dart';
import 'package:personal_finance/features/debts/domain/recorded_position.dart';
import 'package:personal_finance/features/finance/domain/entities/activity_report.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';

FinancialOperation op(
  String id,
  OperationType type,
  int amount, {
  String? command,
  int direction = 1,
  String currency = 'COP',
}) => FinancialOperation(
  id: id,
  type: type,
  amountMinor: amount,
  currency: currency,
  monthKey: '2026-01',
  occurredAt: DateTime.utc(2026),
  status: OperationStatus.confirmed,
  idempotencyKey: id,
  categoryId: 'food',
  debtCommandId: command,
  projectionDirection: direction,
);

void main() {
  test('legacy negative money is not reinterpreted as debt; currencies never mix', () {
    final groups = RecordedPosition.byCurrency(const [
      FinanceAccount(id: 'bank', name: '', type: 'checking', currentBalanceMinor: -100),
      FinanceAccount(
        id: 'card',
        name: '',
        type: 'creditCard',
        nature: 'debt',
        currentBalanceMinor: -200,
      ),
      FinanceAccount(
        id: 'credit',
        name: '',
        type: 'creditCard',
        nature: 'debt',
        currentBalanceMinor: 50,
      ),
      FinanceAccount(
        id: 'hidden',
        name: '',
        type: 'bankLoan',
        nature: 'debt',
        currentBalanceMinor: -999,
        includeInDashboard: false,
      ),
      FinanceAccount(
        id: 'archived',
        name: '',
        type: 'checking',
        currentBalanceMinor: 999,
        status: 'archived',
      ),
      FinanceAccount(id: 'usd', name: '', type: 'cash', currency: 'USD', currentBalanceMinor: 20),
    ]);
    expect(groups['COP']!.moneyMinor, -100);
    expect(groups['COP']!.debtMinor, 200);
    expect(groups['COP']!.cardCreditMinor, 50);
    expect(groups['COP']!.netMinor, -250);
    expect(groups['USD']!.netMinor, 20);
  });

  test('payment breakdown requires explicit components and exact total', () {
    const split = DebtPaymentSplit(
      principalMinor: 300,
      previousChargesMinor: 100,
      newChargesMinor: 50,
    );
    expect(split.matches(450), true);
    expect(split.matches(451), false);
    expect(
      const DebtPaymentSplit(
        principalMinor: -1,
        previousChargesMinor: 2,
        newChargesMinor: 0,
      ).matches(1),
      false,
    );
  });

  test('refunds and reversals reduce expenses; capital and adjustments never inflate result', () {
    final operations = [
      op('buy', OperationType.expense, 1000),
      op('refund', OperationType.expenseRefund, 200),
      op('reverse', OperationType.expense, 100, direction: -1),
      op('pay', OperationType.transfer, 1000, command: 'payment'),
      op('fee', OperationType.expense, 50, command: 'payment'),
      op('adjust', OperationType.debtAdjustment, 500),
      op('usd', OperationType.expense, 20, currency: 'USD'),
    ];
    final report = ActivityReport.fromOperations(operations);
    expect(report.totalsByCurrency['COP']!.incomeMinor, 0);
    expect(report.totalsByCurrency['COP']!.expenseMinor, 750);
    expect(report.totalsByCurrency['COP']!.netMinor, -750);
    expect(report.totalsByCurrency['USD']!.expenseMinor, 20);
    expect(report.confirmedOperationCount, 6);
    final coach = CoachPeriodReport(
      startAt: DateTime.utc(2026),
      endAtExclusive: DateTime.utc(2026, 1, 8),
      operations: operations,
      freshness: CoachFreshness.fresh,
    );
    expect(coach.topCategoriesByCurrency['COP']!.single.amountMinor, 750);
  });

  test('command envelope preserves stable request and protects caller-owned fields', () {
    final fields = <String, Object?>{'action': 'pay'};
    final command = DebtCommand(requestId: 'stable_request', fields: fields);
    fields['action'] = 'purchase';
    expect(command.toMap()['action'], 'pay');
    expect(command.toMap()['requestId'], 'stable_request');
    expect(() => command.fields['action'] = 'other', throwsUnsupportedError);
  });
}
