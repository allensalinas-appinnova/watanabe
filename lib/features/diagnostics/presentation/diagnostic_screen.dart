import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/async_value_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/diagnostic_engine.dart';
import '../domain/diagnostic_repository.dart';
import 'diagnostic_editor.dart';
import 'diagnostic_providers.dart';

class DiagnosticScreen extends ConsumerStatefulWidget {
  const DiagnosticScreen({super.key});
  @override
  ConsumerState<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends ConsumerState<DiagnosticScreen> {
  int _incomeReduction = 0, _expenseIncrease = 0, _history = 3;
  String? _owner;
  bool _hidden = true;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).diagnosticText;
    final uid = ref.watch(authSessionProvider).valueOrNull?.id;
    if (_owner != uid) {
      _owner = uid;
      _incomeReduction = 0;
      _expenseIncrease = 0;
      _history = 3;
      _hidden = true;
    }
    if (uid == null) {
      return Scaffold(body: Center(child: Text(AppLocalizations.of(context).sessionExpired)));
    }
    final state = ref.watch(diagnosticSnapshotProvider(uid));
    return Scaffold(
      appBar: AppBar(
        title: Text(t('title')),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context).coachToggleAmounts,
            icon: Icon(_hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('readError')),
              TextButton(
                onPressed: () => ref.invalidate(diagnosticSnapshotProvider(uid)),
                child: Text(t('retry')),
              ),
            ],
          ),
        ),
        data: (snapshot) => _body(context, uid, snapshot),
      ),
    );
  }

  Widget _body(BuildContext context, String uid, DiagnosticSnapshot snapshot) {
    final t = AppLocalizations.of(context).diagnosticText;
    final input = snapshot.input;
    final report = const DiagnosticEngine().calculate(
      DiagnosticInput(
        today: input.today,
        accounts: input.accounts,
        operations: input.operations,
        entries: input.entries,
        plan: input.plan,
        records: input.records,
        allocationIncomplete: input.allocationIncomplete,
        cached: input.cached,
        pending: input.pending,
        historyMonths: _history,
        incomeReductionPercent: _incomeReduction,
        expenseIncreasePercent: _expenseIncrease,
      ),
    );
    final locale = Localizations.localeOf(context).toString();
    String money(num amount, String currency) => _hidden
        ? '••••••'
        : CurrencyFormatter.formatMinor(amount.round(), currency, locale: locale);
    String reference(String id) {
      final account = input.accounts.where((a) => a.id == id).firstOrNull;
      if (account != null) return account.name;
      final record = input.records.where((r) => r.id == id).firstOrNull;
      if (record != null) return record.text('name').isEmpty ? t(record.kind) : record.text('name');
      final plan = input.plan.where((p) => p.id == id).firstOrNull;
      if (plan != null) return plan.title;
      final operation = input.operations.where((o) => o.id == id).firstOrNull;
      if (operation != null) {
        return operation.description.isNotEmpty
            ? operation.description
            : DateFormat.yMMMd(locale).format(operation.occurredAt);
      }
      return t('sources');
    }

    String formula(String key) => t(switch (key) {
      'result' => 'formulaResult',
      'cashFlow' || 'averageCashFlow' => 'formulaCash',
      'freeMoney' => 'formulaFree',
      'emergencyCoverage' || 'emergencyTarget' => 'formulaEmergency',
      'debtPressure' => 'formulaDebt',
      'grossDti' => 'formulaGross',
      'creditUtilization' => 'formulaCredit',
      'coverageGap' => 'formulaCoverage',
      'investmentConcentration' => 'formulaConcentration',
      'goalProgress' || 'requiredContribution' => 'formulaGoal',
      'recordedWealth' => 'formulaWealth',
      'minimumCash' || 'minimumCashTotal' || 'minimumFreeTotal' => 'formulaProjection',
      'recurringSurplus' => 'formulaSurplus',
      'fixedExpenseShare' => 'formulaFixed',
      _ => 'formulaOther',
    });
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t('intro')),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('diagnostic_setup'),
          icon: const Icon(Icons.edit_note),
          label: Text(t('configure')),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const DiagnosticSetupScreen())),
        ),
        Text(t('scope'), style: Theme.of(context).textTheme.bodySmall),
        for (final record in input.records.where((r) => r.kind == 'account' && r.yes('excluded')))
          Text('${reference(record.text('accountId'))}: ${record.text('reason')}'),
        const SizedBox(height: 16),
        Text(
          '${t('methodology')} ${DiagnosticReport.methodologyVersion} · ${DateFormat.yMMMd(locale).format(report.asOf)}',
        ),
        Text(t('assumptions')),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _history,
          decoration: InputDecoration(labelText: t('history')),
          items: [
            for (final n in [3, 12]) DropdownMenuItem(value: n, child: Text('$n')),
          ],
          onChanged: (n) => setState(() => _history = n!),
        ),
        Text(report.confirmedMonths.join(', ')),
        for (final key in report.missing) Text(t(key)),
        ExpansionTile(
          title: Text(t('scenario')),
          children: [
            Text('${t('incomeReduction')}: $_incomeReduction'),
            Slider(
              value: _incomeReduction.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              label: '$_incomeReduction%',
              onChanged: (v) => setState(() => _incomeReduction = v.round()),
            ),
            Text('${t('expenseIncrease')}: $_expenseIncrease'),
            Slider(
              value: _expenseIncrease.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              label: '$_expenseIncrease%',
              onChanged: (v) => setState(() => _expenseIncrease = v.round()),
            ),
          ],
        ),
        if (report.metrics.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text(t('empty'))),
        for (final metric in report.metrics)
          Card(
            child: ExpansionTile(
              title: Text(
                '${t(metric.key)}${metric.subject.isEmpty ? '' : ' · ${metric.subject}'}',
              ),
              subtitle: Text(
                '${metric.value == null
                    ? t('notCalculable')
                    : metric.unit == 'money'
                    ? money(metric.value!, metric.currency)
                    : _hidden
                    ? '••••••'
                    : '${NumberFormat.decimalPattern(locale).format(metric.value)}${metric.unit == 'percent' ? '%' : ''}'} · ${t(metric.sufficiency.name)}',
              ),
              childrenPadding: const EdgeInsets.all(16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${diagnosticDate(metric.periodStart(report))} → ${diagnosticDate(metric.periodEnd(report))}',
                ),
                Text(formula(metric.key)),
                Text('${t('sources')}: ${metric.sources.map(reference).join(', ')}'),
                for (final key in metric.missing) Text(t(key)),
              ],
            ),
          ),
        Text(t('findings'), style: Theme.of(context).textTheme.titleLarge),
        for (final finding in report.findings)
          Card(
            child: ListTile(
              leading: Icon(finding.priority == 0 ? Icons.warning_amber : Icons.info_outline),
              title: Text(t(finding.key)),
              subtitle: Text(
                [
                  if (finding.reference.isNotEmpty) reference(finding.reference),
                  if (finding.date != null) DateFormat.yMMMd(locale).format(finding.date!),
                  if (finding.amountMinor != null) money(finding.amountMinor!, finding.currency),
                ].join(' · '),
              ),
              trailing: finding.reference.isEmpty ? null : const Icon(Icons.chevron_right),
              onTap: () {
                if (finding.key == 'unlinkedMovement') {
                  showDiagnosticAssociation(context, ref, uid, snapshot, finding.reference);
                } else if (finding.key == 'unallocatedPayment') {
                  final operation = input.operations
                      .where((o) => o.id == finding.reference)
                      .firstOrNull;
                  if (operation?.debtAccountId != null) {
                    context.push('/accounts/${operation!.debtAccountId}/debt');
                  }
                } else if (finding.reference.startsWith('budget:')) {
                  final parts = finding.reference.split(':');
                  context.push('/budgets/${parts[1]}');
                } else if (finding.reference.startsWith('debt:')) {
                  context.push('/budgets/debt-payments');
                } else {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => const DiagnosticSetupScreen()));
                }
              },
            ),
          ),
        ExpansionTile(
          title: Text(t('projection')),
          children: [
            for (final p in report.projection)
              ListTile(
                title: Text(
                  '${DateFormat.yMMMd(locale).format(p.date)} · ${reference(p.reference)}',
                ),
                subtitle: Text(
                  '${reference(p.accountId)} · ${money(p.deltaMinor, p.currency)} → ${money(p.balanceMinor, p.currency)}\n${t('netProjected')}: ${money(p.freeMinor, p.currency)}',
                ),
              ),
          ],
        ),
        ExpansionTile(
          title: Text(t('effectiveAnnualRate')),
          children: [
            for (final debt in input.records.where(
              (r) =>
                  r.kind == 'debt' &&
                  r.number('rateBps') != null &&
                  r.text('ratePeriod').isNotEmpty,
            ))
              ListTile(
                title: Text(reference(debt.text('accountId'))),
                subtitle: Text(
                  _hidden
                      ? '••••••'
                      : '${NumberFormat.decimalPattern(locale).format((debt.text('ratePeriod') == 'monthlyEffective' ? math.pow(1 + debt.number('rateBps')! / 10000, 12) - 1 : debt.number('rateBps')! / 10000) * 100)}% · ${debt.text('referenceDate')} · ${t(debt.text('rateMode'))}',
                ),
              ),
          ],
        ),
        ExpansionTile(
          title: Text(t('valuations')),
          children: [
            for (final valuation in [
              ...snapshot.valuations,
            ]..sort((a, b) => b.text('referenceDate').compareTo(a.text('referenceDate'))))
              ListTile(
                title: Text(valuation.text('name')),
                subtitle: Text(
                  '${valuation.text('referenceDate')} · ${money(valuation.number('amountMinor') ?? 0, valuation.text('currency'))} · ${valuation.number('ownershipPercent')}%',
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
