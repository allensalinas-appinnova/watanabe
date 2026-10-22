import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/offline/pending_operation_queue.dart';
import '../../../../core/offline/sync_state.dart';
import '../../../../core/routing/global_fab_visibility.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/budget_flow_type.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/usecases/calculate_budget_tracking.dart';
import '../providers/canonical_finance_providers.dart';
import '../widgets/finance_category_icon.dart';
import '../widgets/finance_components.dart';
import '../widgets/sync_issue_localization.dart';

class CanonicalHomeScreen extends ConsumerWidget {
  const CanonicalHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    return session.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: Center(child: Text(AppLocalizations.of(context).genericError)),
      ),
      data: (user) {
        final l10n = AppLocalizations.of(context);
        if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));

        final accounts = ref.watch(canonicalAccountsProvider(user.id));
        final categories = ref.watch(canonicalCategoriesProvider(user.id));
        final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
        final operationsInput = (
          userId: user.id,
          cursor: null,
          monthKey: null,
          currency: null,
          type: null,
          accountIds: null,
          pageSize: 10,
        );
        final operations = ref.watch(canonicalOperationsPageProvider(operationsInput));
        final primaryCurrency = accounts.valueOrNull?.isNotEmpty == true
            ? accounts.valueOrNull!.first.currency
            : 'COP';
        final summaryInput = (
          userId: user.id,
          monthKey: monthKey,
          currency: primaryCurrency,
        );
        final summary = ref.watch(canonicalMonthlySummaryProvider(summaryInput));
        final budgetInput = (userId: user.id, monthKey: monthKey);
        final budgets = ref.watch(canonicalBudgetsProvider(budgetInput));
        final pending = ref.watch(pendingOperationsProvider).valueOrNull ?? const [];
        final amountsHidden = ref.watch(dashboardAmountsHiddenProvider);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            toolbarHeight: 52,
            titleSpacing: 24,
            title: Text(
              l10n.appTitle,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.blueDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                key: const ValueKey('home_more_menu'),
                tooltip: l10n.homeMenu,
                icon: const Icon(Icons.more_horiz, size: 26),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onSelected: (value) {
                  if (value == 'categories') context.push('/categories');
                  if (value == 'sign_out') {
                    ref.read(authControllerProvider.notifier).signOut();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'categories', child: Text(l10n.manageCategories)),
                  PopupMenuItem(value: 'sign_out', child: Text(l10n.signOut)),
                ],
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref
                ..invalidate(canonicalAccountsProvider(user.id))
                ..invalidate(canonicalCategoriesProvider(user.id))
                ..invalidate(canonicalMonthlySummaryProvider(summaryInput))
                ..invalidate(canonicalBudgetsProvider(budgetInput))
                ..invalidate(canonicalOperationsPageProvider(operationsInput));
            },
            child: GlobalFabScrollObserver(
              child: ListView(
                key: const ValueKey('home_dashboard_content'),
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 104),
                children: [
                  Text(
                    l10n.dashboardTitle,
                    key: const ValueKey('home_dashboard_title'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.homeMonthlySummary(
                      DateFormat.yMMMM(
                        Localizations.localeOf(context).toString(),
                      ).format(DateTime.now()),
                      primaryCurrency,
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  if (pending.isNotEmpty) ...[
                    _PendingOperationsCard(
                      pending: pending,
                      onRetry: () => ref.read(canonicalActionsProvider).syncPending(user.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                  accounts.when(
                    loading: () => const _HomeSkeleton(height: 116),
                    error: (_, _) => _ErrorCard(
                      message: l10n.genericError,
                      onRetry: () => ref.invalidate(canonicalAccountsProvider(user.id)),
                    ),
                    data: (items) => _BalanceCard(
                      accounts: items,
                      amountsHidden: amountsHidden,
                      onToggleVisibility: () => ref
                          .read(dashboardAmountsHiddenProvider.notifier)
                          .setHidden(!amountsHidden),
                    ),
                  ),
                  const SizedBox(height: 16),
                  summary.when(
                    loading: () => const _HomeSkeleton(height: 92, lines: 2),
                    error: (_, _) => _ErrorCard(
                      message: l10n.genericError,
                      onRetry: () => ref.invalidate(canonicalMonthlySummaryProvider(summaryInput)),
                    ),
                    data: (value) => _MonthlySummaryCards(
                      incomeMinor: value?.incomeMinor ?? 0,
                      expenseMinor: value?.expenseMinor ?? 0,
                      currency: primaryCurrency,
                      amountsHidden: amountsHidden,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FinanceSectionHeading(title: l10n.homeBudgetTitle),
                  const SizedBox(height: 8),
                  budgets.when(
                    loading: () => const _HomeSkeleton(height: 96, lines: 2),
                    error: (_, _) => _ErrorCard(
                      message: l10n.genericError,
                      onRetry: () => ref.invalidate(canonicalBudgetsProvider(budgetInput)),
                    ),
                    data: (items) {
                      final matching = items.where((item) => item.currency == primaryCurrency);
                      final budget = matching.isEmpty ? null : matching.first;
                      if (budget == null) {
                        return _EmptyBudgetPreview(
                          message: l10n.budgetEmptyTitle,
                          onTap: () => context.go('/budgets'),
                        );
                      }
                      return summary.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => _ErrorCard(
                          message: l10n.genericError,
                          onRetry: () =>
                              ref.invalidate(canonicalMonthlySummaryProvider(summaryInput)),
                        ),
                        data: (value) => _BudgetPreview(
                          budget: budget,
                          category: _categoryName(
                            categories.valueOrNull ?? const [],
                            budget.categoryId,
                          ),
                          summary: value,
                          onTap: () => context.push('/budgets/${budget.id}'),
                          amountsHidden: amountsHidden,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  FinanceSectionHeading(
                    title: l10n.recentActivity,
                    action: TextButton(
                      key: const ValueKey('home_view_all_activity'),
                      onPressed: () => context.go('/activity'),
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      child: Text(l10n.seeAll),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (categories.hasError)
                    _ErrorCard(
                      message: l10n.genericError,
                      onRetry: () => ref.invalidate(canonicalCategoriesProvider(user.id)),
                    ),
                  operations.when(
                    loading: () => const _HomeSkeleton(height: 150, lines: 3),
                    error: (_, _) => _ErrorCard(
                      message: l10n.genericError,
                      onRetry: () =>
                          ref.invalidate(canonicalOperationsPageProvider(operationsInput)),
                    ),
                    data: (page) => page.items.isEmpty
                        ? Card(
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(l10n.noTransactions),
                            ),
                          )
                        : Column(
                            children: page.items.take(3).map((item) {
                              FinanceCategory? category;
                              for (final value
                                  in categories.valueOrNull ?? const <FinanceCategory>[]) {
                                if (value.id == item.categoryId) category = value;
                              }
                              return _OperationTile(
                                operation: item,
                                category: category,
                                accounts: accounts.valueOrNull ?? const [],
                                amountsHidden: amountsHidden,
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.accounts,
    required this.amountsHidden,
    required this.onToggleVisibility,
  });

  final List<FinanceAccount> accounts;
  final bool amountsHidden;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<FinanceAccount>>{};
    for (final account in accounts.where((item) => item.includeInDashboard)) {
      groups.putIfAbsent(account.currency, () => []).add(account);
    }
    if (groups.isEmpty) {
      for (final account in accounts) {
        groups.putIfAbsent(account.currency, () => []).add(account);
      }
    }
    return Container(
      key: const ValueKey('home_balance_card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).homeTotalBalance.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFD8E7F8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('home_toggle_amount_visibility'),
                tooltip: amountsHidden
                    ? AppLocalizations.of(context).showBalances
                    : AppLocalizations.of(context).hideBalances,
                onPressed: onToggleVisibility,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(
                  amountsHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final entry in groups.entries) ...[
            Text(
              amountsHidden
                  ? '••••••'
                  : _money(
                      entry.value.fold<int>(0, (sum, account) => sum + account.currentBalanceMinor),
                      entry.key,
                    ),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              entry.value
                  .map(
                    (account) => amountsHidden
                        ? '${account.name}: ••••••'
                        : '${account.name}: ${_money(account.currentBalanceMinor, entry.key)}',
                  )
                  .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFD8E7F8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthlySummaryCards extends StatelessWidget {
  const _MonthlySummaryCards({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.currency,
    required this.amountsHidden,
  });

  final int incomeMinor;
  final int expenseMinor;
  final String currency;
  final bool amountsHidden;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _SummaryCard(
          label: AppLocalizations.of(context).income,
          value: amountsHidden ? '••••••' : _money(incomeMinor, currency),
          color: AppColors.green,
          key: const ValueKey('home_income_summary'),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: _SummaryCard(
          label: AppLocalizations.of(context).expense,
          value: amountsHidden ? '••••••' : _money(expenseMinor, currency),
          color: const Color(0xFFC62828),
          key: const ValueKey('home_expense_summary'),
        ),
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.color, super.key});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 82),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _BudgetPreview extends StatelessWidget {
  const _BudgetPreview({
    required this.budget,
    required this.category,
    required this.summary,
    required this.onTap,
    required this.amountsHidden,
  });

  final Budget budget;
  final String category;
  final MonthlySummary? summary;
  final VoidCallback onTap;
  final bool amountsHidden;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tracking = const CalculateBudgetTracking()(budget, const [], summary: summary);
    final ratio = budget.plannedAmountMinor == 0
        ? 0.0
        : (tracking.actualMinor / budget.plannedAmountMinor).clamp(0.0, 1.0);
    final actualLabel = budget.flowType == BudgetFlowType.income
        ? l10n.budgetReceived
        : l10n.budgetSpent;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey('home_budget_preview'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$category · ${amountsHidden ? '••••••' : _money(budget.plannedAmountMinor, budget.currency)}',
              ),
              const SizedBox(height: 6),
              Text(
                amountsHidden
                    ? '$actualLabel · •••••• · ${l10n.remaining('••••••')}'
                    : '$actualLabel · ${_money(tracking.actualMinor, budget.currency)} · '
                          '${l10n.remaining(_money(tracking.remainingMinor, budget.currency))}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  key: const ValueKey('home_budget_progress'),
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: AppColors.blueSoft,
                  color: AppColors.blueDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBudgetPreview extends StatelessWidget {
  const _EmptyBudgetPreview({required this.message, required this.onTap});

  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(message, style: Theme.of(context).textTheme.bodySmall),
      ),
    ),
  );
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({
    required this.operation,
    required this.category,
    required this.accounts,
    required this.amountsHidden,
  });

  final FinancialOperation operation;
  final FinanceCategory? category;
  final List<FinanceAccount> accounts;
  final bool amountsHidden;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isIncome = operation.type == OperationType.income;
    final isTransfer = operation.type == OperationType.transfer;
    final source = _findAccount(accounts, operation.sourceAccountId);
    final destination = _findAccount(accounts, operation.destinationAccountId);
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(
      operation.occurredAt.toLocal(),
    );
    final title = isTransfer
        ? '${source?.name ?? l10n.sourceAccount} → ${destination?.name ?? l10n.destinationAccount}'
        : operation.description.isEmpty
        ? (category?.customName ?? category?.id ?? (isIncome ? l10n.income : l10n.expense))
        : operation.description;
    final subtitle = isTransfer
        ? '${l10n.transferOperationLabel} · $date'
        : '${isIncome ? l10n.income : l10n.expense} · $date';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isTransfer
              ? null
              : () => context.push('/operations/${operation.id}/edit', extra: operation),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                if (isTransfer)
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.blueSoft,
                    child: Icon(Icons.swap_horiz, color: AppColors.blueDark, size: 18),
                  )
                else
                  FinanceCategoryIcon(
                    iconId: category?.icon,
                    semanticLabel: category?.customName ?? category?.id,
                    size: 32,
                    iconSize: 18,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    amountsHidden
                        ? '••••••'
                        : '${isIncome
                              ? '+'
                              : isTransfer
                              ? ''
                              : '−'}${_money(operation.amountMinor, operation.currency)}',
                    maxLines: 1,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isIncome ? AppColors.green : AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingOperationsCard extends StatelessWidget {
  const _PendingOperationsCard({required this.pending, required this.onRetry});

  final List<PendingOperation> pending;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: const Icon(Icons.sync_problem),
          title: Text(
            pending.any((item) => item.status == 'rejected')
                ? l10n.offlineRejected
                : l10n.offlinePending,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final operation in pending.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_pendingDescription(operation.operationType, operation.payload, l10n)),
                      if (SyncFailureInfo.parse(operation.lastError) case final issue?) ...[
                        Text(syncIssueMessage(l10n, issue)),
                        if (issue.technicalCode case final code?)
                          SelectableText(l10n.syncDiagnosticCode(code)),
                      ],
                    ],
                  ),
                ),
              if (pending.length > 3) Text('+${pending.length - 3}'),
            ],
          ),
          trailing: TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: onRetry, child: Text(AppLocalizations.of(context).retry)),
          ),
        ],
      ),
    ),
  );
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton({required this.height, this.lines = 1});

  final double height;
  final int lines;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    child: SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            lines,
            (index) => FractionallySizedBox(
              widthFactor: index == lines - 1 ? .52 : .78,
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String _categoryName(List<FinanceCategory> categories, String id) {
  for (final category in categories) {
    if (category.id == id) return category.customName ?? category.id;
  }
  return id;
}

FinanceAccount? _findAccount(List<FinanceAccount> accounts, String? id) {
  if (id == null) return null;
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
}

String _money(int minor, String currency) => CurrencyFormatter.formatMinor(minor, currency);

String _pendingDescription(String operationType, String payload, AppLocalizations l10n) {
  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final rawType = operationType == 'transfer' ? 'transfer' : data['type'] as String?;
    final typeLabel = switch (rawType) {
      'income' => l10n.income,
      'expense' => l10n.expense,
      _ => l10n.transfer,
    };
    final description = data['description'] as String?;
    return description == null || description.isEmpty ? typeLabel : '$typeLabel · $description';
  } catch (_) {
    return operationType;
  }
}
