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
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/usecases/calculate_budget_tracking.dart';
import '../providers/canonical_finance_providers.dart';
import '../widgets/budget_month_picker.dart';
import '../widgets/finance_category_icon.dart';

class CanonicalBudgetTrackingScreen extends ConsumerStatefulWidget {
  const CanonicalBudgetTrackingScreen({super.key, this.initialMonthKey});

  final String? initialMonthKey;

  @override
  ConsumerState<CanonicalBudgetTrackingScreen> createState() =>
      _CanonicalBudgetTrackingScreenState();
}

class _CanonicalBudgetTrackingScreenState extends ConsumerState<CanonicalBudgetTrackingScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = _parseMonth(widget.initialMonthKey) ?? DateTime.now();
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    final l10n = AppLocalizations.of(context);
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));

    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);
    final budgetsProvider = canonicalBudgetsProvider((userId: user.id, monthKey: monthKey));
    final budgetsState = ref.watch(budgetsProvider);
    final accountsState = ref.watch(canonicalAccountsProvider(user.id));
    final profileState = ref.watch(canonicalUserProfileProvider(user.id));
    final categories =
        ref.watch(canonicalCategoriesProvider(user.id)).valueOrNull ?? const <FinanceCategory>[];
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: budgetsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _TrackingLoadError(
            message: l10n.genericError,
            retryLabel: l10n.retry,
            onRetry: () => ref.invalidate(budgetsProvider),
          ),
          data: (budgets) {
            if (accountsState.isLoading || profileState.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (accountsState.hasError || profileState.hasError) {
              return _TrackingLoadError(
                message: l10n.genericError,
                retryLabel: l10n.retry,
                onRetry: () {
                  ref
                    ..invalidate(canonicalAccountsProvider(user.id))
                    ..invalidate(canonicalUserProfileProvider(user.id));
                },
              );
            }

            final currencySet = <String>{
              ...budgets.map((budget) => budget.currency),
              ...?accountsState.valueOrNull?.map((account) => account.currency),
            };
            final defaultCurrency = profileState.valueOrNull?.defaultCurrency;
            if (defaultCurrency != null) currencySet.add(defaultCurrency);
            final currencies = currencySet.toList()..sort();
            final summaryStates = <String, AsyncValue<MonthlySummary?>>{
              for (final currency in currencies)
                currency: ref.watch(
                  canonicalMonthlySummaryProvider(
                    (userId: user.id, monthKey: monthKey, currency: currency),
                  ),
                ),
            };
            if (summaryStates.values.any((summary) => summary.isLoading)) {
              return const Center(child: CircularProgressIndicator());
            }
            if (summaryStates.values.any((summary) => summary.hasError)) {
              return _TrackingLoadError(
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
            final summaries = {
              for (final entry in summaryStates.entries) entry.key: entry.value.valueOrNull,
            };
            final hasActivity = summaries.values.any(
              (summary) =>
                  summary != null && (summary.incomeMinor != 0 || summary.expenseMinor != 0),
            );
            return Column(
              children: [
                _TrackingHeader(
                  title: l10n.budgetTrackingTitle,
                  onBack: context.pop,
                  backLabel: l10n.budgetBackToBudgets,
                ),
                Expanded(
                  child: budgets.isEmpty && !hasActivity
                      ? _TrackingEmpty(
                          title: l10n.budgetTrackingEmptyTitle,
                          message: l10n.budgetTrackingEmptyMessage,
                          createLabel: l10n.createBudget,
                          onCreate: () => context.push('/budgets/new'),
                          month: _selectedMonth,
                          locale: locale,
                          onChooseMonth: _chooseMonth,
                          monthLabel: l10n.budgetMonth,
                          changeMonthLabel: l10n.changeMonth,
                        )
                      : ListView(
                          key: const ValueKey('budget_tracking_scroll'),
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
                          children: [
                            _MonthSelector(
                              month: _selectedMonth,
                              locale: locale,
                              label: l10n.budgetMonth,
                              changeLabel: l10n.changeMonth,
                              onTap: _chooseMonth,
                            ),
                            const SizedBox(height: 16),
                            for (final currency in currencies)
                              _CurrencyTrackingGroup(
                                key: ValueKey('budget_tracking_currency_$currency'),
                                currency: currency,
                                budgets: budgets
                                    .where((budget) => budget.currency == currency)
                                    .toList(),
                                summary: summaries[currency],
                                categories: categories,
                                locale: locale,
                                l10n: l10n,
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _chooseMonth() async {
    final selected = await showBudgetMonthPicker(context, _selectedMonth);
    if (selected != null && mounted) {
      setState(() => _selectedMonth = DateTime(selected.year, selected.month));
    }
  }
}

DateTime? _parseMonth(String? value) {
  if (value == null || !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value)) return null;
  final pieces = value.split('-');
  return DateTime(int.parse(pieces[0]), int.parse(pieces[1]));
}

class _TrackingHeader extends StatelessWidget {
  const _TrackingHeader({required this.title, required this.onBack, required this.backLabel});

  final String title;
  final VoidCallback onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(24, 12, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).appTitle,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.blueDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                key: const ValueKey('budget_tracking_title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('budget_tracking_back'),
              tooltip: backLabel,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: AppColors.blueDark),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.locale,
    required this.label,
    required this.changeLabel,
    required this.onTap,
  });

  final DateTime month;
  final String locale;
  final String label;
  final String changeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          key: const ValueKey('budget_tracking_month'),
          onPressed: onTap,
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
              Expanded(child: Text(DateFormat.yMMMM(locale).format(month))),
              Icon(Icons.keyboard_arrow_down, color: AppColors.muted, semanticLabel: changeLabel),
            ],
          ),
        ),
      ),
    ],
  );
}

