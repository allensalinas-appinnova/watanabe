import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/usecases/calculate_budget_tracking.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalBudgetTrackingScreen extends ConsumerWidget {
  const CanonicalBudgetTrackingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Inicia sesión')));
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final budgets =
        ref.watch(canonicalBudgetsProvider((userId: user.id, monthKey: month))).valueOrNull ??
        const <Budget>[];
    final operations =
        ref.watch(canonicalOperationsProvider(user.id)).valueOrNull ?? const <FinancialOperation>[];
    final categories =
        ref.watch(canonicalCategoriesProvider(user.id)).valueOrNull ?? const <FinanceCategory>[];
    const calculator = CalculateBudgetTracking();
    return Scaffold(
      appBar: AppBar(title: Text('Seguimiento · $month')),
      body: budgets.isEmpty
          ? const Center(child: Text('No hay presupuestos para este mes.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: budgets.map((budget) {
                final tracking = calculator(budget, operations);
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
                          'Planeado ${_format(budget.plannedAmountMinor, budget.currency)} · Real ${_format(tracking.actualMinor, budget.currency)}',
                        ),
                        Text(
                          tracking.isExceeded
                              ? 'Excedido ${_format(-tracking.remainingMinor, budget.currency)}'
                              : 'Restante ${_format(tracking.remainingMinor, budget.currency)}',
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

String _format(int minor, String currency) =>
    NumberFormat.currency(name: currency, decimalDigits: 2).format(minor / 100);
