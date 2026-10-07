import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/offline/sync_state.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalOperationFormScreen extends ConsumerStatefulWidget {
  const CanonicalOperationFormScreen({
    super.key,
    this.initialType = OperationType.expense,
    this.initialOperation,
  });

  final OperationType initialType;
  final FinancialOperation? initialOperation;
  @override
  ConsumerState<CanonicalOperationFormScreen> createState() => _CanonicalOperationFormScreenState();
}

class _CanonicalOperationFormScreenState extends ConsumerState<CanonicalOperationFormScreen> {
  late OperationType _type;
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _accountId;
  String? _categoryId;
  String? _idempotencyKey;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final operation = widget.initialOperation;
    _type = operation?.type ?? widget.initialType;
    if (operation != null) {
      _amount.text = _minorAmountInput(operation.amountMinor, operation.currency);
      _description.text = operation.description;
      _accountId = operation.accountId;
      _categoryId = operation.categoryId;
      _idempotencyKey = operation.idempotencyKey;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    final l10n = AppLocalizations.of(context);
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final accounts = ref.watch(canonicalAccountsProvider(user.id));
    final categories = ref.watch(canonicalCategoriesProvider(user.id));
    final filteredCategories =
        categories.valueOrNull
            ?.where((category) => category.type.name == _type.name && !category.isArchived)
            .toList() ??
        const <FinanceCategory>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialOperation == null
              ? (_type == OperationType.income ? l10n.addIncome : l10n.addExpense)
              : l10n.editOperation,
        ),
        actions: [
          if (widget.initialOperation != null && _type != OperationType.transfer)
            IconButton(
              key: const ValueKey('delete_operation'),
              tooltip: l10n.deleteOperation,
              onPressed: _saving ? null : () => _delete(user.id),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<OperationType>(
            segments: [
              ButtonSegment(
                value: OperationType.expense,
                label: Text(l10n.expense),
                icon: const Icon(Icons.remove),
              ),
              ButtonSegment(
                value: OperationType.income,
                label: Text(l10n.income),
                icon: const Icon(Icons.add),
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
            key: const ValueKey('operation_amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.amount),
          ),
          const SizedBox(height: 12),
          accounts.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Text(l10n.genericError),
            data: (items) => DropdownButtonFormField<String>(
              key: const ValueKey('operation_account_selector'),
              initialValue: _accountId,
              decoration: InputDecoration(labelText: l10n.account),
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
            key: const ValueKey('operation_category_selector'),
            initialValue: _categoryId,
            decoration: InputDecoration(labelText: l10n.category),
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
            key: const ValueKey('operation_description'),
            controller: _description,
            decoration: InputDecoration(labelText: l10n.descriptionOptional),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('operation_save'),
            onPressed: _saving ? null : () => _save(user.id, accounts.valueOrNull ?? const []),
            child: _saving ? const CircularProgressIndicator() : Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<void> _save(String userId, List<FinanceAccount> accounts) async {
    FinanceAccount? account;
    for (final item in accounts) {
      if (item.id == _accountId) account = item;
    }
    int? amountMinor;
    try {
      amountMinor = account == null ? null : MoneyParser.minorUnits(_amount.text, account.currency);
    } on FormatException {
      amountMinor = null;
    }
    if (amountMinor == null || account == null || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).completeRequiredFields)),
      );
      return;
    }
    setState(() => _saving = true);
    final existing = widget.initialOperation;
    final draft = FinancialOperationDraft(
      type: _type,
      amountMinor: amountMinor,
      currency: account.currency,
      accountId: account.id,
      categoryId: _categoryId,
      occurredAt: existing?.occurredAt ?? DateTime.now().toUtc(),
      monthKey: existing?.monthKey ?? _currentMonthKey(),
      description: _description.text,
      idempotencyKey: _idempotencyKey ??= '${DateTime.now().microsecondsSinceEpoch}_operation',
    );
    try {
      if (existing != null) {
        await ref
            .read(canonicalActionsProvider)
            .updateOperation(
              userId,
              FinancialOperation(
                id: existing.id,
                type: draft.type,
                amountMinor: draft.amountMinor,
                currency: draft.currency,
                accountId: draft.accountId,
                categoryId: draft.categoryId,
                monthKey: draft.monthKey ?? existing.monthKey,
                occurredAt: draft.occurredAt,
                description: draft.description,
                status: existing.status,
                idempotencyKey: existing.idempotencyKey,
                createdAt: existing.createdAt,
                updatedAt: existing.updatedAt,
              ),
            );
        if (mounted) context.pop();
      } else {
        final status = await ref.read(canonicalActionsProvider).createOperation(userId, draft);
        if (mounted && status == SyncState.confirmed) {
          context.pop();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status == SyncState.rejected
                    ? AppLocalizations.of(context).offlineRejected
                    : AppLocalizations.of(context).savedPending,
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).genericError)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String userId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteOperation),
        content: Text(l10n.confirmDeleteOperation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteOperation),
          ),
        ],
      ),
    );
    final operation = widget.initialOperation;
    if (confirmed != true || operation == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(canonicalActionsProvider).deleteOperation(userId, operation.id);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.genericError)),
        );
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

String _minorAmountInput(int amountMinor, String currency) {
  final decimals = MoneyParser.zeroDecimalCurrencies.contains(currency.toUpperCase()) ? 0 : 2;
  if (decimals == 0) return amountMinor.toString();
  final whole = amountMinor ~/ 100;
  final fraction = (amountMinor % 100).toString().padLeft(2, '0');
  return '$whole.$fraction';
}
