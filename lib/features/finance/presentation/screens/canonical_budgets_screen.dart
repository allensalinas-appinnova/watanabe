import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/pinned_action_bar.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/budget_flow_type.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/usecases/calculate_budget_tracking.dart';
import '../providers/canonical_finance_providers.dart';
import '../widgets/finance_category_icon.dart';
import '../widgets/planning_section_header.dart';

enum _BudgetFilter { all, expenses, income }

class CanonicalBudgetsScreen extends ConsumerStatefulWidget {
  const CanonicalBudgetsScreen({super.key, this.initialMonthKey});

  final String? initialMonthKey;

  @override
  ConsumerState<CanonicalBudgetsScreen> createState() => _CanonicalBudgetsScreenState();
}

class _CanonicalBudgetsScreenState extends ConsumerState<CanonicalBudgetsScreen> {
  _BudgetFilter _filter = _BudgetFilter.all;
  bool _initialMonthApplied = false;
  final Map<String, Budget> _justCreatedBudgets = {};
  GoRouter? _router;
  Object? _createRouteRequest;
  bool _createRouteWasVisible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (identical(_router, router)) return;
    _router?.routerDelegate.removeListener(_handleRouteChange);
    _router = router;
    router.routerDelegate.addListener(_handleRouteChange);
  }

  void _handleRouteChange() {
    if (_createRouteRequest == null) return;
    if (_router!.state.uri.path == '/budgets/new') {
      _createRouteWasVisible = true;
    } else if (_createRouteWasVisible) {
      // A redirect or route replacement can abandon the push future. Release
      // the guard when the form actually closes, not only when that future ends.
      _createRouteRequest = null;
      _createRouteWasVisible = false;
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_handleRouteChange);
    super.dispose();
  }

  Future<void> _createBudget() async {
    if (_createRouteRequest != null) return;
    final request = Object();
    _createRouteRequest = request;
    try {
      final userId = ref.read(authSessionProvider).valueOrNull?.id;
      final month = userId == null ? DateTime.now() : ref.read(planningMonthProvider(userId));
      final monthKey = DateFormat('yyyy-MM').format(month);
      final created = await context.push<Budget>('/budgets/new?month=$monthKey');
      if (!mounted || created == null) return;
      setState(() {
        _justCreatedBudgets[created.id] = created;
      });
    } finally {
      if (identical(_createRouteRequest, request)) {
        _createRouteRequest = null;
        _createRouteWasVisible = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    final l10n = AppLocalizations.of(context);
    if (user == null) {
      return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    }

    if (!_initialMonthApplied) {
      _initialMonthApplied = true;
      final key = widget.initialMonthKey;
      final parsed = key != null && RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(key)
          ? DateTime.tryParse('$key-01')
          : null;
      if (parsed != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(planningMonthProvider(user.id).notifier).select(parsed);
        });
      }
    }

    final selectedMonth = ref.watch(planningMonthProvider(user.id));
    final monthKey = DateFormat('yyyy-MM').format(selectedMonth);
    final budgetProvider = canonicalBudgetsProvider((userId: user.id, monthKey: monthKey));
    final budgetsState = ref.watch(budgetProvider);
    ref.listen(budgetProvider, (previous, next) {
      final serverBudgets = next.valueOrNull;
      if (serverBudgets == null || _justCreatedBudgets.isEmpty) return;
      final serverIds = serverBudgets.map((budget) => budget.id).toSet();
      final reconciled = _justCreatedBudgets.keys.where(serverIds.contains).toList();
      if (reconciled.isEmpty) return;
      setState(() {
        for (final id in reconciled) {
          _justCreatedBudgets.remove(id);
        }
      });
    });
    final categoriesState = ref.watch(canonicalCategoriesProvider(user.id));
    final streamedBudgets = budgetsState.valueOrNull ?? const <Budget>[];
    final budgets = <Budget>[
      ...streamedBudgets,
      for (final budget in _justCreatedBudgets.values)
        if (budget.monthKey == monthKey && !streamedBudgets.any((item) => item.id == budget.id))
          budget,
    ];
    final currencies = budgets.map((budget) => budget.currency).toSet();
    final summaries = <String, AsyncValue<MonthlySummary?>>{
      for (final currency in currencies)
        currency: ref.watch(
          canonicalMonthlySummaryProvider(
            (userId: user.id, monthKey: monthKey, currency: currency),
          ),
        ),
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: PinnedActionBar(
        buttonKey: const ValueKey('budgets_create_button'),
        label: l10n.createBudget,
        icon: Icons.add,
        onPressed: _createBudget,
      ),
      body: SafeArea(
        child: Column(
          children: [
            PlanningSectionHeader(userId: user.id, section: PlanningSection.budgets),
            Expanded(
              child: budgetsState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _LoadError(
                  message: l10n.genericError,
                  retryLabel: l10n.retry,
                  onRetry: () => ref.invalidate(budgetProvider),
                ),
                data: (allBudgets) {
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
                  final mergedBudgets = <Budget>[
                    ...allBudgets,
                    for (final budget in _justCreatedBudgets.values)
                      if (budget.monthKey == monthKey &&
                          !allBudgets.any((item) => item.id == budget.id))
                        budget,
                  ];
                  final visibleBudgets = mergedBudgets
                      .where(
                        (budget) => switch (_filter) {
                          _BudgetFilter.all => true,
                          _BudgetFilter.expenses => budget.flowType == BudgetFlowType.expense,
                          _BudgetFilter.income => budget.flowType == BudgetFlowType.income,
                        },
                      )
                      .toList();
                  final isEmptyForMonth = mergedBudgets.isEmpty;

                  return ListView(
                    key: const ValueKey('budget_monthly_list'),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    children: [
                      Text(
                        l10n.budgetsTitle,
                        key: const ValueKey('budgets_title'),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.budgetsSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      PlanningMonthlySummary(userId: user.id),
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
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isEmptyForMonth)
                        _EmptyBudgets(
                          title: l10n.budgetEmptyTitle,
                          message: l10n.budgetEmptyMessage,
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
                              categoryColorValue: _categoryColorValue(
                                categories,
                                budget.categoryId,
                              ),
                              summary: summary,
                              isSummaryLoading: summaries[budget.currency]?.isLoading ?? false,
                              locale: _localeName,
                              l10n: l10n,
                              onTap: () => context.push('/budgets/${budget.id}'),
                            ),
                          );
                        }),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: OutlinedButton(
                          key: const ValueKey('budgets_manage_categories'),
                          onPressed: () => context.push('/categories'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(l10n.manageCategories),
                        ),
                      ),
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
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surface,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _filter = filter),
                    customBorder: const StadiumBorder(),
                    child: Center(
                      child: Text(
                        labels[filter]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
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
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
    required super.key,
    required this.budget,
    required this.category,
    required this.categoryIcon,
    required this.categoryColorValue,
    required this.summary,
    required this.isSummaryLoading,
    required this.locale,
    required this.l10n,
    required this.onTap,
  });

  final Budget budget;
  final String category;
  final String? categoryIcon;
  final int? categoryColorValue;
  final MonthlySummary? summary;
  final bool isSummaryLoading;
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
    final statusColor = tracking.isExceeded ? const Color(0xFFC73338) : context.appColors.income;
    final typeLabel = isIncome ? l10n.income : l10n.expense;
    final actualLabel = isIncome ? l10n.budgetReceived : l10n.budgetSpent;
    final remainingLabel = tracking.isExceeded
        ? l10n.exceeded(formatAmount(-tracking.remainingMinor))
        : l10n.remaining(formatAmount(tracking.remainingMinor));

    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
                  FinanceCategoryIcon(
                    iconId: categoryIcon,
                    colorValue: categoryColorValue,
                    size: 32,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isIncome ? Icons.south_west : Icons.north_east,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    typeLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.planned(formatAmount(tracking.plannedMinor)),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isSummaryLoading) ...[
                const SizedBox(height: 8),
                const SizedBox(height: 7, child: LinearProgressIndicator()),
              ] else ...[
                Text(
                  '$actualLabel · ${formatAmount(tracking.actualMinor)}',
                  key: ValueKey('budget_card_actual_${budget.id}'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    color: tracking.isExceeded
                        ? const Color(0xFFC73338)
                        : Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
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
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 100),
    child: Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.pie_chart_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          key: const ValueKey('budget_empty_title'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
        Icon(
          Icons.filter_list_off,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 36,
        ),
        const SizedBox(height: 12),
        Text(title, key: const ValueKey('budget_filtered_empty'), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
