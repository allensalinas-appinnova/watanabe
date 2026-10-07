import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalBudgetsScreen extends ConsumerWidget {
  const CanonicalBudgetsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    final l10n = AppLocalizations.of(context);
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final budgets = ref.watch(canonicalBudgetsProvider((userId: user.id, monthKey: month)));
    final categories =
        ref.watch(canonicalCategoriesProvider(user.id)).valueOrNull ?? const <FinanceCategory>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.budget)),
      body: budgets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.genericError)),
        data: (items) => items.isEmpty
            ? Center(
                child: FilledButton.icon(
                  onPressed: () => _showCreate(context, ref, user.id, categories, month),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.createBudget),
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
                        subtitle: Text(
                          '${budget.flowType.name == 'income' ? l10n.income : l10n.expense} · ${budget.items.length}',
                        ),
                        trailing: Text(
                          CurrencyFormatter.formatMinor(
                            budget.plannedAmountMinor,
                            budget.currency,
                          ),
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
        label: Text(l10n.budget),
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
    final l10n = AppLocalizations.of(context);
    final drafts = [_BudgetItemControllers(day: DateTime.now().day)];
    String? categoryId;
    var flowType = 'expense';
    var saving = false;
    var hasValidationError = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(l10n.newBudget),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: flowType,
                      decoration: InputDecoration(labelText: l10n.category),
                      items: [
                        DropdownMenuItem(value: 'expense', child: Text(l10n.expense)),
                        DropdownMenuItem(value: 'income', child: Text(l10n.income)),
                      ],
                      onChanged: (value) => setState(() {
                        flowType = value ?? 'expense';
                        categoryId = null;
                      }),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: categoryId,
                      decoration: InputDecoration(labelText: l10n.budgetCategory),
                      items: categories
                          .where((item) => item.type.name == flowType && !item.isArchived)
                          .map<DropdownMenuItem<String>>(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.customName ?? item.id),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => categoryId = value),
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < drafts.length; index++) ...[
                      TextField(
                        controller: drafts[index].description,
                        decoration: InputDecoration(
                          labelText: '${l10n.budgetItem} ${index + 1}',
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: drafts[index].amount,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(labelText: l10n.amount),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: drafts[index].day,
                            items: [
                              for (var day = 1; day <= 31; day++)
                                DropdownMenuItem(value: day, child: Text('$day')),
                            ],
                            onChanged: (day) => setState(() => drafts[index].day = day ?? 1),
                          ),
                          if (drafts.length > 1)
                            IconButton(
                              tooltip: l10n.cancel,
                              onPressed: () => setState(() => drafts.removeAt(index).dispose()),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(
                          () => drafts.add(_BudgetItemControllers(day: DateTime.now().day)),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.budgetItem),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${l10n.plannedAmountLabel}: ${CurrencyFormatter.formatMinor(_draftTotal(drafts), 'COP')}',
                      ),
                    ),
                    if (hasValidationError)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(l10n.completeRequiredFields),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final items = <CanonicalBudgetItemDraft>[];
                        try {
                          for (final draft in drafts) {
                            if (draft.description.text.trim().isEmpty) {
                              throw const FormatException();
                            }
                            items.add(
                              CanonicalBudgetItemDraft(
                                description: draft.description.text.trim(),
                                amountMinor: MoneyParser.minorUnits(draft.amount.text, 'COP'),
                                dayOfMonth: draft.day,
                              ),
                            );
                          }
                        } on FormatException {
                          setState(() => hasValidationError = true);
                          return;
                        }
                        if (categoryId == null) {
                          setState(() => hasValidationError = true);
                          return;
                        }
                        setState(() => saving = true);
                        try {
                          await ref
                              .read(canonicalActionsProvider)
                              .createBudget(
                                userId,
                                categoryId: categoryId!,
                                flowType: flowType,
                                monthKey: month,
                                currency: 'COP',
                                items: items,
                              );
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                        } catch (_) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(l10n.genericError)),
                            );
                          }
                        } finally {
                          if (dialogContext.mounted) setState(() => saving = false);
                        }
                      },
                child: saving ? const CircularProgressIndicator() : Text(l10n.save),
              ),
            ],
          ),
        ),
      );
    } finally {
      for (final draft in drafts) {
        draft.dispose();
      }
    }
  }
}

class _BudgetItemControllers {
  _BudgetItemControllers({required this.day});

  final description = TextEditingController();
  final amount = TextEditingController();
  int day;

  void dispose() {
    description.dispose();
    amount.dispose();
  }
}

int _draftTotal(List<_BudgetItemControllers> drafts) => drafts.fold<int>(0, (total, draft) {
  try {
    return total + MoneyParser.minorUnits(draft.amount.text, 'COP');
  } on FormatException {
    return total;
  }
});