class _CurrencyTrackingGroup extends StatelessWidget {
  const _CurrencyTrackingGroup({
    super.key,
    required this.currency,
    required this.budgets,
    required this.summary,
    required this.categories,
    required this.locale,
    required this.l10n,
  });

  final String currency;
  final List<Budget> budgets;
  final MonthlySummary? summary;
  final List<FinanceCategory> categories;
  final String locale;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: _CurrencyTrackingContent(
      currency: currency,
      budgets: budgets,
      summary: summary,
      categories: categories,
      locale: locale,
      l10n: l10n,
    ),
  );
}

class _CurrencyTrackingContent extends StatelessWidget {
  const _CurrencyTrackingContent({
    required this.currency,
    required this.budgets,
    required this.categories,
    required this.summary,
    required this.locale,
    required this.l10n,
  });

  final String currency;
  final List<Budget> budgets;
  final List<FinanceCategory> categories;
  final MonthlySummary? summary;
  final String locale;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    const calculator = CalculateBudgetTracking();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final flowType in BudgetFlowType.values)
          if (budgets.any((budget) => budget.flowType == flowType) ||
              _summaryActual(summary, flowType) > 0) ...[
            _FlowTrackingSection(
              currency: currency,
              flowType: flowType,
              budgets: budgets.where((budget) => budget.flowType == flowType).toList(),
              categories: categories,
              summary: summary,
              locale: locale,
              l10n: l10n,
              calculator: calculator,
            ),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}

class _FlowTrackingSection extends StatelessWidget {
  const _FlowTrackingSection({
    required this.currency,
    required this.flowType,
    required this.budgets,
    required this.categories,
    required this.summary,
    required this.locale,
    required this.l10n,
    required this.calculator,
  });

  final String currency;
  final BudgetFlowType flowType;
  final List<Budget> budgets;
  final List<FinanceCategory> categories;
  final MonthlySummary? summary;
  final String locale;
  final AppLocalizations l10n;
  final CalculateBudgetTracking calculator;

