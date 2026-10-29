import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/pinned_action_bar.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/planning_agenda_entry.dart';
import '../providers/canonical_finance_providers.dart';
import '../widgets/planning_section_header.dart';

class PlanningAgendaScreen extends ConsumerStatefulWidget {
  const PlanningAgendaScreen({super.key, this.initialMonthKey});
  final String? initialMonthKey;

  @override
  ConsumerState<PlanningAgendaScreen> createState() => _PlanningAgendaScreenState();
}

class _PlanningAgendaScreenState extends ConsumerState<PlanningAgendaScreen> {
  bool _showAll = false;
  bool _initialMonthApplied = false;
  String _kindFilter = 'all';
  String _currencyFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userId = ref.watch(authSessionProvider).valueOrNull?.id;
    if (userId == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    if (!_initialMonthApplied) {
      _initialMonthApplied = true;
      final key = widget.initialMonthKey;
      final parsed = key != null && RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(key)
          ? DateTime.tryParse('$key-01')
          : null;
      if (parsed != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(planningMonthProvider(userId).notifier).select(parsed);
        });
      }
    }
    final month = ref.watch(planningMonthProvider(userId));
    final monthKey = DateFormat('yyyy-MM').format(month);
    final entries = ref.watch(planningAgendaEntriesProvider((userId: userId, monthKey: monthKey)));
    final accounts =
        ref.watch(canonicalAccountsProvider(userId)).valueOrNull ?? const <FinanceAccount>[];
    return Scaffold(
      bottomNavigationBar: PinnedActionBar(
        buttonKey: const ValueKey('planning_agenda_create'),
        label: l10n.planningPlan,
        icon: Icons.add,
        onPressed: () => _showCreateOptions(context, monthKey),
      ),
      body: SafeArea(
        child: Column(
          children: [
            PlanningSectionHeader(userId: userId, section: PlanningSection.agenda),
            Expanded(
              child: entries.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(
                      planningAgendaEntriesProvider((userId: userId, monthKey: monthKey)),
                    ),
                    child: Text(l10n.retry),
                  ),
                ),
                data: (allEntries) {
                  final currencies = allEntries.map((entry) => entry.currency).toSet().toList()
                    ..sort();
                  final filtered = allEntries
                      .where((entry) {
                        final kindMatches = _kindFilter == 'all' || entry.kind.name == _kindFilter;
                        final currencyMatches =
                            _currencyFilter == 'all' || entry.currency == _currencyFilter;
                        final pendingMatches = _showAll || entry.pendingMinor > 0;
                        return kindMatches && currencyMatches && pendingMatches;
                      })
                      .toList(growable: false);
                  if (allEntries.isEmpty) return Center(child: Text(l10n.planningNoEntries));
                  return ListView(
                    key: const ValueKey('planning_agenda_entries'),
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    children: [
                      PlanningMonthlySummary(userId: userId),
                      const SizedBox(height: 8),
                      Text(l10n.planningAgenda, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        l10n.planningSourceExplanation,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(value: false, label: Text(l10n.planningPendingOnly)),
                          ButtonSegment(value: true, label: Text(l10n.planningAll)),
                        ],
                        selected: {_showAll},
                        onSelectionChanged: (value) => setState(() => _showAll = value.first),
                        showSelectedIcon: false,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          DropdownButton<String>(
                            key: const ValueKey('planning_agenda_kind_filter'),
                            value: _kindFilter,
                            onChanged: (value) => setState(() => _kindFilter = value ?? 'all'),
                            items: [
                              DropdownMenuItem(value: 'all', child: Text(l10n.planningAllTypes)),
                              DropdownMenuItem(
                                value: PlanningEntryKind.income.name,
                                child: Text(l10n.income),
                              ),
                              DropdownMenuItem(
                                value: PlanningEntryKind.expense.name,
                                child: Text(l10n.expense),
                              ),
                              DropdownMenuItem(
                                value: PlanningEntryKind.debt.name,
                                child: Text(l10n.debtTitle),
                              ),
                            ],
                          ),
                          if (currencies.length > 1)
                            DropdownButton<String>(
                              key: const ValueKey('planning_agenda_currency_filter'),
                              value: _currencyFilter,
                              onChanged: (value) =>
                                  setState(() => _currencyFilter = value ?? 'all'),
                              items: [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text(l10n.planningAllCurrencies),
                                ),
                                for (final currency in currencies)
                                  DropdownMenuItem(value: currency, child: Text(currency)),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Text(l10n.planningNoPendingEntries, textAlign: TextAlign.center),
                        ),
                      for (var index = 0; index < filtered.length; index++) ...[
                        if (index == 0 ||
                            !_sameDate(filtered[index - 1].date, filtered[index].date))
                          Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 4),
                            child: Text(
                              DateFormat.yMMMd(
                                Localizations.localeOf(context).toString(),
                              ).format(filtered[index].date),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        _AgendaEntryCard(
                          entry: filtered[index],
                          accounts: accounts,
                          onTap: () => _openEntry(context, filtered[index], monthKey),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _openEntry(BuildContext context, PlanningAgendaEntry entry, String monthKey) {
    if (entry.commitmentId != null) {
      context.push('/budgets/debt-payments/${entry.commitmentId}?month=$monthKey');
    } else if (entry.budgetId != null) {
      context.push('/budgets/${entry.budgetId}');
    }
  }

  Future<void> _showCreateOptions(BuildContext context, String monthKey) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(l10n.createBudget),
              onTap: () => Navigator.pop(context, 'budget'),
            ),
            ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: Text(l10n.debtCommitmentCreate),
              onTap: () => Navigator.pop(context, 'debt'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    await context.push<void>(
      choice == 'budget'
          ? '/budgets/new?month=$monthKey'
          : '/budgets/debt-payments/new?month=$monthKey',
    );
  }
}

class _AgendaEntryCard extends StatelessWidget {
  const _AgendaEntryCard({required this.entry, required this.accounts, required this.onTap});
  final PlanningAgendaEntry entry;
  final List<FinanceAccount> accounts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (entry.kind) {
      PlanningEntryKind.income => l10n.income,
      PlanningEntryKind.expense => l10n.expense,
      PlanningEntryKind.debt => l10n.debtTitle,
    };
    final icon = switch (entry.kind) {
      PlanningEntryKind.income => Icons.south_west,
      PlanningEntryKind.expense => Icons.north_east,
      PlanningEntryKind.debt => Icons.event_note_outlined,
    };
    final locale = Localizations.localeOf(context).toString();
    final title = entry.debtAccountId == null
        ? entry.title
        : accounts.where((account) => account.id == entry.debtAccountId).firstOrNull?.name ??
              l10n.debtTitle;
    String amount(int value) =>
        CurrencyFormatter.formatMinor(value, entry.currency, locale: locale);
    return Card(
      child: ListTile(
        key: ValueKey('agenda_entry_${entry.id}'),
        minTileHeight: 76,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(
          '$label · ${l10n.planned(amount(entry.plannedMinor))}\n${l10n.planningRecorded}: ${amount(entry.recordedMinor)} · ${l10n.planningPendingAmount}: ${amount(entry.pendingMinor)}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
