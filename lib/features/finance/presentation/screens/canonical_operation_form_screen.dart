import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalOperationFormScreen extends ConsumerStatefulWidget {
  const CanonicalOperationFormScreen({super.key, this.initialType = OperationType.expense});
  final OperationType initialType;
  @override
  ConsumerState<CanonicalOperationFormScreen> createState() => _CanonicalOperationFormScreenState();
}

class _CanonicalOperationFormScreenState extends ConsumerState<CanonicalOperationFormScreen> {
  late OperationType _type = widget.initialType;
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _accountId;
  String? _categoryId;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Inicia sesión')));
    final accounts = ref.watch(canonicalAccountsProvider(user.id));
    final categories = ref.watch(canonicalCategoriesProvider(user.id));
    final filteredCategories =
        categories.valueOrNull
            ?.where((category) => category.type.name == _type.name && !category.isArchived)
            .toList() ??
        const <FinanceCategory>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(_type == OperationType.income ? 'Agregar ingreso' : 'Agregar gasto'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<OperationType>(
            segments: const [
              ButtonSegment(
                value: OperationType.expense,
                label: Text('Gasto'),
                icon: Icon(Icons.remove),
              ),
              ButtonSegment(
                value: OperationType.income,
                label: Text('Ingreso'),
                icon: Icon(Icons.add),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() {
              _type = value.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monto', prefixText: r'$ '),
          ),
          const SizedBox(height: 12),
          accounts.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text(error.toString()),
            data: (items) => DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Cuenta'),
              items: items
                  .map(
                    (account) => DropdownMenuItem(
                      value: account.id,
                      child: Text('${account.name} (${account.currency})'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _accountId = value),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: filteredCategories
                .map(
                  (category) => DropdownMenuItem(
                    value: category.id,
                    child: Text(category.customName ?? category.id),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : () => _save(user.id, accounts.valueOrNull ?? const []),
            child: _saving ? const CircularProgressIndicator() : const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(String userId, List<FinanceAccount> accounts) async {
    final parsed = double.tryParse(_amount.text.replaceAll(',', '.'));
    FinanceAccount? account;
    for (final item in accounts) {
      if (item.id == _accountId) account = item;
    }
    if (parsed == null || parsed <= 0 || account == null || _categoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Completa monto, cuenta y categoría.')));
      return;
    }
    setState(() => _saving = true);
    final draft = FinancialOperationDraft(
      type: _type,
      amountMinor: (parsed * 100).round(),
      currency: account.currency,
      accountId: account.id,
      categoryId: _categoryId,
      occurredAt: DateTime.now().toUtc(),
      monthKey: _currentMonthKey(),
      description: _description.text,
      idempotencyKey: '${DateTime.now().microsecondsSinceEpoch}_$_type',
    );
    try {
      await ref.read(canonicalActionsProvider).createOperation(userId, draft);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }
}
