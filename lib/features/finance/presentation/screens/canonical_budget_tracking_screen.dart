import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/usecases/calculate_budget_tracking.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalBudgetTrackingScreen extends ConsumerStatefulWidget {
  const CanonicalBudgetTrackingScreen({super.key});

  @override
  ConsumerState<CanonicalBudgetTrackingScreen> createState() =>
      _CanonicalBudgetTrackingScreenState();
}

class _CanonicalBudgetTrackingScreenState extends ConsumerState<CanonicalBudgetTrackingScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final user = ref.watch(authSessionProvider).valueOrNull;
    final l10n = AppLocalizations.of(context);
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final month = DateFormat('yyyy-MM').format(_selectedMonth);
    final budgets =
        ref.watch(canonicalBudgetsProvider((userId: user.id, monthKey: month))).valueOrNull ??
        const <Budget>[];
    final summaryState = budgets.isEmpty
        ? null
        : ref.watch(
            canonicalMonthlySummaryProvider(
              (userId: user.id, monthKey: month, currency: budgets.first.currency),
            ),
          );
    final summary = summaryState?.valueOrNull;
    final categories =
        ref.watch(canonicalCategoriesProvider(user.id)).valueOrNull ?? const <FinanceCategory>[];
    const calculator = CalculateBudgetTracking();
    final tracking = budgets
        .map((budget) => calculator(budget, const <FinancialOperation>[], summary: summary))
        .toList();
    final plannedTotal = tracking.fold<int>(0, (sum, item) => sum + item.plannedMinor);
    final actualTotal = tracking.fold<int>(0, (sum, item) => sum + item.actualMinor);
    final remainingTotal = plannedTotal - actualTotal;
    final usedPercent = plannedTotal == 0 ? 0 : ((actualTotal * 100) ~/ plannedTotal).clamp(0, 999);
    final budgetCategoryIds = budgets.map((budget) => budget.categoryId).toSet();
    final summaryHasUnbudgeted =
        summary?.byCategory.keys.any(
          (categoryId) => !budgetCategoryIds.contains(categoryId),
        ) ??
        false;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.budgetTracking(month)),
        actions: [
          IconButton(
            tooltip: l10n.changeMonth,
            icon: const Icon(Icons.calendar_month),
            onPressed: _chooseMonth,
          ),
        ],
      ),
      body: summaryState?.isLoading == true
          ? const Center(child: CircularProgressIndicator())
          : summaryState?.hasError == true
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.genericError),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      canonicalMonthlySummaryProvider(
                        (userId: user.id, monthKey: month, currency: budgets.first.currency),
                      ),
                    ),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            )
          : budgets.isEmpty
          ? Center(child: Text(l10n.noBudgetsThisMonth))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: const Color(0xFF102A43),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.plannedSummary, style: const TextStyle(color: Color(0xFFA6C7E5))),
                        const SizedBox(height: 8),
                        Text(
                          l10n.plannedTotal(_format(plannedTotal, budgets.first.currency)),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: plannedTotal == 0 ? 0 : (actualTotal / plannedTotal).clamp(0, 1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.usedSummary(
                            budgets.first.currency,
                            usedPercent,
                            _format(remainingTotal.abs(), budgets.first.currency),
                          ),
                          style: const TextStyle(color: Color(0xFFB8DED1)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(l10n.byCategory, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ...budgets.map((budget) {
                  final tracking = calculator(
                    budget,
                    const <FinancialOperation>[],
                    summary: summary,
                  );
                  String name = budget.categoryId;
                  for (final category in categories) {
                    if (category.id == budget.categoryId) name = category.customName ?? category.id;
                  }
                  final ratio = tracking.plannedMinor <= 0
                      ? 0.0
                      : (tracking.actualMinor / tracking.plannedMinor).clamp(0.0, 1.0);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: ratio),
                          const SizedBox(height: 8),
                          Text(
                            '${l10n.planned(_format(budget.plannedAmountMinor, budget.currency))} · ${l10n.actual(_format(tracking.actualMinor, budget.currency))}',
                          ),
                          Text(
                            tracking.isExceeded
                                ? l10n.exceeded(_format(-tracking.remainingMinor, budget.currency))
                                : l10n.remaining(_format(tracking.remainingMinor, budget.currency)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (summaryHasUnbudgeted)
                  Card(
                    color: const Color(0xFFFFF8E8),
                    child: ListTile(
                      title: Text(l10n.unbudgetedMovements),
                      subtitle: Text(l10n.reviewCategories),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () {},
                  child: Text(l10n.viewBudgetDetails),
                ),
              ],
            ),
    );
  }

  Future<void> _chooseMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (selected != null && mounted) {
      setState(() => _selectedMonth = DateTime(selected.year, selected.month));
    }
  }
}

String _format(int minor, String currency) =>
    NumberFormat.currency(name: currency, decimalDigits: 2).format(minor / 100);
