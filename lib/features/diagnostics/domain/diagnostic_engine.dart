import 'dart:math' as math;

import '../../finance/domain/entities/finance_account.dart';
import '../../finance/domain/entities/financial_operation.dart';
import '../../finance/domain/entities/ledger_entry.dart';
import '../../finance/domain/entities/planning_agenda_entry.dart';
import 'diagnostic_record.dart';

enum DiagnosticSufficiency { sufficient, partial, notCalculable }

class DiagnosticMetric {
  const DiagnosticMetric(
    this.key,
    this.currency,
    this.value, {
    this.unit = 'money',
    this.sources = const [],
    this.missing = const [],
    this.subject = '',
  });
  final String key, currency, unit, subject;
  DateTime periodStart(DiagnosticReport report) => switch (key) {
    'result' ||
    'cashFlow' ||
    'debtPressure' ||
    'grossDti' => DateTime(report.asOf.year, report.asOf.month),
    'emergencyCoverage' ||
    'emergencyTarget' ||
    'averageCashFlow' ||
    'recurringSurplus' ||
    'fixedExpenseShare' => report.historyStart,
    _ => report.asOf,
  };
  DateTime periodEnd(DiagnosticReport report) => switch (key) {
    'minimumCash' || 'minimumCashTotal' || 'minimumFreeTotal' => DateTime(
      report.endExclusive.year,
      report.endExclusive.month,
      report.endExclusive.day - 1,
    ),
    'emergencyCoverage' ||
    'emergencyTarget' ||
    'averageCashFlow' ||
    'recurringSurplus' ||
    'fixedExpenseShare' => DateTime(report.asOf.year, report.asOf.month, 0),
    _ => report.asOf,
  };
  final num? value;
  final List<String> sources, missing;
  DiagnosticSufficiency get sufficiency => value == null
      ? DiagnosticSufficiency.notCalculable
      : missing.isEmpty
      ? DiagnosticSufficiency.sufficient
      : DiagnosticSufficiency.partial;
}

class DiagnosticFinding {
  const DiagnosticFinding(
    this.key,
    this.priority, {
    this.currency = '',
    this.reference = '',
    this.amountMinor,
    this.date,
  });
  final String key, currency, reference;
  final int priority;
  final int? amountMinor;
  final DateTime? date;
}

class ProjectionPoint {
  const ProjectionPoint(
    this.reference,
    this.accountId,
    this.currency,
    this.date,
    this.deltaMinor,
    this.balanceMinor,
    this.freeMinor,
  );
  final String reference, accountId, currency;
  final DateTime date;
  final int deltaMinor, balanceMinor, freeMinor;
}

class DiagnosticInput {
  const DiagnosticInput({
    required this.today,
    required this.accounts,
    required this.operations,
    required this.entries,
    required this.plan,
    required this.records,
    this.allocationIncomplete = false,
    this.cached = false,
    this.pending = false,
    this.historyMonths = 3,
    this.incomeReductionPercent = 0,
    this.expenseIncreasePercent = 0,
  });

  /// Calendar date already converted to the user's configured time zone.
  final DateTime today;
  final List<FinanceAccount> accounts;
  final List<FinancialOperation> operations;
  final List<LedgerEntry> entries;
  final List<PlanningAgendaEntry> plan;
  final List<DiagnosticRecord> records;
  final bool cached, pending, allocationIncomplete;
  final int historyMonths;
  final int incomeReductionPercent, expenseIncreasePercent;
}

class DiagnosticReport {
  const DiagnosticReport({
    required this.asOf,
    required this.endExclusive,
    required this.historyStart,
    required this.metrics,
    required this.findings,
    required this.projection,
    required this.missing,
    required this.confirmedMonths,
  });
  static const methodologyVersion = 1;
  final DateTime asOf, endExclusive, historyStart;
  final List<DiagnosticMetric> metrics;
  final List<DiagnosticFinding> findings;
  final List<ProjectionPoint> projection;
  final List<String> missing, confirmedMonths;
}

