import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/request_id.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/entities/planning_agenda_entry.dart';
import '../../domain/entities/planning_follow_up.dart';
import '../providers/canonical_finance_providers.dart';

String planningEntryRoute(PlanningAgendaEntry entry) => entry.kind == PlanningEntryKind.debt
    ? '/budgets/debt-payments/${entry.commitmentId}?month=${entry.monthKey}'
    : '/budgets/${entry.budgetId}/items/${entry.itemId}';

class PlanningFollowUpButton extends StatelessWidget {
  const PlanningFollowUpButton({required this.userId, required this.entry, super.key});
  final String userId;
  final PlanningAgendaEntry entry;
  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey('planning_follow_up_${entry.id}'),
    tooltip: AppLocalizations.of(context).planningFollowUpText('menu'),
    icon: const Icon(Icons.more_horiz),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PlanningFollowUpSheet(userId: userId, entry: entry),
    ),
  );
}

class PlanningFollowUpSheet extends ConsumerStatefulWidget {
  const PlanningFollowUpSheet({
    required this.userId,
    required this.entry,
    this.initialAction,
    super.key,
  });
  final String userId;
  final PlanningAgendaEntry entry;
  final PlanningFollowUpAction? initialAction;
  @override
  ConsumerState<PlanningFollowUpSheet> createState() => _PlanningFollowUpSheetState();
}

