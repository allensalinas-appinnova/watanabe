import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/diagnostics/domain/diagnostic_engine.dart';
import 'package:personal_finance/features/diagnostics/domain/diagnostic_record.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/domain/entities/ledger_entry.dart';
import 'package:personal_finance/features/finance/domain/entities/planning_agenda_entry.dart';

DiagnosticRecord record(String id, String kind, Map<String, Object> values) =>
    DiagnosticRecord(id, kind, values);
final today = DateTime(2026, 10, 29);
const bank = FinanceAccount(
  id: 'bank',
  name: 'Bank',
  type: 'bank',
  currentBalanceMinor: 1000,
  includeInDashboard: false,
);
const debt = FinanceAccount(
  id: 'loan',
  name: 'Loan',
  type: 'bankLoan',
  nature: 'debt',
  currentBalanceMinor: -20000,
  principalMinor: 20000,
);
List<DiagnosticRecord> baseRecords() => [
  record('context', 'context', {
    'accountsComplete': 'yes',
    'debtsComplete': 'yes',
    'verifiedOn': '2026-10-29',
    'completeMonths': '2026-07,2026-08,2026-09',
    'confirmedPlanMonths': '2026-10,2026-11,2026-12,2027-01',
  }),
  record('account-bank', 'account', {'accountId': 'bank', 'availability': 'immediate'}),
];
FinancialOperation op(
  String id,
  OperationType type,
  int amount, {
  String accountId = 'bank',
  String? destination,
  String? source,
  String? debtKind,
  String month = '2026-10',
  int direction = 1,
  String? reversalOf,
  String? categoryId,
}) => FinancialOperation(
  id: id,
  type: type,
  amountMinor: amount,
  currency: 'COP',
  monthKey: month,
  occurredAt: DateTime.parse('$month-15'),
  status: OperationStatus.confirmed,
  idempotencyKey: id,
  accountId: accountId,
  sourceAccountId: source,
  destinationAccountId: destination,
  projectionDirection: direction,
  reversalOf: reversalOf,
  categoryId: categoryId,
  debtKind: debtKind,
);
LedgerEntry entry(String id, int delta, {String accountId = 'bank', String? operationId}) =>
    LedgerEntry(
      id: id,
      operationId: operationId ?? id,
      accountId: accountId,
      deltaMinor: delta,
      currency: 'COP',
    );
PlanningAgendaEntry plan(
  String id,
  int amount, {
  DateTime? date,
  PlanningEntryKind kind = PlanningEntryKind.expense,
  int recorded = 0,
  String? accountId,
}) => PlanningAgendaEntry(
  id: id,
  kind: kind,
  date: date ?? DateTime(2026, 11, 1),
  title: id,
  currency: 'COP',
  plannedMinor: amount,
  recordedMinor: recorded,
  pendingMinor: amount - recorded,
  monthKey: diagnosticMonth(date ?? DateTime(2026, 11, 1)),
  bankAccountId: accountId,
);
DiagnosticReport calculate({
  List<FinanceAccount> accounts = const [bank, debt],
  List<FinancialOperation> operations = const [],
  List<LedgerEntry> entries = const [],
  List<PlanningAgendaEntry> plans = const [],
  List<DiagnosticRecord>? records,
  int reduction = 0,
  int increase = 0,
}) => const DiagnosticEngine().calculate(
  DiagnosticInput(
    today: today,
    accounts: accounts,
    operations: operations,
    entries: entries,
    plan: plans,
    records: records ?? baseRecords(),
    incomeReductionPercent: reduction,
    expenseIncreasePercent: increase,
  ),
);
num? metric(DiagnosticReport report, String key, {String currency = 'COP'}) =>
    report.metrics.firstWhere((m) => m.key == key && m.currency == currency).value;