String diagnosticMonth(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
String diagnosticDate(DateTime date) =>
    '${diagnosticMonth(date)}-${date.day.toString().padLeft(2, '0')}';

class DiagnosticEngine {
  const DiagnosticEngine();
  DiagnosticReport calculate(DiagnosticInput input) {
    final today = DateTime(input.today.year, input.today.month, input.today.day);
    final end = DateTime(today.year, today.month, today.day + 90);
    final context =
        input.records.where((r) => r.kind == 'context').firstOrNull ??
        DiagnosticRecord('context', 'context', {});
    final missing = <String>[
      if (!context.yes('accountsComplete')) 'accountsIncomplete',
      if (!context.yes('debtsComplete')) 'debtsIncomplete',
      if (input.cached) 'cached',
      if (input.pending) 'pending',
      if (input.allocationIncomplete ||
          input.operations.any(
            (o) =>
                o.type == OperationType.unallocatedDebtPayment &&
                o.projectionDirection > 0 &&
                o.allocationStatus != 'allocated' &&
                !input.operations.any((r) => r.reversalOf == o.id),
          ))
        'allocationIncomplete',
    ];
    final months = <String>[];
    for (var i = 1; i <= input.historyMonths.clamp(1, 12); i++) {
      final key = diagnosticMonth(DateTime(today.year, today.month - i));
      if (!context.months('completeMonths').contains(key)) break;
      months.add(key);
    }
    final accountMetadata = {
      for (final r in input.records.where((r) => r.kind == 'account')) r.text('accountId'): r,
    };
    final scopeAccounts = input.accounts
        .where((a) => !(accountMetadata[a.id]?.yes('excluded') ?? false))
        .toList();
    final accounts = scopeAccounts.where((a) => a.status == 'active').toList();
    final ids = scopeAccounts.map((a) => a.id).toSet();
    final activeIds = accounts.map((a) => a.id).toSet();
    bool freshBalance(String date) {
      final verified = DateTime.tryParse(date);
      return verified != null &&
          !verified.isAfter(today) &&
          today.difference(verified).inDays <= 30;
    }

    if (accounts.any(
      (a) => !freshBalance(
        accountMetadata[a.id]?.text('verifiedOn').isNotEmpty == true
            ? accountMetadata[a.id]!.text('verifiedOn')
            : context.text('verifiedOn'),
      ),
    )) {
      missing.add('staleBalances');
    }
    if (input.records.any(
      (r) =>
          r.kind == 'reserve' &&
          ids.contains(r.text('accountId')) &&
          !activeIds.contains(r.text('accountId')),
    )) {
      missing.add('reserveAccountUnavailable');
    }
    final historicalMissing = <String>[...missing, if (months.length < 3) 'historyIncomplete'];
    final accountMap = {for (final a in accounts) a.id: a};
    bool inScope(FinancialOperation o) =>
        [o.accountId, o.sourceAccountId, o.destinationAccountId, o.debtAccountId].any(ids.contains);
    final operations = input.operations
        .where((o) => o.status == OperationStatus.confirmed && inScope(o))
        .toList();
    final operationMap = {for (final o in operations) o.id: o};
    final current = operations.where((o) => o.monthKey == diagnosticMonth(today)).toList();
    final history = operations.where((o) => months.contains(o.monthKey)).toList();
    final reserves = input.records
        .where((r) => r.kind == 'reserve' && activeIds.contains(r.text('accountId')))
        .map((reserve) {
          final linkedGoal = input.records
              .where((r) => r.kind == 'goal' && r.id == reserve.text('goalId'))
              .firstOrNull;
          final entryId = reserve.text('entryId').isNotEmpty
              ? reserve.text('entryId')
              : linkedGoal?.text('entryId');
          final payment = input.plan.where((p) => p.id == entryId).firstOrNull;
          final consumed = math.max(
            0,
            (payment?.recordedMinor ?? 0) - reserve.paymentBaselineMinor,
          );
          return DiagnosticRecord(reserve.id, reserve.kind, {
            ...reserve.values,
            'amountMinor': math.max(0, (reserve.number('amountMinor') ?? 0) - consumed),
          }, paymentBaselineMinor: reserve.paymentBaselineMinor);
        })
        .toList();
    final metrics = <DiagnosticMetric>[];
    final findings = <DiagnosticFinding>[];
    final projection = <ProjectionPoint>[];
    final currencies = {
      ...scopeAccounts.map((a) => a.currency),
      ...input.records
          .where((r) => ['asset', 'goal', 'coverage'].contains(r.kind))
          .map((r) => r.text('currency')),
    }.where((s) => s.isNotEmpty).toList()..sort();
    DiagnosticRecord? classification(FinancialOperation operation) {
      final candidates = input.records.where(
        (r) => r.kind == 'classification' && r.text('categoryId') == operation.categoryId,
      );
      return candidates
              .where(
                (r) =>
                    r.text('itemId').isNotEmpty &&
                    r.text('itemId') == operation.budgetItemId &&
                    r.text('budgetId') == operation.budgetId,
              )
              .firstOrNull ??
          candidates.where((r) => r.text('itemId').isEmpty).firstOrNull;
    }

    for (final currency in currencies) {
      final own = accounts.where((a) => a.currency == currency).toList();
      final monetary = scopeAccounts.where((a) => a.currency == currency && !a.isDebt).toList();
      final liquid = monetary
          .where(
            (a) =>
                a.status == 'active' && accountMetadata[a.id]?.text('availability') == 'immediate',
          )
          .toList();
      final unknownAvailability = monetary.any(
        (a) =>
            a.status == 'active' &&
            !['immediate', 'restricted'].contains(accountMetadata[a.id]?.text('availability')),
      );
      final currentOps = current.where((o) => o.currency == currency).toList();
      final result = currentOps.fold<int>(
        0,
        (s, o) => s + o.recognizedIncomeMinor - o.recognizedExpenseMinor,
      );
      final currentEntries = input.entries
          .where(
            (e) =>
                e.currency == currency &&
                monetary.any((a) => a.id == e.accountId) &&
                operationMap[e.operationId]?.monthKey == diagnosticMonth(today),
          )
          .toList();
      // Adjustments reconcile balances but are not operating cash flow.
      final cashEntries = currentEntries
          .where(
            (e) =>
                operationMap[e.operationId]?.balanceDeltaMinor == null &&
                operationMap[e.operationId]?.type != OperationType.debtAdjustment,
          )
          .toList();
      final cash = cashEntries.fold<int>(0, (s, e) => s + e.deltaMinor);
      final reserveSum = reserves
          .where(
            (r) => r.text('currency') == currency && liquid.any((a) => a.id == r.text('accountId')),
          )
          .fold<int>(0, (s, r) => s + (r.number('amountMinor') ?? 0));
      final liquidSum = liquid.fold<int>(0, (s, a) => s + a.currentBalanceMinor);
      final liquidityMissing = [...missing, if (unknownAvailability) 'availabilityUnknown'];
      metrics.addAll([
        DiagnosticMetric(
          'result',
          currency,
          result,
          sources: currentOps.map((o) => o.id).toList(),
          missing: missing,
        ),
        DiagnosticMetric(
          'cashFlow',
          currency,
          cash,
          sources: cashEntries.map((e) => e.operationId).toSet().toList(),
          missing: missing,
        ),
        DiagnosticMetric(
          'freeMoney',
          currency,
          liquid.isEmpty && unknownAvailability ? null : liquidSum - reserveSum,
          sources: [...liquid.map((a) => a.id), ...reserves.map((r) => r.id)],
          missing: liquidityMissing,
        ),
      ]);
      final hist = history.where((o) => o.currency == currency).toList();
      final expenseUnknown = hist.any(
        (o) =>
            o.recognizedExpenseMinor != 0 &&
            !['yes', 'no'].contains(classification(o)?.text('essential')),
      );
      final incomeUnknown = hist.any(
        (o) =>
            o.recognizedIncomeMinor != 0 &&
            !['yes', 'no'].contains(classification(o)?.text('recurring')),
      );
      final essentials = hist
          .where((o) => classification(o)?.yes('essential') ?? false)
          .fold<int>(0, (s, o) => s + o.recognizedExpenseMinor);
      final income = hist
          .where((o) => classification(o)?.yes('recurring') ?? false)
          .fold<int>(0, (s, o) => s + o.recognizedIncomeMinor);
      final averageEssential = months.isEmpty ? null : math.max(0, essentials) / months.length;
      final averageIncome = months.isEmpty ? null : income / months.length;
      final expenseQuality = [...historicalMissing, if (expenseUnknown) 'classificationIncomplete'];
      final incomeQuality = [...historicalMissing, if (incomeUnknown) 'classificationIncomplete'];
      final allExpense = hist.fold<int>(
        0,
        (sum, operation) => sum + operation.recognizedExpenseMinor,
      );
      final fixedExpense = hist
          .where((operation) => classification(operation)?.yes('fixed') ?? false)
          .fold<int>(0, (sum, operation) => sum + operation.recognizedExpenseMinor);
      final fixedUnknown = hist.any(
        (operation) =>
            operation.recognizedExpenseMinor != 0 &&
            !['yes', 'no'].contains(classification(operation)?.text('fixed')),
      );
      metrics
        ..add(
          DiagnosticMetric(
            'recurringSurplus',
            currency,
            averageIncome == null || incomeUnknown
                ? null
                : averageIncome - (allExpense / months.length),
            missing: incomeQuality,
            sources: hist.map((o) => o.id).toList(),
          ),
        )
        ..add(
          DiagnosticMetric(
            'fixedExpenseShare',
            currency,
            allExpense <= 0 || fixedUnknown ? null : fixedExpense / allExpense * 100,
            unit: 'percent',
            missing: [...historicalMissing, if (fixedUnknown) 'classificationIncomplete'],
            sources: hist.map((o) => o.id).toList(),
          ),
        );
      final emergency = reserves
          .where(
            (r) =>
                r.text('currency') == currency &&
                r.text('purpose') == 'emergency' &&
                liquid.any((a) => a.id == r.text('accountId')),
          )
          .fold<int>(0, (s, r) => s + (r.number('amountMinor') ?? 0));
      final emergencyCoverage = averageEssential != null && averageEssential > 0 && !expenseUnknown
          ? emergency / averageEssential
          : null;
      metrics.add(
        DiagnosticMetric(
          'emergencyCoverage',
          currency,
          emergencyCoverage,
          unit: 'months',
          sources: hist.map((o) => o.id).toList(),
          missing: [
            ...expenseQuality,
            if (averageEssential == null || averageEssential == 0) 'essentialBaselineMissing',
          ],
        ),
      );
      final emergencyTarget = context.number('emergencyMonths') ?? 3;
      metrics.add(
        DiagnosticMetric(
          'emergencyTarget',
          currency,
          averageEssential == null || expenseUnknown ? null : averageEssential * emergencyTarget,
          missing: expenseQuality,
          sources: [
            'context',
            ...hist.where((o) => o.recognizedExpenseMinor != 0).map((o) => o.id),
          ],
        ),
      );
      final debtPlans = input.plan
          .where(
            (p) =>
                p.currency == currency &&
                p.kind == PlanningEntryKind.debt &&
                ids.contains(p.debtAccountId) &&
                p.monthKey == diagnosticMonth(today),
          )
          .toList();
      final contractual = input.records
          .where(
            (r) =>
                r.kind == 'debt' &&
                ids.contains(r.text('accountId')) &&
                r.text('currency') == currency,
          )
          .toList();
      var monthlyDebt = 0;
      var debtMissing = false;
      for (final a in own.where((a) => a.debtMinor > 0)) {
        final terms = contractual.where((r) => r.text('accountId') == a.id).firstOrNull;
        final amount = a.isCreditCard
            ? (terms?.text('statementMonth') == diagnosticMonth(today)
                  ? terms?.number('minimumPaymentMinor')
                  : null)
            : terms?.number('installmentMinor');
        final planned = debtPlans
            .where((p) => p.debtAccountId == a.id)
            .fold<int>(0, (s, p) => s + p.plannedMinor);
        monthlyDebt += amount ?? planned;
        final termsDate = terms == null ? null : DateTime.tryParse(terms.text('referenceDate'));
        if (amount == null ||
            termsDate == null ||
            termsDate.isAfter(today) ||
            today.difference(termsDate).inDays > 90) {
          debtMissing = true;
        }
        if (a.isCreditCard) {
          metrics.add(
            DiagnosticMetric(
              'creditUtilization',
              currency,
              a.limitMinor == null || a.limitMinor == 0 ? null : a.debtMinor / a.limitMinor! * 100,
              unit: 'percent',
              subject: a.name,
              sources: [a.id],
              missing: [
                ...missing,
                if (a.limitMinor == null || a.limitMinor == 0) 'creditLimitMissing',
              ],
            ),
          );
        }
        metrics
          ..add(
            DiagnosticMetric(
              'debtPrincipal',
              currency,
              a.principalMinor,
              subject: a.name,
              sources: [a.id],
              missing: missing,
            ),
          )
          ..add(
            DiagnosticMetric(
              'debtCharges',
              currency,
              a.chargesMinor,
              subject: a.name,
              sources: [a.id],
              missing: missing,
            ),
          );
      }
      final debtQuality = [...incomeQuality, if (debtMissing) 'debtTermsMissing'];
      metrics.add(
        DiagnosticMetric(
          'debtPressure',
          currency,
          averageIncome == null || averageIncome <= 0 || incomeUnknown
              ? null
              : monthlyDebt / averageIncome * 100,
          unit: 'percent',
          sources: [
            ...debtPlans.map((p) => p.id),
            ...contractual.map((r) => r.id),
            ...hist.where((o) => o.recognizedIncomeMinor != 0).map((o) => o.id),
          ],
          missing: [
            ...debtQuality,
            if (averageIncome == null || averageIncome <= 0) 'recurringIncomeMissing',
          ],
        ),
      );
      if (context.text('currency') == currency && (context.number('grossIncomeMinor') ?? 0) > 0) {
        metrics.add(
          DiagnosticMetric(
            'grossDti',
            currency,
            monthlyDebt / context.number('grossIncomeMinor')! * 100,
            unit: 'percent',
            missing: [...missing, if (debtMissing) 'debtTermsMissing'],
            sources: ['context', ...contractual.map((r) => r.id)],
          ),
        );
      }
      final historyCash = input.entries
          .where(
            (e) =>
                monetary.any((a) => a.id == e.accountId) &&
                months.contains(operationMap[e.operationId]?.monthKey) &&
                operationMap[e.operationId]?.balanceDeltaMinor == null &&
                operationMap[e.operationId]?.type != OperationType.debtAdjustment,
          )
          .fold<int>(0, (s, e) => s + e.deltaMinor);
      metrics.add(
        DiagnosticMetric(
          'averageCashFlow',
          currency,
          months.isEmpty ? null : historyCash / months.length,
          missing: historicalMissing,
          sources: hist.map((o) => o.id).toList(),
        ),
      );
      if (result > 0 && cash < 0) {
        findings.add(
          DiagnosticFinding('positiveResultNegativeCash', 1, currency: currency, amountMinor: cash),
        );
      }
      if (reserveSum > liquidSum) {
        findings.add(
          DiagnosticFinding(
            'reservesExceedBalance',
            0,
            currency: currency,
            amountMinor: liquidSum - reserveSum,
          ),
        );
      }
      for (final goal in input.records.where(
        (r) => r.kind == 'goal' && r.text('currency') == currency,
      )) {
        final target = goal.number('amountMinor') ?? 0;
        var allocated = reserves
            .where((r) => r.text('goalId') == goal.id)
            .fold<int>(0, (s, r) => s + (r.number('amountMinor') ?? 0));
        allocated += input.records
            .where(
              (r) =>
                  r.kind == 'asset' &&
                  r.text('currency') == goal.text('currency') &&
                  r.text('goalId') == goal.id &&
                  r.text('accountId').isEmpty &&
                  !r.yes('obligation'),
            )
            .fold<int>(
              0,
              (sum, r) =>
                  sum +
                  ((r.number('amountMinor') ?? 0) * (r.number('ownershipPercent') ?? 0) / 100)
                      .round(),
            );
        final fulfilled =
            input.plan.where((p) => p.id == goal.text('entryId')).firstOrNull?.recordedMinor ?? 0;
        final completedResources = allocated + fulfilled;
        final remaining = math.max(0, target - completedResources);
        final due = DateTime.tryParse(goal.text('dueDate'));
        final availableMonths = due == null || due.isBefore(today)
            ? 0
            : (due.year - today.year) * 12 + due.month - today.month + 1;
        final contribution = availableMonths > 0 ? (remaining / availableMonths).ceil() : remaining;
        metrics
          ..add(
            DiagnosticMetric(
              'goalProgress',
              currency,
              target > 0 ? completedResources / target * 100 : null,
              unit: 'percent',
              subject: goal.text('name'),
              sources: [
                goal.id,
                ...reserves.where((r) => r.text('goalId') == goal.id).map((r) => r.id),
                ...input.records
                    .where((r) => r.kind == 'asset' && r.text('goalId') == goal.id)
                    .map((r) => r.id),
              ],
              missing: liquidityMissing,
            ),
          )
          ..add(
            DiagnosticMetric(
              'requiredContribution',
              currency,
              contribution,
              subject: goal.text('name'),
              sources: [goal.id],
              missing: [...liquidityMissing, if (availableMonths <= 0) 'goalOverdue'],
            ),
          );
        if (goal.number('monthlyContributionMinor') != null &&
            goal.number('monthlyContributionMinor')! < contribution) {
          findings.add(
            DiagnosticFinding(
              'goalContributionGap',
              3,
              currency: currency,
              reference: goal.id,
              amountMinor: contribution - goal.number('monthlyContributionMinor')!,
            ),
          );
        }
      }
      var wealth = own.fold<int>(0, (s, a) => s + a.currentBalanceMinor);
      final assets = input.records
          .where((r) => r.kind == 'asset' && r.text('currency') == currency)
          .toList();
      final assetSources = [...own.map((a) => a.id)];
      for (final asset in assets) {
        if (asset.text('accountId').isNotEmpty) continue;
        final value =
            ((asset.number('amountMinor') ?? 0) * (asset.number('ownershipPercent') ?? 0) / 100)
                .round();
        wealth += asset.yes('obligation') ? -value : value;
        assetSources.add(asset.id);
      }
      metrics.add(
        DiagnosticMetric(
          'recordedWealth',
          currency,
          wealth,
          sources: assetSources,
          missing: [
            ...missing,
            'wealthInventoryUnconfirmed',
            if (assets.any(
              (a) =>
                  DateTime.tryParse(a.text('referenceDate')) == null ||
                  today.difference(DateTime.parse(a.text('referenceDate'))).inDays > 365,
            ))
              'staleValuation',
          ],
        ),
      );
      final investments = assets
          .where(
            (a) => ['equity', 'fixedIncome'].contains(a.text('assetClass')) && !a.yes('obligation'),
          )
          .toList();
      final invested = investments.fold<int>(
        0,
        (s, a) =>
            s +
            ((a.number('amountMinor') ?? 0) * (a.number('ownershipPercent') ?? 0) / 100).round(),
      );
      for (final asset in investments) {
        metrics.add(
          DiagnosticMetric(
            'investmentConcentration',
            currency,
            invested > 0
                ? (asset.number('amountMinor') ?? 0) *
                      (asset.number('ownershipPercent') ?? 0) /
                      invested
                : null,
            unit: 'percent',
            subject: asset.text('name'),
            sources: [asset.id],
            missing: ['investmentInventoryUnconfirmed'],
          ),
        );
      }
      for (final coverage in input.records.where(
        (r) => r.kind == 'coverage' && r.text('currency') == currency,
      )) {
        final need = coverage.number('needMinor');
        final expiry = DateTime.tryParse(coverage.text('dueDate'));
        metrics.add(
          DiagnosticMetric(
            'coverageGap',
            currency,
            need == null
                ? null
                : math.max(
                    0,
                    need -
                        (expiry != null && expiry.isBefore(today)
                            ? 0
                            : coverage.number('amountMinor') ?? 0),
                  ),
            subject: coverage.text('name'),
            sources: [coverage.id],
            missing: [if (need == null) 'coverageNeedMissing'],
          ),
        );
        if (expiry != null && expiry.isBefore(today)) {
          findings.add(
            DiagnosticFinding(
              'coverageExpired',
              2,
              reference: coverage.id,
              currency: currency,
              date: expiry,
            ),
          );
        }
      }
    }
    final balances = {
      for (final a in accounts.where(
        (a) => !a.isDebt && accountMetadata[a.id]?.text('availability') == 'immediate',
      ))
        a.id: a.currentBalanceMinor,
    };
    final held = {
      for (final id in balances.keys)
        id: reserves
            .where((r) => r.text('accountId') == id)
            .fold<int>(0, (s, r) => s + (r.number('amountMinor') ?? 0)),
    };
    final minimum = Map<String, int>.from(balances);
    for (final a in balances.keys) {
      if (balances[a]! < 0) {
        findings.add(
          DiagnosticFinding(
            'cashShortfall',
            0,
            currency: accountMap[a]!.currency,
            reference: a,
            amountMinor: balances[a],
            date: today,
          ),
        );
      }
    }
    final plan = [...input.plan]
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        if (c != 0) return c;
        final byFlow = (a.kind == PlanningEntryKind.income ? 1 : 0).compareTo(
          b.kind == PlanningEntryKind.income ? 1 : 0,
        );
        return byFlow != 0 ? byFlow : a.id.compareTo(b.id);
      });
    final projectionMissing = <String>{...missing};
    for (final p in plan) {
      if (p.monthKey.compareTo(diagnosticMonth(today)) < 0) continue;
      if (p.pendingMinor <= 0 || !p.date.isBefore(end)) continue;
      if (p.debtAccountId != null && !ids.contains(p.debtAccountId)) continue;
      if (p.date.isBefore(today)) {
        findings.add(
          DiagnosticFinding(
            'unconfirmedPastPayment',
            1,
            currency: p.currency,
            reference: p.id,
            date: p.date,
            amountMinor: p.pendingMinor,
          ),
        );
        projectionMissing.add('pastPaymentsUnconfirmed');
        continue;
      }
      final mapping = input.records
          .where((r) => r.kind == 'plan' && r.text('entryId') == p.id)
          .firstOrNull;
      final effect = mapping?.text('effect') ?? (p.kind == PlanningEntryKind.debt ? 'cash' : '');
      if (effect == 'none' || effect == 'card') continue;
      final accountId = mapping?.text('accountId') ?? p.bankAccountId;
      if (effect.isEmpty ||
          !balances.containsKey(accountId) ||
          accountMap[accountId]?.currency != p.currency) {
        projectionMissing.add('planAccountMissing');
        continue;
      }
      final incoming = p.kind == PlanningEntryKind.income;
      final percent = incoming
          ? 100 - input.incomeReductionPercent.clamp(0, 100)
          : p.kind == PlanningEntryKind.expense
          ? 100 + input.expenseIncreasePercent.clamp(0, 100)
          : 100;
      final amount = incoming
          ? p.pendingMinor * percent ~/ 100
          : (p.pendingMinor * percent / 100).ceil();
      final delta = incoming ? amount : -amount;
      balances[accountId!] = balances[accountId]! + delta;
      if (!incoming) {
        final reservedForPayment = reserves
            .where(
              (r) =>
                  (r.text('entryId') == p.id ||
                      input.records.any(
                        (g) =>
                            g.kind == 'goal' &&
                            g.id == r.text('goalId') &&
                            g.text('entryId') == p.id,
                      )) &&
                  r.text('accountId') == accountId,
            )
            .fold<int>(0, (s, r) => s + (r.number('amountMinor') ?? 0));
        held[accountId] = math.max(0, held[accountId]! - math.min(reservedForPayment, amount));
      }
      final balance = balances[accountId]!;
      final free = balance - held[accountId]!;
      projection.add(ProjectionPoint(p.id, accountId, p.currency, p.date, delta, balance, free));
      if (balance < minimum[accountId]!) minimum[accountId] = balance;
      if (balance < 0 &&
          !findings.any((f) => f.key == 'cashShortfall' && f.reference == accountId)) {
        findings.add(
          DiagnosticFinding(
            'cashShortfall',
            0,
            currency: p.currency,
            reference: accountId,
            amountMinor: balance,
            date: p.date,
          ),
        );
      }
      if (free < 0 &&
          balance >= 0 &&
          !findings.any((f) => f.key == 'reservedMoneyNeeded' && f.reference == accountId)) {
        findings.add(
          DiagnosticFinding(
            'reservedMoneyNeeded',
            1,
            currency: p.currency,
            reference: accountId,
            amountMinor: free,
            date: p.date,
          ),
        );
      }
    }
    final horizonMonths = <String>{};
    for (
      var date = today;
      date.isBefore(end);
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      horizonMonths.add(diagnosticMonth(date));
    }
    if (!context.months('confirmedPlanMonths').containsAll(horizonMonths)) {
      projectionMissing.add('planIncomplete');
    }
    for (final entry in minimum.entries) {
      metrics.add(
        DiagnosticMetric(
          'minimumCash',
          accountMap[entry.key]!.currency,
          entry.value,
          subject: accountMap[entry.key]!.name,
          sources: [
            entry.key,
            ...projection.where((p) => p.accountId == entry.key).map((p) => p.reference),
          ],
          missing: projectionMissing.toList(),
        ),
      );
    }
    for (final currency in currencies) {
      final liquidAccounts = accounts
          .where((a) => a.currency == currency && balances.containsKey(a.id))
          .toList();
      if (liquidAccounts.isEmpty) continue;
      var aggregate = liquidAccounts.fold<int>(0, (sum, a) => sum + a.currentBalanceMinor);
      var aggregateMinimum = aggregate;
      final freeByAccount = {
        for (final a in liquidAccounts)
          a.id:
              a.currentBalanceMinor -
              reserves
                  .where((r) => r.text('accountId') == a.id)
                  .fold<int>(0, (sum, r) => sum + (r.number('amountMinor') ?? 0)),
      };
      var freeMinimum = freeByAccount.values.fold<int>(0, (sum, value) => sum + value);
      for (final point in projection.where((p) => p.currency == currency)) {
        aggregate += point.deltaMinor;
        aggregateMinimum = math.min(aggregateMinimum, aggregate);
        freeByAccount[point.accountId] = point.freeMinor;
        freeMinimum = math.min(
          freeMinimum,
          freeByAccount.values.fold<int>(0, (sum, value) => sum + value),
        );
      }
      metrics
        ..add(
          DiagnosticMetric(
            'minimumCashTotal',
            currency,
            aggregateMinimum,
            sources: liquidAccounts.map((a) => a.id).toList(),
            missing: [
              ...projectionMissing,
              if (accounts.any(
                (a) =>
                    a.currency == currency &&
                    !a.isDebt &&
                    ![
                      'immediate',
                      'restricted',
                    ].contains(accountMetadata[a.id]?.text('availability')),
              ))
                'availabilityUnknown',
            ],
          ),
        )
        ..add(
          DiagnosticMetric(
            'minimumFreeTotal',
            currency,
            freeMinimum,
            sources: liquidAccounts.map((a) => a.id).toList(),
            missing: projectionMissing.toList(),
          ),
        );
    }
    for (final o in operations.where(
      (o) =>
          o.type == OperationType.unallocatedDebtPayment &&
          o.projectionDirection > 0 &&
          o.allocationStatus != 'allocated',
    )) {
      final reversed = operations.any((r) => r.reversalOf == o.id);
      if (!reversed) {
        findings.add(
          DiagnosticFinding('unallocatedPayment', 2, currency: o.currency, reference: o.id),
        );
      }
    }
    for (final o in current.where(
      (o) =>
          (o.type == OperationType.income || o.type == OperationType.expense) &&
          o.budgetItemId == null,
    )) {
      findings.add(
        DiagnosticFinding(
          'unlinkedMovement',
          2,
          currency: o.currency,
          reference: o.id,
          amountMinor: o.amountMinor,
        ),
      );
    }
    for (final key in {...missing, ...projectionMissing, ...metrics.expand((m) => m.missing)}) {
      findings.add(DiagnosticFinding(key, 2));
    }
    findings.sort((a, b) {
      final p = a.priority.compareTo(b.priority);
      return p != 0 ? p : (a.date ?? today).compareTo(b.date ?? today);
    });
    return DiagnosticReport(
      asOf: today,
      endExclusive: end,
      historyStart: DateTime(today.year, today.month - math.max(1, months.length)),
      metrics: List.unmodifiable(metrics),
      findings: List.unmodifiable(findings),
      projection: List.unmodifiable(projection),
      missing: List.unmodifiable({...missing, ...projectionMissing}),
      confirmedMonths: List.unmodifiable(months),
    );
  }
}
