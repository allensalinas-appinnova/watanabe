import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/pinned_action_bar.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/budget_command_failure.dart';
import '../../domain/entities/budget_flow_type.dart';
import '../../domain/entities/budget_item.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/usecases/calculate_budget_tracking.dart';
import '../providers/canonical_finance_providers.dart';
import '../widgets/budget_command_message.dart';

class CanonicalBudgetDetailScreen extends ConsumerWidget {
  const CanonicalBudgetDetailScreen({super.key, required this.budgetId, this.initialTab = 0});

  final String budgetId;
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));

    final budgetKey = (userId: user.id, budgetId: budgetId);
    final budgetState = ref.watch(canonicalBudgetProvider(budgetKey));
    final itemsState = ref.watch(canonicalFinanceRepositoryItemsProvider(budgetKey));
    final aggregateState = ref.watch(canonicalBudgetAggregateReconciliationProvider(budgetKey));
    final activeBudget = budgetState.valueOrNull;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: activeBudget != null && activeBudget.status == 'active'
          ? PinnedActionBar(
              buttonKey: const ValueKey('budget_add_item_detail'),
              label: l10n.budgetAddItem,
              icon: Icons.add,
              onPressed: () => context.push('/budgets/${activeBudget.id}/items/new'),
            )
          : null,
      appBar: FinanceRouteHeader(
        title: l10n.budgetDetailTitle,
        backLabel: l10n.budgetBackToBudgets,
        backButtonKey: const ValueKey('budget_detail_back'),
        onBack: () => popOrGo(context, '/budgets'),
      ),
      body: SafeArea(
        child: aggregateState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _BudgetDetailError(
            message: l10n.genericError,
            onRetry: () {
              ref
                ..invalidate(canonicalBudgetAggregateReconciliationProvider(budgetKey))
                ..invalidate(canonicalBudgetProvider(budgetKey))
                ..invalidate(canonicalFinanceRepositoryItemsProvider(budgetKey));
            },
          ),
          data: (_) => budgetState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _BudgetDetailError(
              message: l10n.genericError,
              onRetry: () => ref.invalidate(canonicalBudgetProvider(budgetKey)),
            ),
            data: (budget) {
              if (budget == null || budget.status != 'active') {
                return _BudgetDetailError(
                  message: l10n.genericError,
                  onRetry: () => context.pop(),
                  retryLabel: l10n.budgetBackToBudgets,
                );
              }
              final summaryKey = (
                userId: user.id,
                monthKey: budget.monthKey,
                currency: budget.currency,
              );
              final summaryState = ref.watch(canonicalMonthlySummaryProvider(summaryKey));
              return itemsState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _BudgetDetailError(
                  message: l10n.genericError,
                  onRetry: () {
                    ref
                      ..invalidate(canonicalBudgetAggregateReconciliationProvider(budgetKey))
                      ..invalidate(canonicalFinanceRepositoryItemsProvider(budgetKey));
                  },
                ),
                data: (items) => summaryState.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => _BudgetDetailError(
                    message: l10n.genericError,
                    onRetry: () => ref.invalidate(canonicalMonthlySummaryProvider(summaryKey)),
                  ),
                  data: (summary) => _BudgetDetailContent(
                    budget: budget,
                    items: items,
                    summary: summary,
                    userId: user.id,
                    initialTab: initialTab,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BudgetDetailContent extends ConsumerWidget {
  const _BudgetDetailContent({
    required this.budget,
    required this.items,
    required this.summary,
    required this.userId,
    required this.initialTab,
  });

  final Budget budget;
  final List<BudgetItem> items;
  final MonthlySummary? summary;
  final String userId;
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(canonicalCategoriesProvider(userId)).valueOrNull ?? const [];
    FinanceCategory? category;
    for (final entry in categories) {
      if (entry.id == budget.categoryId) {
        category = entry;
        break;
      }
    }
    final categoryName = category?.customName ?? budget.categoryId;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final month = DateFormat.yMMMM(locale).format(DateTime.parse('${budget.monthKey}-01'));
    final isIncome = budget.flowType == BudgetFlowType.income;
    final activeItems = items.where((item) => item.isActive).toList(growable: false);
    final archivedItems = items.where((item) => !item.isActive).toList(growable: false);
    final operationsKey = (
      userId: userId,
      budgetId: budget.id,
      categoryId: budget.categoryId,
      monthKey: budget.monthKey,
      currency: budget.currency,
      flowType: budget.flowType.value,
    );
    final operationsState = ref.watch(canonicalBudgetCategoryOperationsProvider(operationsKey));
    final displayBudget = budget.copyWith(
      plannedAmountMinor: activeItems.fold<int>(0, (total, item) => total + item.amountMinor),
      itemCount: activeItems.length,
    );
    const calculator = CalculateBudgetTracking();
    final tracking = calculator(displayBudget, const [], summary: summary);
    final actualLabel = isIncome ? l10n.budgetReceived : l10n.budgetSpent;
    final typeLabel = isIncome ? l10n.income : l10n.expense;
    final planned = CurrencyFormatter.formatMinor(
      tracking.plannedMinor,
      budget.currency,
      locale: locale,
    );
    final actual = CurrencyFormatter.formatMinor(
      tracking.actualMinor,
      budget.currency,
      locale: locale,
    );
    final remaining = CurrencyFormatter.formatMinor(
      tracking.remainingMinor.abs(),
      budget.currency,
      locale: locale,
    );
    final statusText = tracking.isExceeded ? l10n.exceeded(remaining) : l10n.remaining(remaining);
    final progress = tracking.plannedMinor <= 0
        ? 0.0
        : (tracking.actualMinor / tracking.plannedMinor).clamp(0.0, 1.0);

    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(
                key: const ValueKey('budget_detail_elements_tab'),
                text: l10n.budgetItemsHeading(activeItems.length),
              ),
              Tab(
                key: const ValueKey('budget_detail_movements_tab'),
                text: l10n.budgetMovementsTab,
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  key: const ValueKey('budget_detail_scroll'),
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      categoryName,
                      key: const ValueKey('budget_detail_category'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isIncome ? Icons.south_west : Icons.north_east,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$typeLabel · $month · ${budget.currency}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _BudgetSummaryCard(
                      planned: l10n.planned(planned),
                      actual: '$actualLabel · $actual',
                      status: statusText,
                      isExceeded: tracking.isExceeded,
                      progress: progress,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.budgetItemsHeading(activeItems.length),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (activeItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(l10n.genericError),
                      ),
                    for (final item in activeItems) ...[
                      _BudgetItemCard(
                        item: item,
                        userId: userId,
                        budgetId: budget.id,
                        currency: budget.currency,
                        locale: locale,
                        canRemove: activeItems.length > 1,
                        onEdit: () => context.push(
                          '/budgets/${budget.id}/items/${item.id}/edit',
                          extra: item,
                        ),
                        onRemove: () => _confirmRemoveItem(context, ref, item),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (activeItems.length == 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 8),
                        child: Text(
                          l10n.budgetLastItemMessage,
                          key: const ValueKey('budget_last_item_hint'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (archivedItems.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        l10n.budgetArchivedItems,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final item in archivedItems) ...[
                        _BudgetItemCard(
                          item: item,
                          currency: budget.currency,
                          locale: locale,
                          archived: true,
                          userId: userId,
                          budgetId: budget.id,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    const SizedBox(height: 16),
                    OutlinedButton(
                      key: const ValueKey('budget_archive_button'),
                      onPressed: () => _confirmArchive(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(color: Theme.of(context).colorScheme.error),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(l10n.budgetDeleteBudgetAction),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.budgetDeleteBudgetMessage,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                operationsState.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () =>
                          ref.invalidate(canonicalBudgetCategoryOperationsProvider(operationsKey)),
                      child: Text(l10n.retry),
                    ),
                  ),
                  data: (operations) => _BudgetMovementsTab(
                    userId: userId,
                    budget: budget,
                    items: items,
                    operations: operations,
                    locale: locale,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveItem(BuildContext context, WidgetRef ref, BudgetItem item) async {
    final l10n = AppLocalizations.of(context);
    final amount = CurrencyFormatter.formatMinor(
      item.amountMinor,
      budget.currency,
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.budgetDeleteItemTitle),
        content: Text(l10n.budgetDeleteItemMessage(amount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm_budget_item_delete'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.budgetRemoveItem),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(canonicalActionsProvider).deleteBudgetItem(userId, budget.id, item.id);
      ref
        ..invalidate(canonicalFinanceRepositoryItemsProvider((userId: userId, budgetId: budget.id)))
        ..invalidate(canonicalBudgetProvider((userId: userId, budgetId: budget.id)))
        ..invalidate(canonicalBudgetsProvider((userId: userId, monthKey: budget.monthKey)));
    } on BudgetCommandException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(budgetCommandMessage(l10n, error.issue))));
    } catch (error) {
      if (!context.mounted) return;
      final isLastItem = error.toString().contains('budget-last-item');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isLastItem ? l10n.budgetLastItemMessage : l10n.budgetItemDeleteFailed),
        ),
      );
    }
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.budgetDeleteBudgetTitle),
        content: Text(l10n.budgetDeleteBudgetMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm_budget_archive'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(l10n.budgetDeleteBudgetAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final failure = await ref.read(canonicalActionsProvider).archiveBudget(userId, budget.id);
      if (!context.mounted) return;
      if (failure != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_budgetArchiveFailureMessage(l10n, failure))),
        );
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      context.goNamed('budgets');
      messenger.showSnackBar(SnackBar(content: Text(l10n.budgetArchiveSuccess)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.budgetArchiveUnexpectedFailure('unavailable'))));
    }
  }
}

String _budgetArchiveFailureMessage(AppLocalizations l10n, Failure failure) {
  if (failure.technicalCode?.startsWith('budget-') == true) {
    return budgetCommandMessage(l10n, BudgetCommandException.fromFailure(failure).issue);
  }
  final code =
      failure.technicalCode != null && RegExp(r'^[a-z0-9-]{1,48}$').hasMatch(failure.technicalCode!)
      ? failure.technicalCode!
      : 'unavailable';
  return switch (failure) {
    NetworkFailure() => l10n.budgetArchiveNetworkFailure(code),
    AuthFailure() => l10n.budgetArchivePermissionFailure(code),
    ConflictFailure() => l10n.budgetArchiveConflictFailure(code),
    UnknownFailure() => l10n.budgetArchiveUnexpectedFailure(code),
  };
}

enum _BudgetMovementFilter { all, linked, unlinked }

class _BudgetMovementsTab extends ConsumerStatefulWidget {
  const _BudgetMovementsTab({
    required this.userId,
    required this.budget,
    required this.items,
    required this.operations,
    required this.locale,
  });

  final String userId;
  final Budget budget;
  final List<BudgetItem> items;
  final List<FinancialOperation> operations;
  final String locale;

  @override
  ConsumerState<_BudgetMovementsTab> createState() => _BudgetMovementsTabState();
}

class _BudgetMovementsTabState extends ConsumerState<_BudgetMovementsTab> {
  _BudgetMovementFilter _filter = _BudgetMovementFilter.all;
  final Set<String> _savingOperationIds = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final itemById = {for (final item in widget.items) item.id: item};
    final visible = widget.operations
        .where(
          (operation) => switch (_filter) {
            _BudgetMovementFilter.all => true,
            _BudgetMovementFilter.linked => operation.budgetItemId != null,
            _BudgetMovementFilter.unlinked => operation.budgetItemId == null,
          },
        )
        .toList(growable: false);
    return ListView(
      key: const ValueKey('budget_detail_movements_list'),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      children: [
        Text(
          l10n.budgetMovementsExplanation,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_BudgetMovementFilter>(
          segments: [
            ButtonSegment(
              value: _BudgetMovementFilter.all,
              label: Text(l10n.budgetMovementFilterAll),
            ),
            ButtonSegment(
              value: _BudgetMovementFilter.linked,
              label: Text(l10n.budgetMovementFilterLinked),
            ),
            ButtonSegment(
              value: _BudgetMovementFilter.unlinked,
              label: Text(l10n.budgetMovementFilterUnlinked),
            ),
          ],
          selected: {_filter},
          onSelectionChanged: (values) => setState(() => _filter = values.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(l10n.budgetMovementsEmpty, textAlign: TextAlign.center),
          ),
        for (final operation in visible) _movementCard(context, ref, operation, itemById, l10n),
      ],
    );
  }

  Widget _movementCard(
    BuildContext context,
    WidgetRef ref,
    FinancialOperation operation,
    Map<String, BudgetItem> itemById,
    AppLocalizations l10n,
  ) {
    final linkedItem = operation.budgetItemId == null ? null : itemById[operation.budgetItemId];
    final amount = operation.recognizedIncomeMinor + operation.recognizedExpenseMinor;
    final canAssociate =
        operation.status == OperationStatus.confirmed &&
        operation.projectionDirection == 1 &&
        operation.reversalOf == null &&
        (operation.type == OperationType.income ||
            operation.type == OperationType.expense ||
            operation.type == OperationType.expenseRefund) &&
        (operation.debtCommandId == null ||
            operation.debtKind == 'purchase' ||
            operation.debtKind == 'newChargePaid');
    final subtitle = operation.projectionDirection == -1 || operation.reversalOf != null
        ? l10n.budgetMovementReversal
        : operation.budgetItemId == null
        ? l10n.budgetMovementUnassociated
        : linkedItem == null || !linkedItem.isActive
        ? l10n.budgetMovementArchivedLink(linkedItem?.description ?? operation.budgetItemId!)
        : l10n.budgetMovementLinkedTo(linkedItem.description);
    final icon = operation.type == OperationType.income ? Icons.south_west : Icons.north_east;
    final signedAmount = amount;
    return Card(
      key: ValueKey('budget_operation_${operation.id}'),
      child: ListTile(
        leading: Icon(
          icon,
          color: signedAmount < 0
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          operation.description.isEmpty
              ? operation.type == OperationType.income
                    ? l10n.income
                    : l10n.expense
              : operation.description,
        ),
        subtitle: Text(
          '${DateFormat.yMMMd(widget.locale).format(operation.occurredAt)} · $subtitle',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.formatMinor(
                signedAmount,
                widget.budget.currency,
                locale: widget.locale,
              ),
            ),
            if (canAssociate)
              IconButton(
                key: ValueKey('budget_operation_associate_${operation.id}'),
                tooltip: l10n.budgetMovementAssociation,
                onPressed: _savingOperationIds.contains(operation.id)
                    ? null
                    : () => _chooseAssociation(context, ref, operation),
                icon: _savingOperationIds.contains(operation.id)
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_outlined),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _chooseAssociation(
    BuildContext context,
    WidgetRef ref,
    FinancialOperation operation,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selectedItemId = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              key: const ValueKey('budget_association_none'),
              leading: const Icon(Icons.link_off_outlined),
              title: Text(l10n.budgetMovementClearAssociation),
              onTap: () => Navigator.pop(sheetContext, ''),
            ),
            for (final item in widget.items.where((item) => item.isActive))
              ListTile(
                key: ValueKey('budget_association_item_${item.id}'),
                leading: const Icon(Icons.event_note_outlined),
                title: Text(item.description),
                subtitle: Text(
                  CurrencyFormatter.formatMinor(
                    item.amountMinor,
                    widget.budget.currency,
                    locale: widget.locale,
                  ),
                ),
                onTap: () => Navigator.pop(sheetContext, item.id),
              ),
          ],
        ),
      ),
    );
    if (selectedItemId == null || !context.mounted) return;
    final currentItem = operation.budgetItemId;
    final nextItem = selectedItemId.isEmpty ? null : selectedItemId;
    if (nextItem == currentItem) return;
    setState(() => _savingOperationIds.add(operation.id));
    try {
      await ref
          .read(canonicalActionsProvider)
          .setOperationBudgetItem(
            widget.userId,
            operationId: operation.id,
            expectedRevision: operation.revision,
            budgetId: nextItem == null ? null : widget.budget.id,
            itemId: nextItem,
          );
      if (!context.mounted) return;
      final key = (
        userId: widget.userId,
        budgetId: widget.budget.id,
        categoryId: widget.budget.categoryId,
        monthKey: widget.budget.monthKey,
        currency: widget.budget.currency,
        flowType: widget.budget.flowType.value,
      );
      ref
        ..invalidate(canonicalBudgetCategoryOperationsProvider(key))
        ..invalidate(
          canonicalFinanceRepositoryItemsProvider((
            userId: widget.userId,
            budgetId: widget.budget.id,
          )),
        )
        ..invalidate(canonicalBudgetProvider((userId: widget.userId, budgetId: widget.budget.id)))
        ..invalidate(
          canonicalBudgetsProvider((userId: widget.userId, monthKey: widget.budget.monthKey)),
        );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.budgetMovementAssociationSaved)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.budgetMovementAssociationFailed)),
      );
    } finally {
      if (mounted) setState(() => _savingOperationIds.remove(operation.id));
    }
  }
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
    required this.planned,
    required this.actual,
    required this.status,
    required this.isExceeded,
    required this.progress,
  });

  final String planned;
  final String actual;
  final String status;
  final bool isExceeded;
  final double progress;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 2,
            children: [
              Text(
                actual,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                planned,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isExceeded ? Theme.of(context).colorScheme.error : context.appColors.income,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Semantics(
            key: const ValueKey('budget_summary_progress'),
            label: '$planned · $actual · $status',
            value: '${(progress * 100).round()}%',
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              color: isExceeded
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BudgetItemCard extends StatelessWidget {
  const _BudgetItemCard({
    required this.item,
    required this.currency,
    required this.locale,
    this.canRemove = false,
    this.onEdit,
    this.onRemove,
    this.archived = false,
    this.userId,
    this.budgetId,
  });

  final BudgetItem item;
  final String currency;
  final String locale;
  final bool canRemove;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final bool archived;
  final String? userId;
  final String? budgetId;

  @override
  Widget build(BuildContext context) => archived ? _buildArchived(context) : _buildActive(context);

  Widget _buildActive(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actual = CurrencyFormatter.formatMinor(
      item.actualAmountMinor,
      currency,
      locale: locale,
    );
    final planned = CurrencyFormatter.formatMinor(item.amountMinor, currency, locale: locale);
    final progress = item.amountMinor <= 0
        ? 0.0
        : (item.actualAmountMinor / item.amountMinor).clamp(0.0, 1.0);
    final isExceeded = item.actualAmountMinor > item.amountMinor;
    return Card(
      key: ValueKey('budget_item_row_${item.id}'),
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              label: l10n.planningOpenDetail(item.description),
              button: true,
              child: InkWell(
                onTap: userId != null && budgetId != null
                    ? () => context.push('/budgets/$budgetId/items/${item.id}')
                    : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.description,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$planned · ${l10n.day.toLowerCase()} ${item.dayOfMonth}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.budgetItemActual(actual),
                        key: ValueKey('budget_item_actual_${item.id}'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isExceeded
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Semantics(
                        label: '${l10n.budgetItemActual(actual)} · ${l10n.planned(planned)}',
                        value: '${(progress * 100).round()}%',
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          color: isExceeded
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (userId != null && budgetId != null)
            PopupMenuButton<_BudgetItemAction>(
              key: ValueKey('budget_item_actions_${item.id}'),
              tooltip: '${l10n.moreOptions}: ${item.description}',
              onSelected: (action) {
                switch (action) {
                  case _BudgetItemAction.edit:
                    onEdit?.call();
                    break;
                  case _BudgetItemAction.remove:
                    onRemove?.call();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  key: ValueKey('budget_item_edit_${item.id}'),
                  value: _BudgetItemAction.edit,
                  child: Text(l10n.budgetEditAction),
                ),
                if (canRemove)
                  PopupMenuItem(
                    key: ValueKey('budget_item_remove_${item.id}'),
                    value: _BudgetItemAction.remove,
                    child: Text(l10n.budgetRemoveItem),
                  ),
              ],
              icon: const Icon(Icons.more_vert),
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildArchived(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Theme.of(context).colorScheme.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: userId != null && budgetId != null
                ? () => context.push('/budgets/$budgetId/items/${item.id}')
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                item.description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${CurrencyFormatter.formatMinor(item.amountMinor, currency, locale: locale)} · ${AppLocalizations.of(context).day.toLowerCase()} ${item.dayOfMonth}',
            style:
                Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context).budgetItemActual(
              CurrencyFormatter.formatMinor(item.actualAmountMinor, currency, locale: locale),
            ),
            key: ValueKey('budget_item_actual_${item.id}'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: item.actualAmountMinor > item.amountMinor
                  ? Theme.of(context).colorScheme.error
                  : context.appColors.income,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (archived) ...[
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).budgetItemArchived,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (userId != null && budgetId != null) ...[
              const SizedBox(height: 8),
              _ArchivedBudgetItemMovements(
                userId: userId!,
                budgetId: budgetId!,
                itemId: item.id,
                currency: currency,
                locale: locale,
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

enum _BudgetItemAction { edit, remove }

class _ArchivedBudgetItemMovements extends ConsumerWidget {
  const _ArchivedBudgetItemMovements({
    required this.userId,
    required this.budgetId,
    required this.itemId,
    required this.currency,
    required this.locale,
  });

  final String userId;
  final String budgetId;
  final String itemId;
  final String currency;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final movements = ref.watch(
      canonicalBudgetItemOperationsProvider((
        userId: userId,
        budgetId: budgetId,
        itemId: itemId,
      )),
    );
    return movements.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, _) => Text(l10n.genericError),
      data: (items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.budgetItemLinkedMovements,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (items.isEmpty)
            Text(l10n.budgetItemNoLinkedMovements)
          else
            for (final operation in items)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${operation.description} · ${CurrencyFormatter.formatMinor(operation.amountMinor, currency, locale: locale)} · ${switch (operation.status) {
                    OperationStatus.confirmed => l10n.budgetLinkedMovementConfirmed,
                    OperationStatus.pending => l10n.budgetLinkedMovementPending,
                    OperationStatus.rejected => l10n.budgetLinkedMovementRejected,
                  }}',
                  key: ValueKey('budget_linked_operation_${operation.id}'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _BudgetDetailError extends StatelessWidget {
  const _BudgetDetailError({required this.message, required this.onRetry, this.retryLabel});

  final String message;
  final VoidCallback onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: Text(retryLabel ?? AppLocalizations.of(context).retry),
          ),
        ],
      ),
    ),
  );
}
