import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/offline/sync_state.dart';
import '../../../../core/routing/discard_changes_scope.dart';
import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/finance_input_validators.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../debts/domain/debt_command.dart';
import '../../../debts/presentation/debt_error_message.dart';
import '../../../debts/presentation/debt_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import '../models/budget_item_movement_preset.dart';
import '../models/movement_save_result.dart';
import '../providers/canonical_finance_providers.dart';
import '../widgets/finance_category_icon.dart';
import '../widgets/finance_components.dart';

class CanonicalOperationFormScreen extends ConsumerStatefulWidget {
  const CanonicalOperationFormScreen({
    super.key,
    this.initialType = OperationType.expense,
    this.initialOperation,
    this.initialAccountId,
    this.initialCategoryId,
    this.initialBudgetItemPreset,
    this.initialOccurredAt,
  });

  final OperationType initialType;
  final FinancialOperation? initialOperation;
  final String? initialAccountId;
  final String? initialCategoryId;
  final BudgetItemMovementPreset? initialBudgetItemPreset;
  final DateTime? initialOccurredAt;
  @override
  ConsumerState<CanonicalOperationFormScreen> createState() => _CanonicalOperationFormScreenState();
}

class _CanonicalOperationFormScreenState extends ConsumerState<CanonicalOperationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late OperationType _type;
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _accountId;
  String? _categoryId;
  String? _idempotencyKey;
  bool _saving = false;
  bool _hasUnsavedChanges = false;
  DateTime _occurredAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    final operation = widget.initialOperation;
    _occurredAt = widget.initialOccurredAt ?? _occurredAt;
    _type = operation?.type ?? widget.initialType;
    _accountId = operation?.accountId ?? widget.initialAccountId;
    _categoryId = operation?.categoryId ?? widget.initialCategoryId;
    final preset = widget.initialBudgetItemPreset;
    if (preset != null) {
      _type = preset.type;
      _categoryId = preset.categoryId;
      _amount.text = _minorAmountInput(preset.amountMinor, preset.currency);
      _description.text = preset.description;
    }
    if (operation != null) {
      _amount.text = _minorAmountInput(operation.amountMinor, operation.currency);
      _description.text = operation.description;
      _accountId = operation.accountId;
      _categoryId = operation.categoryId;
      _idempotencyKey = operation.idempotencyKey;
      if (operation.debtCommandId != null) _idempotencyKey = null;
      _occurredAt = operation.occurredAt.toLocal();
    }
    _amount.addListener(_markChanged);
    _description.addListener(_markChanged);
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
    final preset = widget.initialBudgetItemPreset;
    final availableAccounts = (accounts.valueOrNull ?? const <FinanceAccount>[])
        .where((account) => account.status == 'active')
        .where(
          (account) =>
              widget.initialOperation == null ||
              (widget.initialOperation!.debtCommandId != null
                  ? account.id == widget.initialOperation!.debtAccountId
                  : !account.isDebt),
        )
        .where(
          (account) => !account.isDebt || (_type == OperationType.expense && account.isCreditCard),
        )
        .where((account) => preset == null || account.currency == preset.currency)
        .toList(growable: false);
    final selectedAccountId = _effectiveAccountId(availableAccounts);
    final filteredCategories =
        categories.valueOrNull
            ?.where((category) => category.type.name == _type.name && !category.isArchived)
            .toList() ??
        const <FinanceCategory>[];
    final selectedCategoryId = filteredCategories.any((category) => category.id == _categoryId)
        ? _categoryId
        : null;
    String? selectedCurrency;
    for (final account in accounts.valueOrNull ?? const <FinanceAccount>[]) {
      if (account.id == selectedAccountId) selectedCurrency = account.currency;
    }
    final formCurrency = preset?.currency ?? selectedCurrency;
    return DiscardChangesScope(
      isDirty: _hasUnsavedChanges,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.back,
            onPressed: () => popOrGo(
              context,
              widget.initialBudgetItemPreset != null
                  ? '/budgets'
                  : widget.initialOperation != null
                  ? '/activity'
                  : '/home',
            ),
            icon: const Icon(Icons.arrow_back),
          ),
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
          padding: const EdgeInsets.all(24),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FinanceOperationTypeSelector(
                    expenseLabel: l10n.expense,
                    incomeLabel: l10n.income,
                    isIncomeSelected: _type == OperationType.income,
                    enabled: preset == null && widget.initialOperation?.debtCommandId == null,
                    onChanged: (isIncome) => setState(() {
                      _hasUnsavedChanges = true;
                      _type = isIncome ? OperationType.income : OperationType.expense;
                      _categoryId = null;
                    }),
                  ),
                  if (preset != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.budgetItemMovementContext(preset.description),
                      key: const ValueKey('budget_item_movement_context'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.blueGrey),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FinanceLabeledField(
                    label: l10n.amount,
                    child: TextFormField(
                      key: const ValueKey('operation_amount'),
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: formCurrency == null
                            ? null
                            : CurrencyFormatter.inputPrefix(formCurrency),
                      ),
                      validator: (value) => formCurrency == null
                          ? l10n.operationAccountRequired
                          : FinanceInputValidators.amount(value, formCurrency, l10n),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FinanceLabeledField(
                    label: l10n.account,
                    child: accounts.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Text(l10n.genericError),
                      data: (items) => availableAccounts.isEmpty && preset != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(l10n.budgetItemNoCompatibleAccount(preset.currency)),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  key: const ValueKey('budget_item_add_compatible_account'),
                                  onPressed: () =>
                                      context.push('/accounts/new?currency=${preset.currency}'),
                                  icon: const Icon(Icons.add),
                                  label: Text(l10n.addAccount),
                                ),
                              ],
                            )
                          : DropdownButtonFormField<String>(
                              key: ValueKey(
                                'operation_account_selector_${selectedAccountId ?? 'none'}',
                              ),
                              initialValue: selectedAccountId,
                              decoration: const InputDecoration(),
                              validator: (value) =>
                                  value == null ? l10n.operationAccountRequired : null,
                              items: (preset == null ? items : availableAccounts)
                                  .map(
                                    (account) => DropdownMenuItem(
                                      value: account.id,
                                      child: Text('${account.name} (${account.currency})'),
                                    ),
                                  )
                                  .toList(),
                              // The budget item constrains currency, not the user's
                              // choice of account among compatible active accounts.
                              onChanged: (value) => setState(() {
                                _accountId = value;
                                _hasUnsavedChanges = true;
                              }),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FinanceLabeledField(
                    label: l10n.category,
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('operation_category_selector'),
                      initialValue: selectedCategoryId,
                      decoration: const InputDecoration(),
                      validator: (value) => value == null ? l10n.operationCategoryRequired : null,
                      items: filteredCategories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Row(
                                children: [
                                  FinanceCategoryIcon(
                                    iconId: category.icon,
                                    colorValue: category.colorValue,
                                    size: 28,
                                    iconSize: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    category.customName ?? category.id,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: preset == null
                          ? (value) => setState(() {
                              _categoryId = value;
                              _hasUnsavedChanges = true;
                            })
                          : null,
                    ),
                  ),
                  if (preset == null) const SizedBox(height: 8),
                  if (preset == null)
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        key: const ValueKey('operation_manage_categories'),
                        onPressed: () => context.push('/categories'),
                        icon: const Icon(Icons.tune),
                        label: Text(l10n.manageCategories),
                      ),
                    ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    key: const ValueKey('operation_more_options'),
                    tilePadding: EdgeInsets.zero,
                    initiallyExpanded: false,
                    title: Text(l10n.moreOptions),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    children: [
                      FinanceLabeledField(
                        label: l10n.date,
                        child: Semantics(
                          button: true,
                          label:
                              '${l10n.date}, ${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(_occurredAt)}',
                          child: InkWell(
                            key: const ValueKey('operation_date_selector'),
                            borderRadius: BorderRadius.circular(14),
                            onTap: _selectDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                suffixIcon: Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(
                                DateFormat.yMMMd(
                                  Localizations.localeOf(context).toString(),
                                ).format(_occurredAt),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FinanceLabeledField(
                        label: l10n.time,
                        child: Semantics(
                          button: true,
                          label:
                              '${l10n.time}, ${TimeOfDay.fromDateTime(_occurredAt).format(context)}',
                          child: InkWell(
                            key: const ValueKey('operation_time_selector'),
                            borderRadius: BorderRadius.circular(14),
                            onTap: _selectTime,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                suffixIcon: Icon(Icons.schedule_outlined),
                              ),
                              child: Text(TimeOfDay.fromDateTime(_occurredAt).format(context)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FinanceLabeledField(
                        label: l10n.descriptionOptional,
                        child: TextField(
                          key: const ValueKey('operation_description'),
                          controller: _description,
                          decoration: const InputDecoration(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey('operation_save'),
                    onPressed: _saving || (preset != null && availableAccounts.isEmpty)
                        ? null
                        : () => _save(user.id, accounts.valueOrNull ?? const []),
                    child: _saving ? const CircularProgressIndicator() : Text(l10n.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _markChanged() {
    if (!_hasUnsavedChanges && mounted) setState(() => _hasUnsavedChanges = true);
  }

  Future<void> _popAfterSave([Object? result]) async {
    if (!mounted) return;
    setState(() => _hasUnsavedChanges = false);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) context.pop(result);
  }

  Future<void> _save(String userId, List<FinanceAccount> accounts) async {
    if (!_formKey.currentState!.validate()) return;
    final selectedAccountId = _effectiveAccountId(accounts);
    FinanceAccount? account;
    for (final item in accounts) {
      if (item.id == selectedAccountId) account = item;
    }
    int? amountMinor;
    amountMinor = account == null ? null : MoneyParser.minorUnits(_amount.text, account.currency);
    final preset = widget.initialBudgetItemPreset;
    if (amountMinor == null || account == null || _categoryId == null) return;
    if (preset != null &&
        (account.currency != preset.currency ||
            _type != preset.type ||
            _categoryId != preset.categoryId)) {
      return;
    }
    setState(() => _saving = true);
    final existing = widget.initialOperation;
    if (account.isDebt) {
      final purchase = <String, Object?>{
        'action': 'purchase',
        'accountId': account.id,
        'amountMinor': amountMinor,
        'categoryId': _categoryId,
        'occurredAt': _occurredAt.toUtc().toIso8601String(),
        'description': _description.text,
        if (preset?.budgetId != null || existing?.budgetId != null)
          'budgetId': preset?.budgetId ?? existing?.budgetId,
        if (preset?.itemId != null || existing?.budgetItemId != null)
          'budgetItemId': preset?.itemId ?? existing?.budgetItemId,
      };
      final result = await ref
          .read(debtRepositoryProvider)
          .execute(
            userId,
            DebtCommand(
              requestId: _idempotencyKey ??= '${DateTime.now().microsecondsSinceEpoch}_debt',
              fields: existing?.debtCommandId == null
                  ? purchase
                  : {
                      'action': 'correct',
                      'accountId': account.id,
                      'originalRequestId': existing!.debtCommandId,
                      'replacement': purchase,
                    },
            ),
          );
      if (!mounted) return;
      await result.match<Future<void>>(
        (failure) async {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(debtErrorMessage(AppLocalizations.of(context), failure))),
          );
        },
        (_) async {
          ref
            ..invalidate(canonicalAccountsProvider(userId))
            ..invalidate(activityReportProvider(userId));
          invalidateOperationLists(ref, userId);
          await _popAfterSave();
        },
      );
      return;
    }
    final categories = ref.read(canonicalCategoriesProvider(userId)).valueOrNull ?? const [];
    String? categoryName;
    for (final category in categories) {
      if (category.id == _categoryId) categoryName = category.customName ?? category.id;
    }
    final draft = FinancialOperationDraft(
      type: _type,
      amountMinor: amountMinor,
      currency: account.currency,
      accountId: account.id,
      categoryId: _categoryId,
      occurredAt: _occurredAt.toUtc(),
      monthKey: _currentMonthKey(_occurredAt),
      description: _description.text,
      idempotencyKey: _idempotencyKey ??= '${DateTime.now().microsecondsSinceEpoch}_operation',
      budgetId: preset?.budgetId ?? existing?.budgetId,
      budgetItemId: preset?.itemId ?? existing?.budgetItemId,
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
                budgetId: existing.budgetId,
                budgetItemId: existing.budgetItemId,
                createdAt: existing.createdAt,
                updatedAt: existing.updatedAt,
              ),
            );
        await _popAfterSave();
      } else {
        final status = await ref.read(canonicalActionsProvider).createOperation(userId, draft);
        if (mounted && (status == SyncState.confirmed || status == SyncState.pending)) {
          await _popAfterSave(
            MovementSaveResult(
              type: draft.type,
              status: status == SyncState.confirmed
                  ? MovementSaveStatus.confirmed
                  : MovementSaveStatus.pending,
              amountMinor: draft.amountMinor,
              currency: draft.currency,
              idempotencyKey: draft.idempotencyKey,
              occurredAt: _occurredAt,
              description: draft.description,
              accountName: account.name,
              categoryName: categoryName,
            ),
          );
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
    if (operation.debtCommandId != null) {
      setState(() => _saving = true);
      final result = await ref
          .read(debtRepositoryProvider)
          .execute(
            userId,
            DebtCommand(
              requestId: _idempotencyKey ??= '${DateTime.now().microsecondsSinceEpoch}_reverse',
              fields: {
                'action': 'reverse',
                'accountId': operation.debtAccountId,
                'originalRequestId': operation.debtCommandId,
              },
            ),
          );
      if (!mounted) return;
      await result.match<Future<void>>(
        (failure) async {
          setState(() => _saving = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(debtErrorMessage(l10n, failure))));
        },
        (_) async {
          invalidateOperationLists(ref, userId);
          ref.invalidate(activityReportProvider(userId));
          await _popAfterSave();
        },
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(canonicalActionsProvider).deleteOperation(userId, operation.id);
      invalidateOperationLists(ref, userId);
      await _popAfterSave();
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

  String _currentMonthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  String? _effectiveAccountId(List<FinanceAccount> accounts) {
    if (_accountId != null) {
      return accounts.any((account) => account.id == _accountId) ? _accountId : null;
    }
    if (widget.initialAccountId != null || widget.initialOperation != null) return null;
    final preset = widget.initialBudgetItemPreset;
    final activeAccounts = accounts
        .where((account) => account.status == 'active')
        .where(
          (account) =>
              widget.initialOperation == null ||
              (widget.initialOperation!.debtCommandId != null
                  ? account.id == widget.initialOperation!.debtAccountId
                  : !account.isDebt),
        )
        .where(
          (account) => !account.isDebt || (_type == OperationType.expense && account.isCreditCard),
        )
        .where((account) => preset == null || account.currency == preset.currency)
        .toList();
    return activeAccounts.length == 1 ? activeAccounts.single.id : null;
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(
        () {
          _hasUnsavedChanges = true;
          _occurredAt = DateTime(
            selected.year,
            selected.month,
            selected.day,
            _occurredAt.hour,
            _occurredAt.minute,
          );
        },
      );
    }
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (selected != null && mounted) {
      setState(
        () {
          _hasUnsavedChanges = true;
          _occurredAt = DateTime(
            _occurredAt.year,
            _occurredAt.month,
            _occurredAt.day,
            selected.hour,
            selected.minute,
          );
        },
      );
    }
  }
}

String _minorAmountInput(int amountMinor, String currency) {
  final decimals = MoneyParser.zeroDecimalCurrencies.contains(currency.toUpperCase()) ? 0 : 2;
  if (decimals == 0) return amountMinor.toString();
  final whole = amountMinor ~/ 100;
  final fraction = (amountMinor % 100).toString().padLeft(2, '0');
  return '$whole.$fraction';
}
