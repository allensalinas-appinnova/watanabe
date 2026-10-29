enum DiagnosticFieldKind {
  text,
  integer,
  money,
  date,
  months,
  choice,
  account,
  category,
  goal,
  plan,
}

class DiagnosticField {
  const DiagnosticField(this.key, this.kind, {this.required = false, this.options = const []});
  final String key;
  final DiagnosticFieldKind kind;
  final bool required;
  final List<String> options;
}

const diagnosticSchemas = <String, List<DiagnosticField>>{
  'context': [
    DiagnosticField('dependents', DiagnosticFieldKind.integer),
    DiagnosticField(
      'incomeStability',
      DiagnosticFieldKind.choice,
      options: ['stable', 'variable', 'unknown'],
    ),
    DiagnosticField('sharedExpensePercent', DiagnosticFieldKind.integer),
    DiagnosticField(
      'accountsComplete',
      DiagnosticFieldKind.choice,
      options: ['yes', 'no', 'unknown'],
    ),
    DiagnosticField('debtsComplete', DiagnosticFieldKind.choice, options: ['yes', 'no', 'unknown']),
    DiagnosticField('verifiedOn', DiagnosticFieldKind.date),
    DiagnosticField('completeMonths', DiagnosticFieldKind.months),
    DiagnosticField('confirmedPlanMonths', DiagnosticFieldKind.months),
    DiagnosticField('emergencyMonths', DiagnosticFieldKind.integer),
    DiagnosticField('currency', DiagnosticFieldKind.text),
    DiagnosticField('grossIncomeMinor', DiagnosticFieldKind.money),
    DiagnosticField(
      'riskCapacity',
      DiagnosticFieldKind.choice,
      options: ['low', 'medium', 'high', 'unknown'],
    ),
    DiagnosticField(
      'riskTolerance',
      DiagnosticFieldKind.choice,
      options: ['low', 'medium', 'high', 'unknown'],
    ),
  ],
  'account': [
    DiagnosticField('accountId', DiagnosticFieldKind.account, required: true),
    DiagnosticField(
      'availability',
      DiagnosticFieldKind.choice,
      options: ['immediate', 'restricted', 'unknown'],
    ),
    DiagnosticField('excluded', DiagnosticFieldKind.choice, options: ['yes', 'no']),
    DiagnosticField('reason', DiagnosticFieldKind.text),
    DiagnosticField('verifiedOn', DiagnosticFieldKind.date),
  ],
  'classification': [
    DiagnosticField('categoryId', DiagnosticFieldKind.category, required: true),
    DiagnosticField('budgetId', DiagnosticFieldKind.text),
    DiagnosticField('itemId', DiagnosticFieldKind.text),
    DiagnosticField('essential', DiagnosticFieldKind.choice, options: ['yes', 'no', 'unknown']),
    DiagnosticField('fixed', DiagnosticFieldKind.choice, options: ['yes', 'no', 'unknown']),
    DiagnosticField('recurring', DiagnosticFieldKind.choice, options: ['yes', 'no', 'unknown']),
  ],
  'plan': [
    DiagnosticField('entryId', DiagnosticFieldKind.plan, required: true),
    DiagnosticField('accountId', DiagnosticFieldKind.account, required: true),
    DiagnosticField(
      'effect',
      DiagnosticFieldKind.choice,
      required: true,
      options: ['cash', 'card', 'none'],
    ),
  ],
  'reserve': [
    DiagnosticField('name', DiagnosticFieldKind.text, required: true),
    DiagnosticField('accountId', DiagnosticFieldKind.account, required: true),
    DiagnosticField('currency', DiagnosticFieldKind.text, required: true),
    DiagnosticField('amountMinor', DiagnosticFieldKind.money, required: true),
    DiagnosticField(
      'purpose',
      DiagnosticFieldKind.choice,
      required: true,
      options: ['emergency', 'obligation', 'goal'],
    ),
    DiagnosticField('goalId', DiagnosticFieldKind.goal),
    DiagnosticField('entryId', DiagnosticFieldKind.plan),
  ],
  'goal': [
    DiagnosticField('name', DiagnosticFieldKind.text, required: true),
    DiagnosticField(
      'kind',
      DiagnosticFieldKind.choice,
      required: true,
      options: ['goal', 'provision', 'retirement', 'tax'],
    ),
    DiagnosticField('currency', DiagnosticFieldKind.text, required: true),
    DiagnosticField('amountMinor', DiagnosticFieldKind.money, required: true),
    DiagnosticField('dueDate', DiagnosticFieldKind.date, required: true),
    DiagnosticField('entryId', DiagnosticFieldKind.plan),
    DiagnosticField('priority', DiagnosticFieldKind.integer),
    DiagnosticField('monthlyContributionMinor', DiagnosticFieldKind.money),
  ],
  'debt': [
    DiagnosticField('accountId', DiagnosticFieldKind.account, required: true),
    DiagnosticField('currency', DiagnosticFieldKind.text, required: true),
    DiagnosticField('referenceDate', DiagnosticFieldKind.date, required: true),
    DiagnosticField('rateBps', DiagnosticFieldKind.integer),
    DiagnosticField(
      'ratePeriod',
      DiagnosticFieldKind.choice,
      options: ['monthlyEffective', 'annualEffective'],
    ),
    DiagnosticField('rateMode', DiagnosticFieldKind.choice, options: ['fixed', 'variable']),
    DiagnosticField('remainingMonths', DiagnosticFieldKind.integer),
    DiagnosticField('dueDate', DiagnosticFieldKind.date),
    DiagnosticField('installmentMinor', DiagnosticFieldKind.money),
    DiagnosticField('statementMonth', DiagnosticFieldKind.months),
    DiagnosticField('minimumPaymentMinor', DiagnosticFieldKind.money),
    DiagnosticField('interestFreePaymentMinor', DiagnosticFieldKind.money),
    DiagnosticField('prepaymentTerms', DiagnosticFieldKind.text),
    DiagnosticField('prepaymentCostMinor', DiagnosticFieldKind.money),
  ],
  'asset': [
    DiagnosticField('goalId', DiagnosticFieldKind.goal),
    DiagnosticField('name', DiagnosticFieldKind.text, required: true),
    DiagnosticField('currency', DiagnosticFieldKind.text, required: true),
    DiagnosticField('amountMinor', DiagnosticFieldKind.money, required: true),
    DiagnosticField('referenceDate', DiagnosticFieldKind.date, required: true),
    DiagnosticField('ownershipPercent', DiagnosticFieldKind.integer, required: true),
    DiagnosticField(
      'availability',
      DiagnosticFieldKind.choice,
      required: true,
      options: ['immediate', 'restricted'],
    ),
    DiagnosticField(
      'assetClass',
      DiagnosticFieldKind.choice,
      required: true,
      options: ['property', 'vehicle', 'equity', 'fixedIncome', 'receivable', 'other'],
    ),
    DiagnosticField(
      'obligation',
      DiagnosticFieldKind.choice,
      required: true,
      options: ['yes', 'no'],
    ),
    DiagnosticField('accountId', DiagnosticFieldKind.account),
    DiagnosticField('dueDate', DiagnosticFieldKind.date),
  ],
  'coverage': [
    DiagnosticField('name', DiagnosticFieldKind.text, required: true),
    DiagnosticField('currency', DiagnosticFieldKind.text, required: true),
    DiagnosticField('amountMinor', DiagnosticFieldKind.money, required: true),
    DiagnosticField('deductibleMinor', DiagnosticFieldKind.money),
    DiagnosticField('needMinor', DiagnosticFieldKind.money),
    DiagnosticField('beneficiaries', DiagnosticFieldKind.text),
    DiagnosticField('dueDate', DiagnosticFieldKind.date, required: true),
  ],
};

/// Immutable, schema-constrained supplemental facts; never financial movements.
class DiagnosticRecord {
  DiagnosticRecord(this.id, this.kind, Map<String, Object> values, {this.paymentBaselineMinor = 0})
    : values = Map.unmodifiable(values);
  final String id;
  final String kind;
  final int paymentBaselineMinor;
  final Map<String, Object> values;
  String text(String key) => values[key] is String ? values[key] as String : '';
  int? number(String key) => (values[key] as num?)?.toInt();
  bool yes(String key) => text(key) == 'yes';
  Set<String> months(String key) =>
      text(key).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
}
