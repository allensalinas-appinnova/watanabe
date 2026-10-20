import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/global_fab_visibility.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/budget_flow_type.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/usecases/calculate_budget_tracking.dart';
import '../providers/canonical_finance_providers.dart';
import '../widgets/budget_month_picker.dart';
import '../widgets/finance_category_icon.dart';

enum _BudgetFilter { all, expenses, income }

class CanonicalBudgetsScreen extends ConsumerStatefulWidget {
  const CanonicalBudgetsScreen({super.key});

  @override
  ConsumerState<CanonicalBudgetsScreen> createState() => _CanonicalBudgetsScreenState();
}

class _CanonicalBudgetsScreenState extends ConsumerState<CanonicalBudgetsScreen> {
  DateTime _selectedMonth = DateTime.now();
  _BudgetFilter _filter = _BudgetFilter.all;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    final l10n = AppLocalizations.of(context);
    if (user == null) {
      return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    }

    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);
    final budgetProvider = canonicalBudgetsProvider((userId: user.id, monthKey: monthKey));
    final budgetsState = ref.watch(budgetProvider);
    final categoriesState = ref.watch(canonicalCategoriesProvider(user.id));
    final budgets = budgetsState.valueOrNull;
    final currencies = budgets?.map((budget) => budget.currency).toSet() ?? const <String>{};
    final summaries = <String, AsyncValue<MonthlySummary?>>{
      for (final currency in currencies)
        currency: ref.watch(
          canonicalMonthlySummaryProvider(
            (userId: user.id, monthKey: monthKey, currency: currency),
          ),
        ),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: GlobalFabScrollObserver(
          child: budgetsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _LoadError(
              message: l10n.genericError,
              retryLabel: l10n.retry,
              onRetry: () => ref.invalidate(budgetProvider),
            ),
            data: (allBudgets) {
              if (summaries.values.any((summary) => summary.isLoading)) {
                return const Center(child: CircularProgressIndicator());
              }
              if (summaries.values.any((summary) => summary.hasError)) {
                return _LoadError(
                  message: l10n.genericError,
                  retryLabel: l10n.retry,
                  onRetry: () {
                    for (final currency in currencies) {
                      ref.invalidate(
                        canonicalMonthlySummaryProvider(
                          (userId: user.id, monthKey: monthKey, currency: currency),
                        ),
                      );
                    }
                  },
                );
              }

              final categories = categoriesState.valueOrNull ?? const <FinanceCategory>[];
              final visibleBudgets = allBudgets
                  .where(
                    (budget) => switch (_filter) {
                      _BudgetFilter.all => true,
                      _BudgetFilter.expenses => budget.flowType == BudgetFlowType.expense,
                      _BudgetFilter.income => budget.flowType == BudgetFlowType.income,
                    },
                  )
                  .toList();
              final isEmptyForMonth = allBudgets.isEmpty;

              return Stack(
                children: [
                  ListView(
                    key: const ValueKey('budget_monthly_list'),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 104),
                    children: [
                      Text(
                        l10n.appTitle,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.blueDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.budgetsTitle,
                        key: const ValueKey('budgets_title'),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.budgetsSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.budgetMonth.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          key: const ValueKey('budget_list_month'),
                          onPressed: _chooseMonth,
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.navy,
                            side: const BorderSide(color: AppColors.line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(DateFormat.yMMMM(_localeName).format(_selectedMonth)),
                              ),
                              const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _filters(l10n),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          key: const ValueKey('budgets_view_tracking'),
                          onPressed: () => context.push('/budgets/tracking?month=$monthKey'),
                          icon: const Icon(Icons.insights_outlined),
                          label: Text(l10n.viewBudgetTracking),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.budgetsForMonth,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isEmptyForMonth)
                        _EmptyBudgets(
                          title: l10n.budgetEmptyTitle,
                          message: l10n.budgetEmptyMessage,
                          createLabel: l10n.createBudget,
                          onCreate: () => context.push('/budgets/new'),
                        )
                      else if (visibleBudgets.isEmpty)
                        _FilteredEmpty(
                          title: l10n.budgetFilteredEmptyTitle,
                          message: l10n.budgetFilteredEmptyMessage,
                          resetLabel: l10n.budgetFilterReset,
                          onReset: () => setState(() => _filter = _BudgetFilter.all),
                        )
                      else
                        ...visibleBudgets.map((budget) {
                          final summary = summaries[budget.currency]?.valueOrNull;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _BudgetSummaryCard(
                              key: ValueKey('budget_card_${budget.id}'),
                              budget: budget,
                              category: _categoryName(categories, budget.categoryId),
                              categoryIcon: _categoryIcon(categories, budget.categoryId),
                              summary: summary,
                              locale: _localeName,
                              l10n: l10n,
                              onTap: () => context.push('/budgets/${budget.id}'),
                            ),
                          );
                        }),
                      if (!isEmptyForMonth) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            key: const ValueKey('budgets_create_button'),
                            onPressed: () => context.push('/budgets/new'),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.createBudget),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: OutlinedButton(
                          key: const ValueKey('budgets_manage_categories'),
                          onPressed: () => context.push('/categories'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(l10n.manageCategories),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String get _localeName => Localizations.localeOf(context).toString();

  Widget _filters(AppLocalizations l10n) {
    final labels = {
      _BudgetFilter.all: l10n.budgetFilterAll,
      _BudgetFilter.expenses: l10n.budgetFilterExpenses,
      _BudgetFilter.income: l10n.budgetFilterIncome,
    };
    return Row(
      children: _BudgetFilter.values.map((filter) {
        final selected = _filter == filter;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: filter == _BudgetFilter.income ? 0 : 8),
            child: Semantics(
              button: true,
              selected: selected,
              label: labels[filter],
              child: SizedBox(
                height: 48,
                child: Material(
                  key: ValueKey('budget_filter_${filter.name}'),
                  color: selected ? AppColors.blueDark : Colors.white,
                  shape: StadiumBorder(
                    side: BorderSide(color: selected ? AppColors.blueDark : AppColors.line),
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _filter = filter),
                    customBorder: const StadiumBorder(),
                    child: Center(
                      child: Text(
                        labels[filter]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? Colors.white : AppColors.navy,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _chooseMonth() async {
    final selected = await showBudgetMonthPicker(context, _selectedMonth);
    if (selected != null && mounted) {
      setState(() => _selectedMonth = DateTime(selected.year, selected.month));
    }
  }

  String _categoryName(List<FinanceCategory> categories, String categoryId) {
    for (final category in categories) {
      if (category.id == categoryId) return category.customName ?? category.id;
    }
    return categoryId;
  }

  String? _categoryIcon(List<FinanceCategory> categories, String categoryId) {
    for (final category in categories) {
      if (category.id == categoryId) return category.icon;
    }
    return null;
  }
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
    required super.key,
    required this.budget,
    required this.category,
    required this.categoryIcon,
    required this.summary,
    required this.locale,
    required this.l10n,
    required this.onTap,
  });

  final Budget budget;
  final String category;
  final String? categoryIcon;
  final MonthlySummary? summary;
  final String locale;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const calculator = CalculateBudgetTracking();
    final tracking = calculator(budget, const <FinancialOperation>[], summary: summary);
    final ratio = budget.plannedAmountMinor <= 0
        ? 0.0
        : (tracking.actualMinor / budget.plannedAmountMinor).clamp(0.0, 1.0);
    String formatAmount(int value) => CurrencyFormatter.formatMinor(
      value,
      budget.currency,
      locale: locale,
    );
    final isIncome = budget.flowType == BudgetFlowType.income;
    final statusColor = tracking.isExceeded ? const Color(0xFFC73338) : AppColors.green;
    final typeLabel = isIncome ? l10n.income : l10n.expense;
    final actualLabel = isIncome ? l10n.budgetReceived : l10n.budgetSpent;
    final remainingLabel = tracking.isExceeded
        ? l10n.exceeded(formatAmount(-tracking.remainingMinor))
        : l10n.remaining(formatAmount(tracking.remainingMinor));

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        key: ValueKey('budget_card_tap_${budget.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 11, 15, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FinanceCategoryIcon(iconId: categoryIcon, size: 32, iconSize: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                typeLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.planned(formatAmount(tracking.plannedMinor)),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$actualLabel · ${formatAmount(tracking.actualMinor)}',
                key: ValueKey('budget_card_actual_${budget.id}'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
              Text(
                remainingLabel,
                key: ValueKey('budget_card_remaining_${budget.id}'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              Semantics(
                key: ValueKey('budget_card_progress_${budget.id}'),
                label:
                    '$typeLabel · ${l10n.actual(formatAmount(tracking.actualMinor))} · ${l10n.planned(formatAmount(tracking.plannedMinor))}',
                value: '${(ratio * 100).round()}%',
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 7,
                  backgroundColor: AppColors.blueSoft,
                  color: tracking.isExceeded ? const Color(0xFFC73338) : AppColors.blueDark,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets({
    required this.title,
    required this.message,
    required this.createLabel,
    required this.onCreate,
  });

  final String title;
  final String message;
  final String createLabel;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 100),
    child: Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(color: AppColors.blueSoft, shape: BoxShape.circle),
          child: const Icon(Icons.pie_chart_outline, color: AppColors.blueDark, size: 32),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          key: const ValueKey('budget_empty_title'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const ValueKey('budget_empty_create'),
            onPressed: onCreate,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(createLabel),
          ),
        ),
      ],
    ),
  );
}

class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({
    required this.title,
    required this.message,
    required this.resetLabel,
    required this.onReset,
  });

  final String title;
  final String message;
  final String resetLabel;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        const Icon(Icons.filter_list_off, color: AppColors.muted, size: 36),
        const SizedBox(height: 12),
        Text(title, key: const ValueKey('budget_filtered_empty'), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        TextButton(
          key: const ValueKey('budget_filter_reset'),
          onPressed: onReset,
          child: Text(resetLabel),
        ),
      ],
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.retryLabel, required this.onRetry});

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(
            key: const ValueKey('budgets_retry'),
            onPressed: onRetry,
            child: Text(retryLabel),
          ),
        ],
      ),
    ),
  );
}