void main() {
  test('positive result can coexist with negative cash due to principal payment', () {
    final report = calculate(
      operations: [
        op('income', OperationType.income, 5000),
        op('expense', OperationType.expense, 3000),
        op('principal', OperationType.transfer, 2400, destination: 'loan', source: 'bank'),
      ],
      entries: [
        entry('income', 5000),
        entry('expense', -3000),
        entry('principal', -2400),
        entry('principal-loan', 2400, accountId: 'loan', operationId: 'principal'),
      ],
    );
    expect(metric(report, 'result'), 2000);
    expect(metric(report, 'cashFlow'), -400);
    expect(report.findings.any((f) => f.key == 'positiveResultNegativeCash'), isTrue);
  });
  test('hidden Home accounts still contribute to diagnosis; explicit exclusion removes them', () {
    expect(metric(calculate(), 'freeMoney'), 1000);
    final records = baseRecords()
      ..[1] = record('account-bank', 'account', {
        'accountId': 'bank',
        'availability': 'immediate',
        'excluded': 'yes',
        'reason': 'Outside personal scope',
      });
    expect(metric(calculate(records: records), 'freeMoney'), 0);
  });
  test('card purchase and payment are not both consumption or both projected bank outflows', () {
    final p = plan('budget:b:purchase', 300);
    final payment = plan('debt:card:2026-11', 300, kind: PlanningEntryKind.debt, accountId: 'bank');
    final records = [
      ...baseRecords(),
      record('card-plan', 'plan', {'entryId': p.id, 'effect': 'card', 'accountId': 'card'}),
    ];
    final report = calculate(plans: [p, payment], records: records);
    expect(report.projection, hasLength(1));
    expect(report.projection.single.balanceMinor, 700);
    final actual = calculate(
      accounts: [
        ...[bank],
        const FinanceAccount(id: 'card', name: 'Card', type: 'creditCard', nature: 'debt'),
      ],
      operations: [
        op('purchase', OperationType.expense, 300, accountId: 'card'),
        op('payment', OperationType.transfer, 300, source: 'bank', destination: 'card'),
      ],
      entries: [
        entry('purchase', -300, accountId: 'card'),
        entry('payment', -300),
        entry('payment-card', 300, accountId: 'card', operationId: 'payment'),
      ],
    );
    expect(metric(actual, 'result'), -300);
    expect(metric(actual, 'cashFlow'), -300);
  });
  test('same-day payment precedes income and detects temporary account shortfall', () {
    final records = [
      ...baseRecords(),
      record('out', 'plan', {'entryId': 'budget:b:out', 'accountId': 'bank', 'effect': 'cash'}),
      record('in', 'plan', {'entryId': 'budget:b:in', 'accountId': 'bank', 'effect': 'cash'}),
    ];
    final report = calculate(
      plans: [
        plan('budget:b:in', 1000, kind: PlanningEntryKind.income),
        plan('budget:b:out', 1500),
      ],
      records: records,
    );
    expect(report.projection.first.deltaMinor, -1500);
    expect(metric(report, 'minimumCash'), -500);
    expect(report.findings.where((f) => f.key == 'cashShortfall'), hasLength(1));
  });
  test('past unpaid commitments are not silently rescheduled', () {
    final report = calculate(
      plans: [
        plan(
          'past',
          400,
          date: DateTime(2026, 10, 28),
          kind: PlanningEntryKind.debt,
          accountId: 'bank',
        ),
      ],
    );
    expect(report.projection, isEmpty);
    expect(report.findings.any((f) => f.key == 'unconfirmedPastPayment'), isTrue);
  });
  test('partially paid obligation projects remaining amount only', () {
    final report = calculate(
      plans: [
        plan(
          'debt:loan:2026-11',
          600,
          recorded: 200,
          kind: PlanningEntryKind.debt,
          accountId: 'bank',
        ),
      ],
    );
    expect(report.projection.single.deltaMinor, -400);
  });
  test('payment releases its reserve without deducting it twice', () {
    final records = [
      ...baseRecords(),
      record('rent', 'reserve', {
        'accountId': 'bank',
        'currency': 'COP',
        'purpose': 'obligation',
        'amountMinor': 600,
        'entryId': 'debt:loan:2026-11',
      }),
    ];
    final report = calculate(
      plans: [plan('debt:loan:2026-11', 600, kind: PlanningEntryKind.debt, accountId: 'bank')],
      records: records,
    );
    expect(metric(report, 'freeMoney'), 400);
    expect(report.projection.single.freeMinor, 400);
  });
  test('restricted and unknown funds do not appear as available cash', () {
    final restricted = baseRecords()
      ..[1] = record('account-bank', 'account', {
        'accountId': 'bank',
        'availability': 'restricted',
      });
    expect(metric(calculate(records: restricted), 'freeMoney'), 0);
    expect(metric(calculate(records: [baseRecords().first]), 'freeMoney'), isNull);
  });
  test('currencies stay separate and negative starting balance is a finding', () {
    final report = calculate(
      accounts: [
        const FinanceAccount(id: 'bank', name: 'Bank', type: 'bank', currentBalanceMinor: -500),
        const FinanceAccount(
          id: 'usd',
          name: 'USD',
          type: 'bank',
          currency: 'USD',
          currentBalanceMinor: 10000,
        ),
      ],
      records: [
        ...baseRecords(),
        record('usd', 'account', {'accountId': 'usd', 'availability': 'immediate'}),
      ],
    );
    expect(metric(report, 'freeMoney'), -500);
    expect(metric(report, 'freeMoney', currency: 'USD'), 10000);
    expect(report.findings.any((f) => f.key == 'cashShortfall'), isTrue);
  });
  test('stress modifies calculation but not source records or plan', () {
    final p = plan('budget:b:item', 800);
    final records = [
      ...baseRecords(),
      record('mapping', 'plan', {'entryId': p.id, 'accountId': 'bank', 'effect': 'cash'}),
    ];
    final baseline = calculate(plans: [p], records: records);
    final stress = calculate(plans: [p], records: records, increase: 50);
    expect(baseline.projection.single.balanceMinor, 200);
    expect(stress.projection.single.balanceMinor, -200);
    expect(p.pendingMinor, 800);
    expect(records.last.text('effect'), 'cash');
  });
  test('zero recurring income and missing essential classifications are not healthy ratios', () {
    final report = calculate();
    expect(metric(report, 'debtPressure'), isNull);
    expect(metric(report, 'emergencyCoverage'), isNull);
  });
  test('emergency coverage uses complete months and category classification', () {
    final records = [
      ...baseRecords(),
      record('food', 'classification', {'categoryId': 'food', 'essential': 'yes'}),
      record('reserve', 'reserve', {
        'accountId': 'bank',
        'currency': 'COP',
        'purpose': 'emergency',
        'amountMinor': 900,
      }),
    ];
    final report = calculate(
      operations: [
        for (final month in ['2026-07', '2026-08', '2026-09'])
          op(month, OperationType.expense, 300, month: month, categoryId: 'food'),
      ],
      records: records,
    );
    expect(metric(report, 'emergencyCoverage'), 3);
    expect(metric(report, 'emergencyTarget'), 900);
  });
  test('linked assets never duplicate an existing account', () {
    final report = calculate(
      records: [
        ...baseRecords(),
        record('linked', 'asset', {
          'accountId': 'bank',
          'currency': 'COP',
          'amountMinor': 1000,
          'ownershipPercent': 100,
        }),
        record('house', 'asset', {
          'currency': 'COP',
          'amountMinor': 100000,
          'ownershipPercent': 50,
          'obligation': 'no',
        }),
      ],
    );
    expect(metric(report, 'recordedWealth'), 31000);
  });
  test('goal resources come only from reserves and contributions assume no returns', () {
    final records = [
      ...baseRecords(),
      record('goal', 'goal', {
        'name': 'Trip',
        'currency': 'COP',
        'amountMinor': 1500,
        'dueDate': '2026-12-31',
      }),
      record('reserve', 'reserve', {
        'accountId': 'bank',
        'currency': 'COP',
        'purpose': 'goal',
        'goalId': 'goal',
        'amountMinor': 300,
      }),
    ];
    final report = calculate(records: records);
    expect(metric(report, 'goalProgress'), 20);
    expect(metric(report, 'requiredContribution'), 400);
    expect(metric(report, 'freeMoney'), 700);
  });
  test('missing coverage need does not mean zero gap; expired coverage contributes zero', () {
    final report = calculate(
      records: [
        ...baseRecords(),
        record('coverage', 'coverage', {
          'name': 'Life',
          'currency': 'COP',
          'amountMinor': 5000,
          'dueDate': '2026-10-01',
        }),
      ],
    );
    expect(metric(report, 'coverageGap'), isNull);
    expect(report.findings.any((f) => f.key == 'coverageExpired'), isTrue);
  });
  test('refunds and reversal rows offset recognized consumption', () {
    final report = calculate(
      operations: [
        op('purchase', OperationType.expense, 1000),
        op('refund', OperationType.expenseRefund, 200),
        op('reversal', OperationType.expense, 1000, direction: -1, reversalOf: 'purchase'),
      ],
    );
    expect(metric(report, 'result'), 200);
  });
  test('calendar horizon is exclusive and ends correctly across year boundaries', () {
    final report = calculate(
      plans: [
        plan(
          'at-end',
          100,
          date: DateTime(2027, 1, 27),
          kind: PlanningEntryKind.debt,
          accountId: 'bank',
        ),
      ],
    );
    expect(report.endExclusive, DateTime(2027, 1, 27));
    expect(report.projection, isEmpty);
  });
  test('one account can lack cash even if currency aggregate stays positive', () {
    final records = [
      ...baseRecords(),
      record('other', 'account', {'accountId': 'other', 'availability': 'immediate'}),
    ];
    final report = calculate(
      accounts: [
        bank,
        const FinanceAccount(id: 'other', name: 'Other', type: 'bank', currentBalanceMinor: 5000),
      ],
      plans: [plan('debt:loan:2026-11', 1500, kind: PlanningEntryKind.debt, accountId: 'bank')],
      records: records,
    );
    expect(metric(report, 'minimumCashTotal'), 4500);
    expect(report.findings.any((f) => f.key == 'cashShortfall' && f.reference == 'bank'), isTrue);
  });
  test('reserve assigned through a provision releases only for its linked payment', () {
    final records = [
      ...baseRecords(),
      record('provision', 'goal', {
        'name': 'Tax',
        'kind': 'tax',
        'currency': 'COP',
        'amountMinor': 600,
        'dueDate': '2026-11-01',
        'entryId': 'debt:loan:2026-11',
      }),
      record('reserved', 'reserve', {
        'accountId': 'bank',
        'currency': 'COP',
        'purpose': 'goal',
        'goalId': 'provision',
        'amountMinor': 600,
      }),
    ];
    final report = calculate(
      records: records,
      plans: [plan('debt:loan:2026-11', 600, kind: PlanningEntryKind.debt, accountId: 'bank')],
    );
    expect(report.projection.single.freeMinor, 400);
    expect(metric(report, 'minimumFreeTotal'), 400);
  });
  test('emergency expense baseline does not depend on classifying income', () {
    final records = [
      ...baseRecords(),
      record('food', 'classification', {'categoryId': 'food', 'essential': 'yes'}),
      record('reserve', 'reserve', {
        'accountId': 'bank',
        'currency': 'COP',
        'purpose': 'emergency',
        'amountMinor': 900,
      }),
    ];
    final report = calculate(
      operations: [
        for (final month in ['2026-07', '2026-08', '2026-09'])
          op(month, OperationType.expense, 300, month: month, categoryId: 'food'),
        op('salary', OperationType.income, 500, month: '2026-09', categoryId: 'salary'),
      ],
      records: records,
    );
    expect(metric(report, 'emergencyCoverage'), 3);
    expect(metric(report, 'debtPressure'), isNull);
  });
  test('older unallocated payments limit confidence in recorded wealth', () {
    final input = DiagnosticInput(
      today: today,
      accounts: const [bank, debt],
      operations: const [],
      entries: const [],
      plan: const [],
      records: baseRecords(),
      allocationIncomplete: true,
    );
    final report = const DiagnosticEngine().calculate(input);
    expect(
      report.metrics.firstWhere((m) => m.key == 'recordedWealth').missing,
      contains('allocationIncomplete'),
    );
  });
  test('external earmarked retirement assets fund a goal without creating free cash', () {
    final report = calculate(
      records: [
        ...baseRecords(),
        record('retirement', 'goal', {
          'name': 'Retirement',
          'kind': 'retirement',
          'currency': 'COP',
          'amountMinor': 100000,
          'dueDate': '2046-10-29',
        }),
        record('fund', 'asset', {
          'name': 'Fund',
          'currency': 'COP',
          'amountMinor': 50000,
          'ownershipPercent': 100,
          'goalId': 'retirement',
          'assetClass': 'fixedIncome',
          'obligation': 'no',
        }),
      ],
    );
    expect(metric(report, 'goalProgress'), 50);
    expect(metric(report, 'freeMoney'), 1000);
  });

  test('archived accounts retain their historical financial activity', () {
    const archived = FinanceAccount(id: 'closed', name: 'Closed', type: 'bank', status: 'archived');
    final report = calculate(
      accounts: [bank, archived],
      operations: [op('old-expense', OperationType.expense, 300, accountId: 'closed')],
      entries: [entry('old-expense', -300, accountId: 'closed')],
    );
    expect(metric(report, 'result'), -300);
    expect(metric(report, 'cashFlow'), -300);
    expect(metric(report, 'freeMoney'), 1000);
  });
  test('actual payment consumes its reserve without subtracting money a second time', () {
    final report = calculate(
      records: [
        ...baseRecords(),
        record('reserved', 'reserve', {
          'accountId': 'bank',
          'currency': 'COP',
          'purpose': 'obligation',
          'entryId': 'debt:loan:2026-11',
          'amountMinor': 600,
        }),
      ],
      plans: [
        plan(
          'debt:loan:2026-11',
          600,
          recorded: 600,
          kind: PlanningEntryKind.debt,
          accountId: 'bank',
        ),
      ],
    );
    expect(metric(report, 'freeMoney'), 1000);
    expect(report.projection, isEmpty);
  });
  test('reserve created after a partial payment starts from its server baseline', () {
    final reserve = DiagnosticRecord('reserved', 'reserve', {
      'accountId': 'bank',
      'currency': 'COP',
      'purpose': 'obligation',
      'entryId': 'debt:loan:2026-11',
      'amountMinor': 600,
    }, paymentBaselineMinor: 200);
    final report = calculate(
      records: [...baseRecords(), reserve],
      plans: [
        plan(
          'debt:loan:2026-11',
          800,
          recorded: 300,
          kind: PlanningEntryKind.debt,
          accountId: 'bank',
        ),
      ],
    );
    expect(metric(report, 'freeMoney'), 500);
  });
  test('paid provision stays fulfilled after consuming its reserved funding', () {
    final report = calculate(
      records: [
        ...baseRecords(),
        record('tax', 'goal', {
          'name': 'Tax',
          'kind': 'tax',
          'currency': 'COP',
          'amountMinor': 600,
          'dueDate': '2026-11-01',
          'entryId': 'debt:loan:2026-11',
        }),
        record('reserved', 'reserve', {
          'accountId': 'bank',
          'currency': 'COP',
          'purpose': 'goal',
          'goalId': 'tax',
          'amountMinor': 600,
        }),
      ],
      plans: [
        plan(
          'debt:loan:2026-11',
          600,
          recorded: 600,
          kind: PlanningEntryKind.debt,
          accountId: 'bank',
        ),
      ],
    );
    expect(metric(report, 'goalProgress'), 100);
    expect(metric(report, 'requiredContribution'), 0);
    expect(metric(report, 'freeMoney'), 1000);
  });
}
