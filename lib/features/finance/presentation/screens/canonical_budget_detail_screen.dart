import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/budget_flow_type.dart';
import '../../domain/entities/budget_item.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/usecases/calculate_budget_tracking.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalBudgetDetailScreen extends ConsumerWidget {
  const CanonicalBudgetDetailScreen({super.key, required this.budgetId});

  final String budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));

    final budgetKey = (userId: user.id, budgetId: budgetId);
    final budgetState = ref.watch(canonicalBudgetProvider(budgetKey));
    final itemsState = ref.watch(canonicalFinanceRepositoryItemsProvider(budgetKey));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: budgetState.when(
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
                onRetry: () => ref.invalidate(canonicalFinanceRepositoryItemsProvider(budgetKey)),
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
                ),
              ),
            );
          },
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
  });

  final Budget budget;
  final List<BudgetItem> items;
  final MonthlySummary? summary;
  final String userId;

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
    const calculator = CalculateBudgetTracking();
    final tracking = calculator(budget, const [], summary: summary);
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

    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('budget_detail_scroll'),
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
            children: [
              Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.blueDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                key: const ValueKey('budget_detail_back'),
                onPressed: () => context.pop(),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.chevron_left, size: 20),
                label: Text(l10n.budgetBackToBudgets),
              ),
              const SizedBox(height: 8),
              Text(
                categoryName,
                key: const ValueKey('budget_detail_category'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$typeLabel · $month · ${budget.currency}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              _BudgetSummaryCard(
                category: categoryName,
                typeAndMonth: '$typeLabel · $month',
                planned: l10n.planned(planned),
                actual: '$actualLabel · $actual',
                status: statusText,
                isExceeded: tracking.isExceeded,
                progress: progress,
              ),
              const SizedBox(height: 18),
              Text(
                l10n.budgetItemsHeading(items.length),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(l10n.genericError),
                ),
              for (final item in items) ...[
                _BudgetItemCard(
                  item: item,
                  currency: budget.currency,
                  locale: locale,
                  canRemove: items.length > 1,
                  onEdit: () => context.push(
                    '/budgets/${budget.id}/items/${item.id}/edit',
                    extra: item,
                  ),
                  onRemove: () => _confirmRemoveItem(context, ref, item),
                ),
                const SizedBox(height: 10),
              ],
              if (items.length == 1)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  child: Text(
                    l10n.budgetLastItemMessage,
                    key: const ValueKey('budget_last_item_hint'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ),
              FilledButton(
                key: const ValueKey('budget_add_item_detail'),
                onPressed: () => context.push('/budgets/${budget.id}/items/new'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blueDark,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(l10n.budgetAddItem),
              ),
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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
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
      ref.invalidate(canonicalBudgetsProvider((userId: userId, monthKey: budget.monthKey)));
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
      await ref.read(canonicalActionsProvider).archiveBudget(userId, budget.id);
      if (!context.mounted) return;
      context.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.budgetArchiveSuccess)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.budgetDeleteFailed)));
    }
  }
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
    required this.category,
    required this.typeAndMonth,
    required this.planned,
    required this.actual,
    required this.status,
    required this.isExceeded,
    required this.progress,
  });

  final String category;
  final String typeAndMonth;
  final String planned;
  final String actual;
  final String status;
  final bool isExceeded;
  final double progress;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.line),
    ),
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            typeAndMonth,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 5),
          Text(
            planned,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            actual,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isExceeded ? Theme.of(context).colorScheme.error : AppColors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Semantics(
            label: '$planned · $actual · $status',
            value: '${(progress * 100).round()}%',
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.blueSoft,
              color: isExceeded ? Theme.of(context).colorScheme.error : AppColors.blueDark,
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
    required this.canRemove,
    required this.onEdit,
    required this.onRemove,
  });

  final BudgetItem item;
  final String currency;
  final String locale;
  final bool canRemove;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.line),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.navy),
                ),
                const SizedBox(height: 4),
                Text(
                  '${CurrencyFormatter.formatMinor(item.amountMinor, currency, locale: locale)} · ${AppLocalizations.of(context).day.toLowerCase()} ${item.dayOfMonth}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ItemAction(label: AppLocalizations.of(context).budgetEditAction, onPressed: onEdit),
          const SizedBox(width: 4),
          if (canRemove)
            _ItemAction(
              label: AppLocalizations.of(context).budgetRemoveItem,
              destructive: true,
              onPressed: onRemove,
            ),
        ],
      ),
    ),
  );
}

class _ItemAction extends StatelessWidget {
  const _ItemAction({required this.label, required this.onPressed, this.destructive = false});

  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: TextButton(
      key: ValueKey('budget_item_${destructive ? 'remove' : 'edit'}'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 48),
        foregroundColor: destructive ? Theme.of(context).colorScheme.error : AppColors.blueDark,
        backgroundColor: AppColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label),
    ),
  );
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

final canonicalFinanceRepositoryItemsProvider =
    StreamProvider.family<List<BudgetItem>, ({String userId, String budgetId})>(
      (ref, input) => ref
          .watch(canonicalFinanceRepositoryProvider)
          .watchBudgetItems(
            input.userId,
            input.budgetId,
          ),
    );