  @override
  Widget build(BuildContext context) {
    final isIncome = flowType == BudgetFlowType.income;
    final title = isIncome ? l10n.income : l10n.expense;
    final tracking = budgets
        .map((budget) => calculator(budget, const <FinancialOperation>[], summary: summary))
        .toList();
    final planned = tracking.fold<int>(0, (sum, item) => sum + item.plannedMinor);
    // Compare the plan only with activity from the categories that have a budget.
    // The rest of the month's activity is surfaced separately below.
    final actual = tracking.fold<int>(0, (sum, item) => sum + item.actualMinor);
    final totalActual = _summaryActual(summary, flowType);
    final unbudgetedActual = totalActual > actual ? totalActual - actual : 0;
    final remaining = planned - actual;
    final ratio = planned <= 0 ? 0.0 : (actual / planned).clamp(0.0, 1.0);
    final budgetedCategoryIds = budgets.map((budget) => budget.categoryId).toSet();
    final unbudgetedCategoryIds =
        summary?.byCategory.entries
            .where((entry) {
              final hasMatchingSign = isIncome ? entry.value > 0 : entry.value < 0;
              return hasMatchingSign &&
                  entry.value != 0 &&
                  !budgetedCategoryIds.contains(entry.key);
            })
            .map((entry) => entry.key)
            .toSet() ??
        const <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '$currency · $title',
            key: ValueKey('budget_tracking_group_${currency}_${flowType.value}'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _FlowSummaryCard(
          currency: currency,
          flowType: flowType,
          planned: planned,
          actual: actual,
          remaining: remaining,
          progress: ratio,
          locale: locale,
          l10n: l10n,
        ),
        const SizedBox(height: 14),
        Text(
          l10n.byCategory,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (final budget in budgets)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BudgetTrackingCard(
              budget: budget,
              name: _categoryName(categories, budget.categoryId),
              categoryIcon: _categoryIcon(categories, budget.categoryId),
              categoryColorValue: _categoryColorValue(categories, budget.categoryId),
              summary: summary,
              locale: locale,
              l10n: l10n,
              calculator: calculator,
            ),
          ),
        if (unbudgetedCategoryIds.isNotEmpty || unbudgetedActual > 0)
          _UnbudgetedNotice(
            title: l10n.unbudgetedMovements,
            message: unbudgetedCategoryIds.isEmpty
                ? l10n.unbudgetedMovements
                : l10n.unbudgetedCategoryCount(unbudgetedCategoryIds.length),
            amountKey: ValueKey(
              'budget_tracking_unbudgeted_amount_${currency}_${flowType.value}',
            ),
            amount: l10n.unbudgetedActualAmount(
              CurrencyFormatter.formatMinor(unbudgetedActual, currency, locale: locale),
            ),
            action: l10n.reviewCategories,
            onAction: () => context.push('/categories'),
          ),
      ],
    );
  }
}

class _FlowSummaryCard extends StatelessWidget {
  const _FlowSummaryCard({
    required this.currency,
    required this.flowType,
    required this.planned,
    required this.actual,
    required this.remaining,
    required this.progress,
    required this.locale,
    required this.l10n,
  });

  final String currency;
  final BudgetFlowType flowType;
  final int planned;
  final int actual;
  final int remaining;
  final double progress;
  final String locale;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isIncome = flowType == BudgetFlowType.income;
    final actualTitle = isIncome ? l10n.budgetReceived : l10n.budgetSpent;
    String format(int amount) =>
        CurrencyFormatter.formatMinor(amount.abs(), currency, locale: locale);
    final remainingText = planned == 0
        ? l10n.unbudgetedMovements
        : remaining < 0
        ? l10n.exceeded(format(remaining))
        : l10n.remaining(format(remaining));
    final percent = planned > 0 ? (actual * 100 ~/ planned).clamp(0, 999) : null;