class _PlanningFollowUpSheetState extends ConsumerState<PlanningFollowUpSheet> {
  PlanningFollowUpCommand? _command;
  bool _saving = false;
  Failure? _failure;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entry = widget.entry;
    final profile = ref.watch(canonicalUserProfileProvider(widget.userId));
    final operations = entry.kind == PlanningEntryKind.expense
        ? ref.watch(
            canonicalBudgetItemOperationsProvider((
              userId: widget.userId,
              budgetId: entry.budgetId!,
              itemId: entry.itemId!,
            )),
          )
        : const AsyncData<List<FinancialOperation>>([]);
    final rows = operations.valueOrNull ?? const <FinancialOperation>[];
    final reversed = rows
        .where((row) => row.status == OperationStatus.confirmed && row.projectionDirection == -1)
        .map((row) => row.reversalOf)
        .toSet();
    final canComplete = rows.any(
      (row) =>
          row.type == OperationType.expense &&
          row.status == OperationStatus.confirmed &&
          row.projectionDirection == 1 &&
          row.reversalOf == null &&
          !reversed.contains(row.id),
    );
    final conflict = _failure is ConflictFailure || _failure is AuthFailure;
    final enabled = !_saving && profile.hasValue && profile.valueOrNull != null && !conflict;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.planningFollowUpText('menu'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (_saving) const LinearProgressIndicator(),
              if (_failure != null) ...[
                Text(
                  l10n.planningFollowUpText(conflict ? 'conflict' : 'error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                if (!conflict)
                  TextButton(onPressed: _saving ? null : _send, child: Text(l10n.retry)),
              ],
              if (entry.kind == PlanningEntryKind.expense &&
                  entry.followUpState != PlanningFollowUpState.completed)
                ListTile(
                  key: const ValueKey('follow_up_completeExpense'),
                  leading: const Icon(Icons.task_alt),
                  title: Text(l10n.planningFollowUpText('complete')),
                  subtitle: Text(
                    l10n.planningFollowUpText(canComplete ? 'finishInfo' : 'needsRecord'),
                  ),
                  onTap: enabled && canComplete
                      ? () => _choose(PlanningFollowUpAction.completeExpense)
                      : null,
                ),
              ListTile(
                key: const ValueKey('follow_up_dismiss'),
                leading: const Icon(Icons.notifications_off_outlined),
                title: Text(l10n.planningFollowUpText('dismiss')),
                subtitle: Text(l10n.planningFollowUpText('dismissInfo')),
                onTap: enabled ? () => _choose(PlanningFollowUpAction.dismiss) : null,
              ),
              ListTile(
                key: const ValueKey('follow_up_snooze'),
                leading: const Icon(Icons.snooze_outlined),
                title: Text(l10n.planningFollowUpText('snooze')),
                onTap: enabled ? () => _choose(PlanningFollowUpAction.snooze) : null,
              ),
              if (entry.followUpState != PlanningFollowUpState.open)
                ListTile(
                  key: const ValueKey('follow_up_resume'),
                  leading: const Icon(Icons.restore),
                  title: Text(l10n.planningFollowUpText('resume')),
                  onTap: enabled ? () => _choose(PlanningFollowUpAction.resume) : null,
                ),
              ListTile(
                key: const ValueKey('follow_up_edit'),
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.planningFollowUpText('edit')),
                onTap: _saving
                    ? null
                    : () {
                        final router = GoRouter.of(context);
                        Navigator.pop(context);
                        router.push(
                          entry.kind == PlanningEntryKind.debt
                              ? '/budgets/debt-payments/${entry.commitmentId}/edit?month=${entry.monthKey}'
                              : '/budgets/${entry.budgetId}/items/${entry.itemId}/edit',
                        );
                      },
              ),
              if (operations.hasError)
                TextButton(
                  onPressed: () => ref.invalidate(
                    canonicalBudgetItemOperationsProvider((
                      userId: widget.userId,
                      budgetId: entry.budgetId!,
                      itemId: entry.itemId!,
                    )),
                  ),
                  child: Text(l10n.retry),
                ),
              if (profile.hasError)
                TextButton(
                  onPressed: () => ref.invalidate(canonicalUserProfileProvider(widget.userId)),
                  child: Text(l10n.retry),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _choose(PlanningFollowUpAction action) async {
    final profile = ref.read(canonicalUserProfileProvider(widget.userId)).valueOrNull;
    if (profile == null) return;
    String? remindOn;
    if (action == PlanningFollowUpAction.snooze) {
      final today = ref.read(planningTodayProvider(widget.userId));
      final selected = await showDatePicker(
        context: context,
        helpText: AppLocalizations.of(context).planningFollowUpText('returnDate'),
        initialDate: DateTime(today.year, today.month, today.day + 1),
        firstDate: DateTime(today.year, today.month, today.day + 1),
        lastDate: DateTime(today.year, today.month, today.day + 28),
      );
      if (selected == null || !mounted) return;
      remindOn = DateFormatMonth.day(selected);
    }
    _command = PlanningFollowUpCommand(
      source: widget.entry.source,
      action: action,
      requestId: newRequestId(),
      expectedGeneration: profile.dataGeneration,
      expectedVersion: widget.entry.followUpVersion,
      remindOn: remindOn,
    );
    await _send();
  }

  Future<void> _send() async {
    final command = _command;
    final repository = ref.read(planningFollowUpRepositoryProvider);
    if (command == null || repository == null || _saving) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    final result = await repository.mutate(widget.userId, command);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _failure = failure;
        _saving = false;
      }),
      (_) {
        ref.invalidate(planningFollowUpsProvider(widget.userId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).planningFollowUpText('saved'))),
        );
        Navigator.pop(context);
      },
    );
  }
}

