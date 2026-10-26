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
import '../../../coach/presentation/widgets/coach_next_step_card.dart';
import '../../../debts/domain/recorded_position.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/budget_flow_type.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/entities/home_dashboard_preferences.dart';
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
        final profile = ref.watch(canonicalUserProfileProvider(user.id)).valueOrNull;
        final homePreferences =
            profile?.homeDashboardPreferences ?? const HomeDashboardPreferences();
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
        ref.watch(
          homeInitialLoadProvider((
            userId: user.id,
            monthKey: monthKey,
            currency: primaryCurrency,
          )),
        );
        final pending = ref.watch(pendingOperationsProvider).valueOrNull ?? const [];
        final amountsHidden = ref.watch(dashboardAmountsHiddenProvider);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      color: Theme.of(context).colorScheme.onSurface,
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (pending.isNotEmpty) ...[
                    _PendingOperationsCard(
                      pending: pending,
                      onRetry: () => ref.read(canonicalActionsProvider).syncPending(user.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (homePreferences.shows(HomeDashboardWidget.coachNextStep))
                    CoachNextStepCard(userId: user.id, timeZone: profile?.timeZone ?? 'UTC'),
                  if (homePreferences.shows(HomeDashboardWidget.debtCommitments))
                    _DebtCommitmentsHomeCard(
                      userId: user.id,
                      amountsHidden: amountsHidden,
                    ),
                  Padding(
                    key: const ValueKey('home_debt_account_shortcuts'),
                    padding: const EdgeInsets.only(top: 12, bottom: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: const ValueKey('home_credit_cards_shortcut'),
                          onPressed: () => context.push('/accounts?section=cards'),
                          icon: const Icon(Icons.credit_card_outlined),
                          label: Text(l10n.debtCards),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('home_loans_shortcut'),
                          onPressed: () => context.push('/accounts?section=loans'),
                          icon: const Icon(Icons.account_balance_outlined),
                          label: Text(l10n.debtLoans),
                        ),
                      ],
                    ),
                  ),
                  if (homePreferences.shows(HomeDashboardWidget.totalBalance))
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
                  if (homePreferences.shows(HomeDashboardWidget.incomeSummary) ||
                      homePreferences.shows(HomeDashboardWidget.expenseSummary)) ...[
                    const SizedBox(height: 16),
                    summary.when(
                      loading: () => const _HomeSkeleton(height: 92, lines: 2),
                      error: (_, _) => _ErrorCard(
                        message: l10n.genericError,
                        onRetry: () =>
                            ref.invalidate(canonicalMonthlySummaryProvider(summaryInput)),
                      ),
                      data: (value) => _MonthlySummaryCards(
                        incomeMinor: value?.incomeMinor ?? 0,
                        expenseMinor: value?.expenseMinor ?? 0,
                        currency: primaryCurrency,
                        amountsHidden: amountsHidden,
                        showIncome: homePreferences.shows(HomeDashboardWidget.incomeSummary),
                        showExpense: homePreferences.shows(HomeDashboardWidget.expenseSummary),
                      ),
                    ),
                  ],
                  if (homePreferences.shows(HomeDashboardWidget.expenseBudgetRatio) ||
                      homePreferences.shows(HomeDashboardWidget.incomeBudgetRatio) ||
                      (budgets.valueOrNull?.any(
                            (budget) => homePreferences.showsBudget(budget.categoryId),
                          ) ??
                          true)) ...[
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
                        final matching = items
                            .where((item) => item.currency == primaryCurrency)
                            .toList(growable: false);
                        final visibleBudgets = matching
                            .where((budget) => homePreferences.showsBudget(budget.categoryId))
                            .toList(growable: false);
                        final hasComparisons =
                            homePreferences.shows(
                              HomeDashboardWidget.expenseBudgetRatio,
                            ) ||
                            homePreferences.shows(HomeDashboardWidget.incomeBudgetRatio);
                        if (matching.isEmpty || (visibleBudgets.isEmpty && !hasComparisons)) {
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
                          data: (value) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (hasComparisons)
                                _BudgetComparisonCards(
                                  budgets: matching,
                                  incomeMinor: value?.incomeMinor ?? 0,
                                  expenseMinor: value?.expenseMinor ?? 0,
                                  currency: primaryCurrency,
                                  amountsHidden: amountsHidden,
                                  showExpense: homePreferences.shows(
                                    HomeDashboardWidget.expenseBudgetRatio,
                                  ),
                                  showIncome: homePreferences.shows(
                                    HomeDashboardWidget.incomeBudgetRatio,
                                  ),
                                ),
                              if (visibleBudgets.isNotEmpty) const SizedBox(height: 8),
                              for (final budget in visibleBudgets) ...[
                                _BudgetPreview(
                                  key: ValueKey('home_budget_preview_${budget.id}'),
                                  budget: budget,
                                  category: _categoryName(
                                    categories.valueOrNull ?? const [],
                                    budget.categoryId,
                                  ),
                                  summary: value,
                                  onTap: () => context.push('/budgets/${budget.id}'),
                                  amountsHidden: amountsHidden,
                                ),
                                if (budget != visibleBudgets.last) const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  if (homePreferences.shows(HomeDashboardWidget.recentActivity)) ...[
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
                  ],
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
                        ? HomeRecentActivityEmptyState(message: l10n.noTransactions)
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

class _DebtCommitmentsHomeCard extends ConsumerWidget {
  const _DebtCommitmentsHomeCard({required this.userId, required this.amountsHidden});

  final String userId;
  final bool amountsHidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final commitments = ref.watch(debtCommitmentsProvider(userId));
    final links = ref.watch(debtCommitmentPaymentsProvider(userId));
    final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
    return commitments.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 12),
        child: _HomeSkeleton(height: 96, lines: 2),
      ),
      error: (_, _) => _ErrorCard(
        message: l10n.genericError,
        onRetry: () {
          ref
            ..invalidate(debtCommitmentsProvider(userId))
            ..invalidate(debtCommitmentPaymentsProvider(userId));
        },
      ),
      data: (allPlans) {
        if (links.hasError) {
          return _ErrorCard(
            message: l10n.genericError,
            onRetry: () => ref.invalidate(debtCommitmentPaymentsProvider(userId)),
          );
        }
        if (links.isLoading) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: _HomeSkeleton(height: 96, lines: 2),
          );
        }
        final plans = allPlans.where((item) => item.dueDateFor(monthKey) != null).toList()
          ..sort(
            (left, right) => left.dueDateFor(monthKey)!.compareTo(right.dueDateFor(monthKey)!),
          );
        final paymentLinks = links.requireValue;
        final currencies = plans.map((plan) => plan.currency).toSet().toList()..sort();
        final nextDue = plans.where((plan) {
          final paid = paymentLinks
              .where((link) => link.commitmentId == plan.id && link.monthKey == monthKey)
              .fold<int>(0, (sum, link) => sum + link.amountMinor);
          return paid < plan.amountMinor;
        }).firstOrNull;
        return Card(
          key: const ValueKey('home_debt_commitments_card'),
          margin: const EdgeInsets.only(top: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.go('/budgets/debt-payments'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_note_outlined, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.debtCommitmentsTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (plans.isEmpty)
                    Text(l10n.debtCommitmentsEmpty)
                  else ...[
                    for (final currency in currencies)
                      Builder(
                        builder: (context) {
                          final currencyPlans = plans.where((plan) => plan.currency == currency);
                          final planned = currencyPlans.fold<int>(
                            0,
                            (sum, plan) => sum + plan.amountMinor,
                          );
                          final paid = currencyPlans.fold<int>(
                            0,
                            (sum, plan) =>
                                sum +
                                paymentLinks
                                    .where(
                                      (link) =>
                                          link.commitmentId == plan.id && link.monthKey == monthKey,
                                    )
                                    .fold<int>(0, (amount, link) => amount + link.amountMinor),
                          );
                          return Text(
                            '$currency · ${l10n.debtCommitmentRemaining}: ${amountsHidden ? '••••' : _money((planned - paid).clamp(0, planned), currency)}',
                          );
                        },
                      ),
                    if (nextDue != null)
                      Text(
                        '${l10n.debtCommitmentNextDue}: ${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(nextDue.dueDateFor(monthKey)!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class HomeRecentActivityEmptyState extends StatelessWidget {
  const HomeRecentActivityEmptyState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('home_empty_activity'),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(message),
    ),
  );
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
    final balanceColors = context.appColors;
    final groups = <String, List<FinanceAccount>>{};
    for (final account in accounts.where(
      (item) => item.status == 'active' && item.includeInDashboard && !item.isDebt,
    )) {
      groups.putIfAbsent(account.currency, () => []).add(account);
    }
    return Container(
      key: const ValueKey('home_balance_card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: balanceColors.balanceCardBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (accounts.any((a) => a.isDebt)
                          ? AppLocalizations.of(context).debtMoney
                          : AppLocalizations.of(context).homeTotalBalance)
                      .toUpperCase(),
                  key: const ValueKey('home_balance_label'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: balanceColors.balanceCardMuted,
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
                  color: balanceColors.balanceCardForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (groups.isEmpty)
            Text(
              AppLocalizations.of(context).homeNoAccountsIncluded,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: balanceColors.balanceCardForeground,
              ),
            ),
          for (final entry in groups.entries) ...[
            Text(
              amountsHidden
                  ? '••••••'
                  : _money(
                      entry.value.fold<int>(0, (sum, account) => sum + account.currentBalanceMinor),
                      entry.key,
                    ),
              key: ValueKey('home_balance_amount_${entry.key}'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: balanceColors.balanceCardForeground,
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
                color: balanceColors.balanceCardMuted,
              ),
            ),
          ],
          if (accounts.any((a) => a.isDebt && a.includeInDashboard)) ...[
            Divider(color: balanceColors.balanceCardForeground.withValues(alpha: 0.24)),
            for (final entry in RecordedPosition.byCurrency(accounts).entries) ...[
              for (final row in [
                (AppLocalizations.of(context).debtRegistered, entry.value.debtMinor),
                (AppLocalizations.of(context).debtCreditBalance, entry.value.cardCreditMinor),
                (AppLocalizations.of(context).debtPosition, entry.value.netMinor),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    children: [
                      Text(
                        '${row.$1} · ${entry.key}',
                        style: TextStyle(color: balanceColors.balanceCardForeground),
                      ),
                      Text(
                        amountsHidden ? '••••••' : _money(row.$2, entry.key),
                        style: TextStyle(
                          color: balanceColors.balanceCardForeground,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            Text(
              AppLocalizations.of(context).debtPositionNote,
              style: TextStyle(color: balanceColors.balanceCardMuted),
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
    required this.showIncome,
    required this.showExpense,
  });

  final int incomeMinor;
  final int expenseMinor;
  final String currency;
  final bool amountsHidden;
  final bool showIncome;
  final bool showExpense;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (showIncome)
        Expanded(
          child: _SummaryCard(
            label: AppLocalizations.of(context).income,
            value: amountsHidden ? '••••••' : _money(incomeMinor, currency),
            color: context.appColors.income,
            key: const ValueKey('home_income_summary'),
          ),
        ),
      if (showIncome && showExpense) const SizedBox(width: 14),
      if (showExpense)
        Expanded(
          child: _SummaryCard(
            label: AppLocalizations.of(context).expense,
            value: amountsHidden ? '••••••' : _money(expenseMinor, currency),
            color: context.appColors.expense,
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
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
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
    super.key,
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
    final statusColor = tracking.isExceeded ? const Color(0xFFC73338) : context.appColors.income;
    final actualLabel = budget.flowType == BudgetFlowType.income
        ? l10n.budgetReceived
        : l10n.budgetSpent;
    final remainingLabel = tracking.isExceeded
        ? l10n.exceeded(_money(-tracking.remainingMinor, budget.currency))
        : l10n.remaining(_money(tracking.remainingMinor, budget.currency));
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                '$actualLabel · ${amountsHidden ? '••••••' : _money(tracking.actualMinor, budget.currency)}',
                key: ValueKey('home_budget_actual_${budget.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                amountsHidden
                    ? tracking.isExceeded
                          ? l10n.exceeded('••••••')
                          : l10n.remaining('••••••')
                    : remainingLabel,
                key: ValueKey('home_budget_remaining_${budget.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontWeight: tracking.isExceeded ? FontWeight.w600 : null,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  key: ValueKey('home_budget_progress_${budget.id}'),
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  color: tracking.isExceeded
                      ? const Color(0xFFC73338)
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetComparisonCards extends StatelessWidget {
  const _BudgetComparisonCards({
    required this.budgets,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.currency,
    required this.amountsHidden,
    required this.showExpense,
    required this.showIncome,
  });

  final List<Budget> budgets;
  final int incomeMinor;
  final int expenseMinor;
  final String currency;
  final bool amountsHidden;
  final bool showExpense;
  final bool showIncome;

  @override
  Widget build(BuildContext context) {
    final plannedIncome = budgets
        .where((budget) => budget.flowType == BudgetFlowType.income)
        .fold<int>(0, (total, budget) => total + budget.plannedAmountMinor);
    final plannedExpense = budgets
        .where((budget) => budget.flowType == BudgetFlowType.expense)
        .fold<int>(0, (total, budget) => total + budget.plannedAmountMinor);
    final cards = <Widget>[
      if (showExpense)
        _BudgetComparisonCard(
          title: AppLocalizations.of(context).homeExpenseVsBudget,
          actualMinor: expenseMinor,
          plannedMinor: plannedExpense,
          currency: currency,
          amountsHidden: amountsHidden,
          isExpense: true,
        ),
      if (showIncome)
        _BudgetComparisonCard(
          title: AppLocalizations.of(context).homeIncomeVsBudget,
          actualMinor: incomeMinor,
          plannedMinor: plannedIncome,
          currency: currency,
          amountsHidden: amountsHidden,
          isExpense: false,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (cards.length == 1) return cards.single;
        if (constraints.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ],
          );
        }
        return Column(
          children: [cards[0], const SizedBox(height: 8), cards[1]],
        );
      },
    );
  }
}

class _BudgetComparisonCard extends StatelessWidget {
  const _BudgetComparisonCard({
    required this.title,
    required this.actualMinor,
    required this.plannedMinor,
    required this.currency,
    required this.amountsHidden,
    required this.isExpense,
  });

  final String title;
  final int actualMinor;
  final int plannedMinor;
  final String currency;
  final bool amountsHidden;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasBudget = plannedMinor > 0;
    final ratio = hasBudget ? actualMinor / plannedMinor : 0.0;
    final appColors = context.appColors;
    final statusColor = isExpense
        ? !hasBudget
              ? Theme.of(context).colorScheme.primary
              : ratio > 1
              ? appColors.expense
              : ratio >= 0.8
              ? appColors.warning
              : appColors.positive
        : !hasBudget
        ? Theme.of(context).colorScheme.primary
        : ratio >= 1
        ? appColors.income
        : ratio >= 0.8
        ? appColors.warning
        : appColors.expense;
    final locale = Localizations.localeOf(context).toString();
    final percentage = NumberFormat.percentPattern(locale).format(ratio);

    return Container(
      key: ValueKey(isExpense ? 'home_expense_budget_ratio' : 'home_income_budget_ratio'),
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            amountsHidden
                ? '••%'
                : hasBudget
                ? percentage
                : '—',
            key: ValueKey(isExpense ? 'home_expense_budget_percent' : 'home_income_budget_percent'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasBudget
                ? l10n.homeBudgetComparisonDetails(
                    amountsHidden ? '••••••' : _money(actualMinor, currency),
                    amountsHidden ? '••••••' : _money(plannedMinor, currency),
                  )
                : l10n.homeNoBudgetForFlow,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: hasBudget ? ratio.clamp(0.0, 1.0) : 0,
              minHeight: 6,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              color: statusColor,
            ),
          ),
        ],
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
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
        ? operation.type == OperationType.unallocatedDebtPayment
              ? l10n.unallocatedPaymentStatus
              : (category?.customName ?? category?.id ?? (isIncome ? l10n.income : l10n.expense))
        : operation.description;
    final subtitle = operation.type == OperationType.expenseRefund
        ? '${l10n.debtRefund} · $date'
        : operation.type == OperationType.debtAdjustment
        ? '${l10n.debtAdjust} · $date'
        : operation.type == OperationType.unallocatedDebtPayment
        ? '${l10n.unallocatedPaymentStatus} · $date'
        : isTransfer
        ? '${l10n.transferOperationLabel} · $date'
        : '${isIncome ? l10n.income : l10n.expense} · $date';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: operation.debtAccountId != null
              ? () => context.push('/accounts/${operation.debtAccountId}/debt')
              : isTransfer
              ? null
              : () => context.push('/operations/${operation.id}/edit', extra: operation),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(14),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final amountWidth = (constraints.maxWidth * .42).clamp(96.0, 160.0);
                return Row(
                  children: [
                    if (isTransfer)
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.swap_horiz,
                          color: Theme.of(context).colorScheme.primary,
                          size: 18,
                        ),
                      )
                    else
                      FinanceCategoryIcon(
                        iconId: category?.icon,
                        colorValue: category?.colorValue,
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
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: amountWidth,
                      child: Text(
                        key: ValueKey('home_operation_amount_${operation.id}'),
                        amountsHidden
                            ? '••••••'
                            : '${(isIncome || operation.type == OperationType.expenseRefund) != (operation.projectionDirection == -1)
                                  ? '+'
                                  : isTransfer
                                  ? ''
                                  : '−'}${_money(operation.amountMinor, operation.currency)}',
                        maxLines: 1,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isIncome
                              ? context.appColors.income
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              },
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
    color: Theme.of(context).colorScheme.surface,
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
                  color: Theme.of(context).colorScheme.primaryContainer,
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
