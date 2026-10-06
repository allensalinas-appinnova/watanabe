import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalBudgetsScreen extends ConsumerWidget {
  const CanonicalBudgetsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Inicia sesión')));
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final budgets = ref.watch(canonicalBudgetsProvider((userId: user.id, monthKey: month)));
    final categories =
        ref.watch(canonicalCategoriesProvider(user.id)).valueOrNull ?? const <FinanceCategory>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Presupuesto')),
      body: budgets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) => items.isEmpty
            ? Center(
                child: FilledButton.icon(
                  onPressed: () => _showCreate(context, ref, user.id, categories, month),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear presupuesto'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...items.map((budget) {
                    FinanceCategory? category;
                    for (final item in categories) {
                      if (item.id == budget.categoryId) category = item;
                    }
                    return Card(
                      child: ListTile(
                        title: Text(category?.customName ?? budget.categoryId),
                        subtitle: Text('${budget.flowType.name} · ${budget.items.length} items'),
                        trailing: Text(
                          NumberFormat.currency(
                            name: budget.currency,
                            decimalDigits: 2,
                          ).format(budget.plannedAmountMinor / 100),
                        ),
                        onTap: () => context.push('/budgets/${budget.id}'),
                      ),
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref, user.id, categories, month),
        icon: const Icon(Icons.add),
        label: const Text('Presupuesto'),
      ),
    );
  }

  Future<void> _showCreate(
    BuildContext context,
    WidgetRef ref,
    String userId,
    List<FinanceCategory> categories,
    String month,
  ) async {
    final description = TextEditingController();
    final amount = TextEditingController();
    String? categoryId;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Nuevo presupuesto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: categories
                      .where((item) => item.type.name == 'expense' && !item.isArchived)
                      .map<DropdownMenuItem<String>>(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.customName ?? item.id),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => categoryId = value),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Item'),
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monto'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  final parsed = double.tryParse(amount.text.replaceAll(',', '.'));
                  if (categoryId == null ||
                      description.text.trim().isEmpty ||
                      parsed == null ||
                      parsed <= 0) {
                    return;
                  }
                  await ref
                      .read(canonicalActionsProvider)
                      .createBudget(
                        userId,
                        categoryId: categoryId!,
                        flowType: 'expense',
                        monthKey: month,
                        currency: 'COP',
                        items: [
                          CanonicalBudgetItemDraft(
                            description: description.text,
                            amountMinor: (parsed * 100).round(),
                            dayOfMonth: DateTime.now().day,
                          ),
                        ],
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      description.dispose();
      amount.dispose();
    }
  }
}