class PlanningEntryTile extends StatelessWidget {
  const PlanningEntryTile({
    required this.entry,
    required this.userId,
    required this.accounts,
    this.amountsHidden = false,
    this.canOpen = true,
    super.key,
  });
  final PlanningAgendaEntry entry;
  final String userId;
  final List<FinanceAccount> accounts;
  final bool amountsHidden;
  final bool canOpen;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    String money(int value) => CurrencyFormatter.formatMinor(value, entry.currency, locale: locale);
    final debt = entry.kind == PlanningEntryKind.debt;
    final label = debt
        ? l10n.debtTitle
        : entry.kind == PlanningEntryKind.income
        ? l10n.income
        : l10n.expense;
    final title = debt
        ? accounts.where((account) => account.id == entry.debtAccountId).firstOrNull?.name ??
              l10n.debtTitle
        : entry.title;
    final status = entry.followUpReason == 'record-changed'
        ? l10n.planningFollowUpText('reopened')
        : entry.followUpState == PlanningFollowUpState.open
        ? ''
        : l10n.planningFollowUpText(entry.followUpState.name);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            ListTile(
              key: ValueKey('agenda_entry_${entry.id}'),
              leading: Icon(
                debt ? Icons.event_note_outlined : Icons.north_east,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(title),
              subtitle: Text(
                '$label · ${DateFormat.yMMMd(locale).format(entry.date)}${entry.remindOn == null ? '' : '\n${l10n.planningFollowUpText('returnDate')}: ${entry.remindOn}'}${status.isEmpty ? '' : '\n$status'}',
              ),
              trailing: entry.kind == PlanningEntryKind.income
                  ? const Icon(Icons.chevron_right)
                  : PlanningFollowUpButton(userId: userId, entry: entry),
              onTap: canOpen ? () => context.push<void>(planningEntryRoute(entry)) : null,
            ),
            if (!amountsHidden)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${debt ? l10n.planningFollowUpText('paid') : l10n.planningRecorded}: ${money(entry.recordedMinor)} · ${l10n.planned(money(entry.plannedMinor))}${debt ? ' · ${l10n.planningPendingAmount}: ${money(entry.pendingMinor)}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PlanningFollowUpLauncherSheet extends ConsumerWidget {
  const PlanningFollowUpLauncherSheet({
    required this.userId,
    required this.budgetId,
    required this.itemId,
    super.key,
  });
  final String userId;
  final String budgetId;
  final String itemId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(canonicalBudgetProvider((userId: userId, budgetId: budgetId)));
    final month = budget.valueOrNull?.monthKey;
    final agenda = month == null
        ? null
        : ref.watch(planningAgendaEntriesProvider((userId: userId, monthKey: month)));
    final entry = agenda?.valueOrNull
        ?.where((item) => item.budgetId == budgetId && item.itemId == itemId)
        .firstOrNull;
    if (entry != null) return PlanningFollowUpSheet(userId: userId, entry: entry);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: budget.hasError || agenda?.hasError == true || agenda?.hasValue == true
            ? TextButton(
                onPressed: () => retryPlanning(ref, userId),
                child: Text(AppLocalizations.of(context).retry),
              )
            : const LinearProgressIndicator(),
      ),
    );
  }
}

final _initialWaitProvider = FutureProvider.autoDispose.family<void, String>((ref, uid) async {
  final completion = Completer<void>();
  final timer = Timer(const Duration(seconds: 8), completion.complete);
  ref.onDispose(timer.cancel);
  await completion.future;
});

class PlanningAttentionCard extends ConsumerWidget {
  const PlanningAttentionCard({required this.userId, this.amountsHidden = false, super.key});
  final String userId;
  final bool amountsHidden;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(planningAttentionProvider(userId));
    final waiting = ref.watch(_initialWaitProvider(userId)).isLoading;
    final accounts =
        ref.watch(canonicalAccountsProvider(userId)).valueOrNull ?? const <FinanceAccount>[];
    return Card(
      key: const ValueKey('planning_attention'),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.planningPendingOnly, style: Theme.of(context).textTheme.titleLarge),
            if (state.loading && waiting)
              const LinearProgressIndicator()
            else ...[
              if (state.incomplete) ...[
                Text(l10n.planningFollowUpText('partial')),
                TextButton(
                  onPressed: () {
                    retryPlanning(ref, userId);
                    ref.invalidate(_initialWaitProvider(userId));
                  },
                  child: Text(l10n.retry),
                ),
              ],
              if (!state.incomplete)
                Text(l10n.planningAttentionCount(state.entries.length))
              else if (state.entries.isNotEmpty)
                Text(l10n.planningFollowUpText('countPartial')),
              if (state.entries.isEmpty && !state.incomplete)
                Text(l10n.planningFollowUpText('empty')),
              for (final entry in state.entries.take(3))
                PlanningEntryTile(
                  entry: entry,
                  userId: userId,
                  accounts: accounts,
                  amountsHidden: amountsHidden,
                ),
              TextButton(
                onPressed: () => context.go('/budgets/agenda'),
                child: Text(l10n.planningFollowUpText('view')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
