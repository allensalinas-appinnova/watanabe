import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection.dart';
import '../../../core/routing/finance_route_header.dart';
import '../../../core/utils/async_value_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/money_parser.dart';
import '../../../core/utils/request_id.dart';
import '../../../core/widgets/day_of_month_selector.dart';
import '../../../core/widgets/pinned_action_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../finance/domain/entities/finance_account.dart';
import '../../finance/presentation/providers/canonical_finance_providers.dart';
import '../../finance/presentation/widgets/finance_account_option.dart';
import '../../finance/presentation/widgets/finance_popup_selector.dart';
import '../../finance/presentation/widgets/planning_section_header.dart';
import '../domain/commitment_repository.dart';
import '../domain/debt_commitment.dart';
import 'utils/payment_date_suggestion.dart';

class DebtCommitmentsScreen extends ConsumerStatefulWidget {
  const DebtCommitmentsScreen({this.initialMonthKey, super.key});
  final String? initialMonthKey;
  @override
  ConsumerState<DebtCommitmentsScreen> createState() => _DebtCommitmentsScreenState();
}

class _DebtCommitmentsScreenState extends ConsumerState<DebtCommitmentsScreen> {
  DateTime? _initialMonth;

  @override
  void initState() {
    super.initState();
    final key = widget.initialMonthKey;
    final parsed = key != null && RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(key)
        ? DateTime.tryParse('$key-01')
        : null;
    if (parsed != null) _initialMonth = DateTime(parsed.year, parsed.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authSessionProvider).valueOrNull?.id;
      if (mounted && uid != null && _initialMonth != null) {
        ref.read(planningMonthProvider(uid).notifier).select(_initialMonth!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final uid = ref.watch(authSessionProvider).valueOrNull?.id;
    if (uid == null) return Scaffold(body: Center(child: Text(l.sessionExpired)));
    final month = ref.watch(planningMonthProvider(uid));
    final commitments = ref.watch(debtCommitmentsProvider(uid));
    final payments = ref.watch(debtCommitmentPaymentsProvider(uid));
    final accounts =
        ref.watch(canonicalAccountsProvider(uid)).valueOrNull ?? const <FinanceAccount>[];
    final monthKey = DateFormat('yyyy-MM').format(month);
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      bottomNavigationBar: PinnedActionBar(
        buttonKey: const ValueKey('debt_commitment_create'),
        label: l.debtCommitmentCreate,
        icon: Icons.add,
        onPressed: () => context.push('/budgets/debt-payments/new?month=$monthKey'),
      ),
      body: Column(
        children: [
          PlanningSectionHeader(userId: uid, section: PlanningSection.debtPayments),
          Expanded(
            child: commitments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(debtCommitmentsProvider(uid)),
                  child: Text(l.retry),
                ),
              ),
              data: (plans) {
                if (payments.isLoading) return const Center(child: CircularProgressIndicator());
                if (payments.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(debtCommitmentPaymentsProvider(uid)),
                      child: Text(l.retry),
                    ),
                  );
                }
                final links = payments.requireValue;
                final active =
                    plans
                        .where(
                          (plan) => plan.scheduledDateFor(monthKey) != null,
                        )
                        .toList()
                      ..sort(
                        (a, b) {
                          final date = a
                              .scheduledDateFor(monthKey)!
                              .compareTo(b.scheduledDateFor(monthKey)!);
                          return date == 0 ? a.id.compareTo(b.id) : date;
                        },
                      );
                final currencies = active.map((plan) => plan.currency).toSet().toList()..sort();
                final planned = {for (final currency in currencies) currency: 0};
                final paid = {for (final currency in currencies) currency: 0};
                for (final plan in active) {
                  planned[plan.currency] =
                      planned[plan.currency]! +
                      (plan.dueDateFor(monthKey) == null || plan.isSkipped(monthKey)
                          ? 0
                          : plan.amountMinor);
                  paid[plan.currency] =
                      paid[plan.currency]! +
                      links
                          .where(
                            (link) => link.commitmentId == plan.id && link.monthKey == monthKey,
                          )
                          .fold(0, (sum, link) => sum + link.amountMinor);
                }
                final scheduled = active
                    .where(
                      (plan) =>
                          plan.dueDateFor(monthKey) != null &&
                          !plan.isSkipped(monthKey) &&
                          !plan.isPausedFor(monthKey),
                    )
                    .toList(growable: false);
                final excluded = active
                    .where((plan) => plan.isSkipped(monthKey) || plan.isPausedFor(monthKey))
                    .toList(growable: false);
                final pendingCount = scheduled.where((plan) {
                  final amountPaid = links
                      .where((link) => link.commitmentId == plan.id && link.monthKey == monthKey)
                      .fold<int>(0, (sum, link) => sum + link.amountMinor);
                  return (plan.amountMinor - amountPaid).clamp(0, plan.amountMinor) > 0;
                }).length;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    PlanningMonthlySummary(userId: uid),
                    Text(
                      l.planningDebtCount(scheduled.length, pendingCount),
                      key: const ValueKey('debt_commitment_count'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final currency in currencies)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(currency, style: Theme.of(context).textTheme.titleMedium),
                              Text(
                                '${l.debtCommitmentMonthlyPlanned}: ${CurrencyFormatter.formatMinor(planned[currency]!, currency, locale: locale)}',
                              ),
                              Text(
                                '${l.debtCommitmentPaid}: ${CurrencyFormatter.formatMinor(paid[currency]!, currency, locale: locale)}',
                              ),
                              Text(
                                '${l.debtCommitmentRemaining}: ${CurrencyFormatter.formatMinor(scheduled.where((plan) => plan.currency == currency).fold<int>(0, (sum, plan) {
                                  final paidForPlan = links.where((link) => link.commitmentId == plan.id && link.monthKey == monthKey).fold<int>(0, (subtotal, link) => subtotal + link.amountMinor);
                                  return sum + (plan.amountMinor - paidForPlan).clamp(0, plan.amountMinor);
                                }), currency, locale: locale)}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (active.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(child: Text(l.debtCommitmentsEmpty)),
                      ),
                    for (var index = 0; index < scheduled.length; index++)
                      _CommitmentRow(
                        number: index + 1,
                        plan: scheduled[index],
                        account: accounts
                            .where((item) => item.id == scheduled[index].debtAccountId)
                            .firstOrNull,
                        monthKey: monthKey,
                        paidMinor: links
                            .where(
                              (link) =>
                                  link.commitmentId == scheduled[index].id &&
                                  link.monthKey == monthKey,
                            )
                            .fold<int>(0, (sum, link) => sum + link.amountMinor),
                        onTap: () => context.push(
                          '/budgets/debt-payments/${scheduled[index].id}?month=$monthKey',
                        ),
                      ),
                    if (excluded.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        l.debtCommitmentsExcluded,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      for (final plan in excluded)
                        _CommitmentRow(
                          number: null,
                          plan: plan,
                          account: accounts
                              .where((item) => item.id == plan.debtAccountId)
                              .firstOrNull,
                          monthKey: monthKey,
                          paidMinor: links
                              .where(
                                (link) => link.commitmentId == plan.id && link.monthKey == monthKey,
                              )
                              .fold<int>(0, (sum, link) => sum + link.amountMinor),
                          onTap: () =>
                              context.push('/budgets/debt-payments/${plan.id}?month=$monthKey'),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CommitmentRow extends StatelessWidget {
  const _CommitmentRow({
    this.number,
    required this.plan,
    required this.account,
    required this.monthKey,
    required this.paidMinor,
    required this.onTap,
  });
  final int? number;
  final DebtCommitment plan;
  final FinanceAccount? account;
  final String monthKey;
  final int paidMinor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final occurrence = DebtCommitmentOccurrence(
      commitment: plan,
      monthKey: monthKey,
      paidMinor: paidMinor,
      skipped: plan.isSkipped(monthKey),
    );
    final due = plan.scheduledDateFor(monthKey)!;
    final statusLabel = switch (occurrence.status) {
      DebtInstallmentStatus.upcoming => l.debtCommitmentStatusUpcoming,
      DebtInstallmentStatus.due => l.debtCommitmentStatusDue,
      DebtInstallmentStatus.partiallyPaid => l.debtCommitmentStatusPartial,
      DebtInstallmentStatus.paid => l.debtCommitmentStatusPaid,
      DebtInstallmentStatus.missed => l.debtCommitmentStatusMissed,
      DebtInstallmentStatus.skipped => l.debtCommitmentStatusSkipped,
      DebtInstallmentStatus.paused => l.debtCommitmentStatusPaused,
    };
    final locale = Localizations.localeOf(context).toString();
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        key: ValueKey('debt_commitment_occurrence_${plan.id}_$monthKey'),
        minTileHeight: 76,
        leading: number == null
            ? const Icon(Icons.pause_circle_outline)
            : CircleAvatar(child: Text('$number')),
        title: Text(account?.name ?? l.debtTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${DateFormat.yMMMd(locale).format(due)} · $statusLabel · ${l.debtCommitmentRemaining}: ${CurrencyFormatter.formatMinor(occurrence.remainingMinor, plan.currency, locale: locale)}',
        ),
        trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}

class DebtCommitmentFormScreen extends ConsumerStatefulWidget {
  const DebtCommitmentFormScreen({super.key, this.initialDebtAccountId, this.initialMonthKey});
  final String? initialDebtAccountId;
  final String? initialMonthKey;
  @override
  ConsumerState<DebtCommitmentFormScreen> createState() => _DebtCommitmentFormScreenState();
}

class _DebtCommitmentFormScreenState extends ConsumerState<DebtCommitmentFormScreen> {
  final _requestId = newRequestId();
  final _amount = TextEditingController();
  String? _debtId, _bankId, _error;
  DateTime _firstDue = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _lastDue;
  int _dueDay = DateTime.now().day;
  bool _dueDayManuallyEdited = false;
  bool _firstMonthManuallyEdited = false;
  bool _initialSuggestionApplied = false;
  bool _saving = false;
  bool _remindersEnabled = false;

  @override
  void initState() {
    super.initState();
    _debtId = widget.initialDebtAccountId;
    final key = widget.initialMonthKey;
    final parsed = key != null && RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(key)
        ? DateTime.tryParse('$key-01')
        : null;
    if (parsed != null) _firstDue = DateTime(parsed.year, parsed.month);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final uid = ref.watch(authSessionProvider).valueOrNull?.id;
    if (uid == null) return Scaffold(body: Center(child: Text(l.sessionExpired)));
    final state = ref.watch(canonicalAccountsProvider(uid));
    final profile = ref.watch(canonicalUserProfileProvider(uid)).valueOrNull;
    final accounts = state.valueOrNull ?? const <FinanceAccount>[];
    final debts = accounts.where((a) => a.isDebt && a.status == 'active').toList();
    final selected = debts.where((a) => a.id == _debtId).firstOrNull;
    if (selected != null && !_initialSuggestionApplied && profile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initialSuggestionApplied = true;
          _applyPaymentDaySuggestion(selected, profile.timeZone);
        }
      });
    }
    final banks = accounts
        .where(
          (a) =>
              !a.isDebt &&
              a.status == 'active' &&
              (selected == null || a.currency == selected.currency),
        )
        .toList();
    return Scaffold(
      appBar: FinanceRouteHeader(
        title: l.debtCommitmentCreate,
        backLabel: l.cancel,
        onBack: () => popOrGo(context, '/budgets/debt-payments'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(canonicalAccountsProvider(uid)),
            child: Text(l.retry),
          ),
        ),
        data: (_) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            FinancePopupSelector<String>(
              key: ValueKey('commitment_debt_${_debtId ?? 'none'}'),
              controlKey: const ValueKey('commitment_debt_selector'),
              title: l.debtTitle,
              placeholder: l.selectionChoosePrompt,
              initialValue: _debtId,
              options: debts.map((a) => a.id).toList(),
              optionLabel: (id) => debts.firstWhere((a) => a.id == id).name,
              searchText: (id) => debts.firstWhere((a) => a.id == id).name,
              optionBuilder: (context, id) =>
                  FinanceAccountOption(account: debts.firstWhere((a) => a.id == id)),
              onSelected: (id) {
                final debt = debts.firstWhere((a) => a.id == id);
                setState(() {
                  _debtId = id;
                  _bankId = null;
                  _initialSuggestionApplied = false;
                });
                if (profile != null) {
                  _initialSuggestionApplied = true;
                  _applyPaymentDaySuggestion(debt, profile.timeZone);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.debtCommitmentAmount,
                prefixText: '${selected?.currency ?? 'COP'} ',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _firstDue,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2099),
                );
                if (date != null) {
                  setState(() {
                    _firstDue = DateTime(date.year, date.month);
                    _firstMonthManuallyEdited = true;
                  });
                }
              },
              child: Text(
                '${l.debtCommitmentFirstMonth}: ${DateFormat.yMMM(Localizations.localeOf(context).toString()).format(_firstDue)}',
              ),
            ),
            DayOfMonthSelector(
              key: const ValueKey('commitment_due_day'),
              fieldId: 'commitment_due_day',
              selectedDay: _dueDay,
              label: l.debtCommitmentDueDay,
              dayLabel: l.day,
              enabled: !_saving,
              onChanged: (day) {
                if (day == null) return;
                _dueDayManuallyEdited = true;
                setState(() => _dueDay = day);
              },
            ),
            if (selected?.paymentDueDay != null) ...[
              const SizedBox(height: 4),
              Text(l.debtUpcomingPaymentSuggestion(selected!.paymentDueDay!)),
              TextButton.icon(
                key: const ValueKey('commitment_use_payment_day_suggestion'),
                onPressed: profile == null
                    ? null
                    : () => _applyPaymentDaySuggestion(selected, profile.timeZone, force: true),
                icon: const Icon(Icons.event_repeat),
                label: Text(l.debtUseSuggestedPaymentDay),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _lastDue ?? _firstDue,
                  firstDate: _firstDue,
                  lastDate: DateTime(2099),
                );
                if (date != null) setState(() => _lastDue = date);
              },
              child: Text(
                _lastDue == null
                    ? l.debtCommitmentLastMonth
                    : '${l.debtCommitmentLastMonth}: ${DateFormat.yMMM(Localizations.localeOf(context).toString()).format(_lastDue!)}',
              ),
            ),
            const SizedBox(height: 16),
            if (selected != null)
              FinancePopupSelector<String>(
                key: ValueKey('commitment_bank_${selected.currency}_${_bankId ?? 'none'}'),
                controlKey: const ValueKey('commitment_bank_selector'),
                title: l.debtBank,
                placeholder: l.selectionChoosePrompt,
                initialValue: _bankId,
                options: banks.map((a) => a.id).toList(),
                optionLabel: (id) => banks.firstWhere((a) => a.id == id).name,
                searchText: (id) => banks.firstWhere((a) => a.id == id).name,
                optionBuilder: (context, id) =>
                    FinanceAccountOption(account: banks.firstWhere((a) => a.id == id)),
                onSelected: (id) => setState(() => _bankId = id),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _remindersEnabled,
              onChanged: (value) => setState(() => _remindersEnabled = value ?? false),
              title: Text(l.debtCommitmentReminders),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : () => _save(uid, selected),
              child: _saving ? const CircularProgressIndicator() : Text(l.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(String uid, FinanceAccount? debt) async {
    final l = AppLocalizations.of(context);
    if (debt == null) {
      setState(() => _error = l.debtErrorReference);
      return;
    }
    late final int amountMinor;
    try {
      amountMinor = MoneyParser.minorUnits(_amount.text, debt.currency);
    } catch (_) {
      setState(() => _error = l.debtErrorSplit);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final command = <String, Object?>{
      'requestId': _requestId,
      'action': 'create',
      'debtAccountId': debt.id,
      'currency': debt.currency,
      'amountMinor': amountMinor,
      'firstDueMonth': DateFormat('yyyy-MM').format(_firstDue),
      'dueDay': _dueDay,
      if (_lastDue != null) 'lastDueMonth': DateFormat('yyyy-MM').format(_lastDue!),
      if (_bankId != null) 'bankAccountId': _bankId,
      'remindersEnabled': _remindersEnabled,
    };
    final result = await getIt<CommitmentRepository>().execute(uid, command);
    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _saving = false;
        _error = failure.message;
      }),
      (_) {
        ref.invalidate(debtCommitmentsProvider(uid));
        context.pop();
      },
    );
  }

  void _applyPaymentDaySuggestion(FinanceAccount debt, String timeZone, {bool force = false}) {
    final suggestedDay = debt.paymentDueDay;
    if (suggestedDay == null) return;
    if (force || !_dueDayManuallyEdited) {
      _dueDay = suggestedDay;
      if (force) _dueDayManuallyEdited = false;
    }
    if (force || !_firstMonthManuallyEdited) {
      final date = nextNominalPaymentDate(
        instant: DateTime.now(),
        timeZone: timeZone,
        dueDay: _dueDay,
      );
      _firstDue = DateTime(date.year, date.month);
      if (force) _firstMonthManuallyEdited = false;
    }
    if (mounted) setState(() {});
  }
}