    return Card(
      color: AppColors.blueSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.plannedSummary,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.blueDark),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.plannedTotal(format(planned)),
              key: ValueKey('budget_tracking_planned_${currency}_${flowType.value}'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  '$actualTitle · ${format(actual)}',
                  key: ValueKey('budget_tracking_actual_${currency}_${flowType.value}'),
                ),
                Text(
                  remainingText,
                  key: ValueKey('budget_tracking_remaining_${currency}_${flowType.value}'),
                ),
              ],
            ),
            if (percent != null) ...[
              const SizedBox(height: 10),
              KeyedSubtree(
                key: ValueKey('budget_tracking_progress_${currency}_${flowType.value}'),
                child: Semantics(
                  label: '$actualTitle · ${l10n.planned(format(planned))}',
                  value: '$percent%',
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white,
                    color: remaining < 0 ? const Color(0xFFC73338) : AppColors.blueDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  isIncome ? l10n.budgetReceivedPercent(percent) : l10n.budgetUsedPercent(percent),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.blueDark),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetTrackingCard extends StatelessWidget {
  const _BudgetTrackingCard({
    required this.budget,
    required this.name,
    required this.categoryIcon,
    required this.categoryColorValue,
    required this.summary,
    required this.locale,
    required this.l10n,
    required this.calculator,
  });

  final Budget budget;
  final String name;
  final String? categoryIcon;
  final int? categoryColorValue;
  final MonthlySummary? summary;
  final String locale;
  final AppLocalizations l10n;
  final CalculateBudgetTracking calculator;

  @override
  Widget build(BuildContext context) {
    final result = calculator(budget, const <FinancialOperation>[], summary: summary);
    final ratio = result.plannedMinor <= 0
        ? 0.0
        : (result.actualMinor / result.plannedMinor).clamp(0.0, 1.0);
    String format(int amount) =>
        CurrencyFormatter.formatMinor(amount.abs(), budget.currency, locale: locale);
    final isIncome = budget.flowType == BudgetFlowType.income;
    final actualLabel = isIncome ? l10n.budgetReceived : l10n.budgetSpent;
    final remainingLabel = result.isExceeded
        ? l10n.exceeded(format(result.remainingMinor))
        : l10n.remaining(format(result.remainingMinor));

    return Card(
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        key: ValueKey('budget_tracking_category_${budget.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/budgets/${budget.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FinanceCategoryIcon(
                    iconId: categoryIcon,
                    colorValue: categoryColorValue,
                    size: 32,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '$actualLabel · ${format(result.actualMinor)}  /  ${l10n.planned(format(result.plannedMinor))}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                remainingLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: result.isExceeded ? const Color(0xFFC73338) : AppColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                label:
                    '$name · ${l10n.actual(format(result.actualMinor))} · ${l10n.planned(format(result.plannedMinor))}',
                value: '${(ratio * 100).round()}%',
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 7,
                  backgroundColor: AppColors.blueSoft,
                  color: result.isExceeded ? const Color(0xFFC73338) : AppColors.blueDark,
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

class _UnbudgetedNotice extends StatelessWidget {
  const _UnbudgetedNotice({
    required this.title,
    required this.message,
    required this.amountKey,
    required this.amount,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String message;
  final Key amountKey;
  final String amount;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFFFF8E8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy),
                ),
                const SizedBox(height: 2),
                Text(message, style: const TextStyle(color: AppColors.muted)),
                Text(
                  amount,
                  key: amountKey,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  key: const ValueKey('budget_tracking_review_categories'),
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(action),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TrackingEmpty extends StatelessWidget {
  const _TrackingEmpty({
    required this.title,
    required this.message,
    required this.createLabel,
    required this.onCreate,
    required this.month,
    required this.locale,
    required this.onChooseMonth,
    required this.monthLabel,
    required this.changeMonthLabel,
  });

  final String title;
  final String message;
  final String createLabel;
  final VoidCallback onCreate;
  final DateTime month;
  final String locale;
  final VoidCallback onChooseMonth;
  final String monthLabel;
  final String changeMonthLabel;

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('budget_tracking_empty'),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
    children: [
      _MonthSelector(
        month: month,
        locale: locale,
        label: monthLabel,
        changeLabel: changeMonthLabel,
        onTap: onChooseMonth,
      ),
      const SizedBox(height: 56),
      const Icon(Icons.pie_chart_outline, color: AppColors.blueDark, size: 52),
      const SizedBox(height: 16),
      Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        key: const ValueKey('budget_tracking_empty_create'),
        onPressed: onCreate,
        icon: const Icon(Icons.add),
        label: Text(createLabel),
      ),
    ],
  );
}

class _TrackingLoadError extends StatelessWidget {
  const _TrackingLoadError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

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
          const Icon(Icons.cloud_off_outlined, color: AppColors.muted, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('budget_tracking_retry'),
            onPressed: onRetry,
            child: Text(retryLabel),
          ),
        ],
      ),
    ),
  );
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

int? _categoryColorValue(List<FinanceCategory> categories, String categoryId) {
  for (final category in categories) {
    if (category.id == categoryId) return category.colorValue;
  }
  return null;
}

int _summaryActual(MonthlySummary? summary, BudgetFlowType flowType) => switch (flowType) {
  BudgetFlowType.income => summary?.incomeMinor ?? 0,
  BudgetFlowType.expense => summary?.expenseMinor ?? 0,
};
