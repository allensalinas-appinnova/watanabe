import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/canonical_finance_providers.dart';
import 'budget_month_picker.dart';

enum PlanningSection { agenda, budgets, debtPayments }

class PlanningSectionHeader extends ConsumerWidget {
  const PlanningSectionHeader({required this.userId, required this.section, super.key});

  final String userId;
  final PlanningSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final month = ref.watch(planningMonthProvider(userId));
    final monthKey = DateFormat('yyyy-MM').format(month);
    final locale = Localizations.localeOf(context).toString();
    final compact =
        MediaQuery.sizeOf(context).width < 400 || MediaQuery.textScalerOf(context).scale(1) > 1.2;
    void navigate(PlanningSection target) {
      final path = switch (target) {
        PlanningSection.agenda => '/budgets/agenda',
        PlanningSection.budgets => '/budgets',
        PlanningSection.debtPayments => '/budgets/debt-payments',
      };
      context.go('$path?month=$monthKey');
    }

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('planning_previous_month'),
                    tooltip: l10n.previousMonth,
                    onPressed: () => ref
                        .read(planningMonthProvider(userId).notifier)
                        .select(DateTime(month.year, month.month - 1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('planning_month_picker'),
                      onPressed: () async {
                        final picked = await showBudgetMonthPicker(context, month);
                        if (picked != null) {
                          ref.read(planningMonthProvider(userId).notifier).select(picked);
                        }
                      },
                      child: Text(
                        DateFormat.yMMMM(locale).format(month),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('planning_next_month'),
                    tooltip: l10n.nextMonth,
                    onPressed: () => ref
                        .read(planningMonthProvider(userId).notifier)
                        .select(DateTime(month.year, month.month + 1)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  if (compact)
                    IconButton(
                      key: const ValueKey('planning_this_month'),
                      tooltip: l10n.thisMonth,
                      onPressed: () => ref.read(planningMonthProvider(userId).notifier).current(),
                      icon: const Icon(Icons.today_outlined),
                    )
                  else
                    TextButton(
                      key: const ValueKey('planning_this_month'),
                      onPressed: () => ref.read(planningMonthProvider(userId).notifier).current(),
                      child: Text(l10n.thisMonth),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<PlanningSection>(
                  segments: [
                    ButtonSegment(value: PlanningSection.agenda, label: Text(l10n.planningAgenda)),
                    ButtonSegment(value: PlanningSection.budgets, label: Text(l10n.budgetsTab)),
                    ButtonSegment(
                      value: PlanningSection.debtPayments,
                      label: Text(l10n.debtCommitmentsTab),
                    ),
                  ],
                  selected: {section},
                  onSelectionChanged: (value) => navigate(value.first),
                  showSelectedIcon: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlanningMonthlySummary extends ConsumerWidget {
  const PlanningMonthlySummary({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final month = ref.watch(planningMonthProvider(userId));
    final monthKey = DateFormat('yyyy-MM').format(month);
    final locale = Localizations.localeOf(context).toString();
    final totals = ref.watch(planningBudgetTotalsProvider((userId: userId, monthKey: monthKey)));
    return totals.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.planningTotalsUnavailable),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => ref.invalidate(
                    planningBudgetTotalsProvider((userId: userId, monthKey: monthKey)),
                  ),
                  child: Text(l10n.retry),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (value) => _PlanningBudgetTotals(value: value, locale: locale),
    );
  }
}

class _PlanningBudgetTotals extends StatelessWidget {
  const _PlanningBudgetTotals({required this.value, required this.locale});
  final PlanningBudgetTotals value;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencies = {...value.income.keys, ...value.expense.keys, ...value.debt.keys}.toList()
      ..sort();
    if (currencies.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          children: [
            for (final currency in currencies)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '${l10n.income}: ${CurrencyFormatter.formatMinor(value.income[currency] ?? 0, currency, locale: locale)}',
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '${l10n.expense}: ${CurrencyFormatter.formatMinor(value.expense[currency] ?? 0, currency, locale: locale)}',
                      ),
                    ),
                    if ((value.debt[currency] ?? 0) > 0)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l10n.planningDebtTotal(
                            CurrencyFormatter.formatMinor(
                              value.debt[currency]!,
                              currency,
                              locale: locale,
                            ),
                          ),
                          maxLines: 2,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
