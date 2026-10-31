import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/financial_operation.dart';
import '../models/budget_item_movement_preset.dart';
import '../providers/canonical_finance_providers.dart';
import '../widgets/planning_follow_up_controls.dart';

class PlanningItemDetailScreen extends ConsumerWidget {
  const PlanningItemDetailScreen({required this.budgetId, required this.itemId, super.key});
  final String budgetId;
  final String itemId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(authSessionProvider).valueOrNull?.id;
    if (uid == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final budgetKey = (userId: uid, budgetId: budgetId);
    final budget = ref.watch(canonicalBudgetProvider(budgetKey));
    final month = budget.valueOrNull?.monthKey;
    final agenda = month == null
        ? null
        : ref.watch(planningAgendaEntriesProvider((userId: uid, monthKey: month)));
    final entry = agenda?.valueOrNull
        ?.where((item) => item.itemId == itemId && item.budgetId == budgetId)
        .firstOrNull;
    final operations = ref.watch(
      canonicalBudgetItemOperationsProvider((userId: uid, budgetId: budgetId, itemId: itemId)),
    );
    final hidden = ref.watch(dashboardAmountsHiddenProvider);
    final accounts = ref.watch(canonicalAccountsProvider(uid)).valueOrNull ?? const [];
    return Scaffold(
      appBar: FinanceRouteHeader(
        title: l10n.budgetDetailTitle,
        backLabel: l10n.back,
        onBack: () => popOrGo(context, '/budgets/$budgetId'),
      ),
      body: entry == null
          ? Center(
              child:
                  budget.hasError ||
                      agenda?.hasError == true ||
                      agenda?.hasValue == true ||
                      budget.hasValue && budget.valueOrNull == null
                  ? TextButton(
                      onPressed: () {
                        ref.invalidate(canonicalBudgetProvider(budgetKey));
                        retryPlanning(ref, uid);
                      },
                      child: Text(l10n.retry),
                    )
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                PlanningEntryTile(
                  entry: entry,
                  userId: uid,
                  accounts: accounts,
                  amountsHidden: hidden,
                  canOpen: false,
                ),
                TextButton.icon(
                  onPressed: () => context.push('/budgets/$budgetId/items/$itemId/edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.planningFollowUpText('edit')),
                ),
                FilledButton.icon(
                  key: const ValueKey('planning_item_register'),
                  icon: const Icon(Icons.add),
                  label: Text(
                    entry.kind.name == 'income'
                        ? l10n.budgetRecordIncome
                        : l10n.budgetRecordExpense,
                  ),
                  onPressed: () => context.push(
                    '/budgets/$budgetId/items/$itemId/record',
                    extra: BudgetItemMovementPreset(
                      budgetId: budgetId,
                      itemId: itemId,
                      type: entry.kind.name == 'income'
                          ? OperationType.income
                          : OperationType.expense,
                      categoryId: budget.valueOrNull!.categoryId,
                      currency: entry.currency,
                      description: entry.title,
                      amountMinor: entry.pendingMinor > 0 ? entry.pendingMinor : entry.plannedMinor,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/budgets/$budgetId?tab=movements'),
                  icon: const Icon(Icons.link),
                  label: Text(l10n.budgetMovementAssociation),
                ),
                const SizedBox(height: 16),
                Text(l10n.budgetMovementsTab, style: Theme.of(context).textTheme.titleMedium),
                operations.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => TextButton(
                    onPressed: () => ref.invalidate(
                      canonicalBudgetItemOperationsProvider((
                        userId: uid,
                        budgetId: budgetId,
                        itemId: itemId,
                      )),
                    ),
                    child: Text(l10n.retry),
                  ),
                  data: (rows) => Column(
                    children: [
                      if (rows.isEmpty) Text(l10n.budgetMovementsEmpty),
                      for (final row in rows)
                        ListTile(
                          title: Text(row.description),
                          subtitle: Text(
                            row.status == OperationStatus.confirmed
                                ? l10n.planningRecorded
                                : l10n.budgetMovementReversal,
                          ),
                          trailing: hidden
                              ? null
                              : Text(
                                  CurrencyFormatter.formatMinor(
                                    row.recognizedIncomeMinor + row.recognizedExpenseMinor,
                                    row.currency,
                                    locale: Localizations.localeOf(context).toString(),
                                  ),
                                ),
                          onTap:
                              row.debtCommandId == null && row.status == OperationStatus.confirmed
                              ? () => context.push('/operations/${row.id}/edit', extra: row)
                              : null,
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
