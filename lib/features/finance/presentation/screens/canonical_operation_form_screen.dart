import 'dart:async';
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
import '../../../../core/utils/request_id.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../debts/domain/debt_command.dart';
import '../../../debts/presentation/debt_error_message.dart';
import '../../../debts/presentation/debt_providers.dart';
import '../../../document_imports/domain/document_import.dart';
import '../../../document_imports/presentation/document_field_review_hint.dart';
import '../../../document_imports/presentation/document_import_providers.dart';
import '../../../document_imports/presentation/document_import_screen.dart';
import '../../../document_imports/presentation/resource_usage_screen.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import '../models/budget_item_movement_preset.dart';
import '../models/movement_save_result.dart';
import '../models/picker_usage_order.dart';
import '../providers/canonical_finance_providers.dart';
import '../widgets/finance_account_option.dart';
import '../widgets/finance_category_icon.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_popup_selector.dart';
import '../widgets/planning_follow_up_controls.dart';

class CanonicalOperationFormScreen extends ConsumerStatefulWidget {
  const CanonicalOperationFormScreen({
    super.key,
    this.initialType = OperationType.expense,
    this.initialOperation,
    this.initialAccountId,
    this.initialCategoryId,
    this.initialBudgetItemPreset,
    this.initialOccurredAt,
    this.documentImport,
    this.onDocumentSaved,
  });

  final DocumentImport? documentImport;
  final Future<void> Function(MovementSaveResult)? onDocumentSaved;
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
  String? _editRequestId;
  String? _editRequestSignature;
  Timer? _reviewSaveTimer;
  bool _documentSaved = false;
  bool _confirmedPerformed = false;
  bool _documentReviewLoaded = false;
  bool _documentReviewLoading = false;
  DocumentImportRepository? _documentReviewRepository;
  String? _documentReviewUid;
  bool _documentDateConfirmed = false;
  bool _duplicatesReviewed = false;
  bool _saving = false;
  bool _hasUnsavedChanges = false;
  final _documentEditedFields = <DocumentReviewField>{};
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
    final imported = widget.documentImport;
    if (imported != null) {
      _idempotencyKey = 'doc_${imported.id}';
      _documentDateConfirmed = imported.suggestion.date != null;
      if (imported.suggestion.amountMinor != null && imported.suggestion.currency != null) {
        _amount.text = _minorAmountInput(
          imported.suggestion.amountMinor!,
          imported.suggestion.currency!,
        );
      }
      _description.text = imported.suggestion.description ?? '';
      _restoreDocumentReview();
    }
    _amount.addListener(_markChanged);
    _description.addListener(_markChanged);
  }

  @override
  void dispose() {
    _reviewSaveTimer?.cancel();
    if (widget.documentImport != null && !_documentSaved) unawaited(_persistDocumentReview());
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    final l10n = AppLocalizations.of(context);
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    if (widget.documentImport != null && !_documentReviewLoaded && !_documentReviewLoading) {
      unawaited(_restoreDocumentReview());
    }
    final accounts = ref.watch(canonicalAccountsProvider(user.id));
    final categories = ref.watch(canonicalCategoriesProvider(user.id));
    final recentOperations =
        ref.watch(canonicalRecentOperationsProvider(user.id)).valueOrNull ??
        const <FinancialOperation>[];
    if (widget.documentImport != null &&
        (!_documentReviewLoaded || accounts.isLoading || categories.isLoading)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.documentReview)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
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
    final accountUsageOrder = orderPickerOptionsByUsage(
      options: availableAccounts,
      recentOperations: recentOperations,
      idOf: (account) => account.id,
      usageIdsOf: accountUsageIds,
      compareAlphabetically: (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    final selectedAccountId = _effectiveAccountId(availableAccounts);
    final filteredCategories =
        categories.valueOrNull
            ?.where((category) => category.type.name == _type.name && !category.isArchived)
            .toList() ??
        const <FinanceCategory>[];
    final categoryUsageOrder = orderPickerOptionsByUsage(
      options: filteredCategories,
      recentOperations: recentOperations,
      idOf: (category) => category.id,
      usageIdsOf: (operation) => categoryUsageIds(operation, _type),
      compareAlphabetically: (left, right) => (left.customName ?? left.id).toLowerCase().compareTo(
        (right.customName ?? right.id).toLowerCase(),
      ),
    );
    final selectedCategoryId = filteredCategories.any((category) => category.id == _categoryId)
        ? _categoryId
        : null;
    String? selectedCurrency;
    for (final account in accounts.valueOrNull ?? const <FinanceAccount>[]) {
      if (account.id == selectedAccountId) selectedCurrency = account.currency;
    }
    final formCurrency =
        preset?.currency ?? selectedCurrency ?? widget.documentImport?.suggestion.currency;
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
                  if (widget.documentImport != null) ...[
                    Text(l10n.documentSuggested),
                    if (!_documentDateConfirmed) Text(l10n.documentDateRequired),
                    CheckboxListTile(
                      key: const ValueKey('document_performed'),
                      value: _confirmedPerformed,
                      title: Text(l10n.documentPerformed),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _confirmedPerformed = v ?? false),
                    ),
                    Text(l10n.documentNotPaid),
                    TextButton(
                      onPressed: _saving ? null : () => context.push('/budgets/agenda'),
                      child: Text(l10n.documentPlanInstead),
                    ),
                  ],
                  FinanceOperationTypeSelector(
                    expenseLabel: l10n.expense,
                    incomeLabel: l10n.income,
                    isIncomeSelected: _type == OperationType.income,
                    enabled:
                        preset == null &&
                        widget.initialOperation == null &&
                        widget.documentImport == null,
                    onChanged: (isIncome) {
                      if (widget.initialOperation != null || widget.documentImport != null) return;
                      setState(() {
                        _hasUnsavedChanges = true;
                        _type = isIncome ? OperationType.income : OperationType.expense;
                        _categoryId = null;
                      });
                    },
                  ),
                  if (widget.initialOperation != null)
                    AttachmentList(
                      uid: user.id,
                      compact: true,
                      operationId: widget.initialOperation!.attachmentId == null
                          ? widget.initialOperation!.id
                          : null,
                      attachmentId: widget.initialOperation!.attachmentId,
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
                      onChanged: (_) => _documentFieldChanged(DocumentReviewField.amount),
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
                  _documentFieldHint(DocumentReviewField.amount, currency: formCurrency),
                  _documentFieldHint(DocumentReviewField.currency, currency: formCurrency),
                  const SizedBox(height: 12),
                  FinanceLabeledField(
                    label: l10n.account,
                    child: accounts.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Text(l10n.genericError),
                      data: (_) => availableAccounts.isEmpty && preset != null
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
                          : FinancePopupSelector<String>(
                              key: ValueKey(
                                'operation_account_selector_${selectedAccountId ?? 'none'}',
                              ),
                              controlKey: ValueKey(
                                'operation_account_selector_${selectedAccountId ?? 'none'}_tap',
                              ),
                              title: l10n.account,
                              placeholder: l10n.selectionChoosePrompt,
                              initialValue: selectedAccountId,
                              options: accountUsageOrder.ordered
                                  .map((account) => account.id)
                                  .toList(growable: false),
                              frequentOptions: accountUsageOrder.frequent
                                  .map((account) => account.id)
                                  .toList(growable: false),
                              optionLabel: (id) => financeAccountSelectionLabel(
                                availableAccounts.firstWhere((account) => account.id == id),
                                l10n,
                              ),
                              searchText: (id) => financeAccountSelectionLabel(
                                availableAccounts.firstWhere((account) => account.id == id),
                                l10n,
                              ),
                              optionBuilder: (context, id) => FinanceAccountOption(
                                account: availableAccounts.firstWhere(
                                  (account) => account.id == id,
                                ),
                              ),
                              validator: (value) =>
                                  value == null ? l10n.operationAccountRequired : null,
                              // The budget item constrains currency, not account choice.
                              onSelected: (value) {
                                setState(() {
                                  _accountId = value;
                                  _hasUnsavedChanges = true;
                                });
                                _documentFieldChanged(DocumentReviewField.account);
                                _documentFieldChanged(DocumentReviewField.currency);
                              },
                            ),
                    ),
                  ),
                  _documentFieldHint(
                    DocumentReviewField.account,
                    available: selectedAccountId != null,
                  ),
                  const SizedBox(height: 12),
                  FinanceLabeledField(
                    label: l10n.category,
                    child: FinancePopupSelector<String>(
                      key: const ValueKey('operation_category_selector'),
                      controlKey: const ValueKey('operation_category_selector_tap'),
                      title: l10n.category,
                      placeholder: l10n.selectionChoosePrompt,
                      initialValue: selectedCategoryId,
                      options: categoryUsageOrder.ordered
                          .map((category) => category.id)
                          .toList(growable: false),
                      frequentOptions: categoryUsageOrder.frequent
                          .map((category) => category.id)
                          .toList(growable: false),
                      optionLabel: (id) {
                        final category = filteredCategories.firstWhere((item) => item.id == id);
                        return category.customName ?? category.id;
                      },
                      searchText: (id) {
                        final category = filteredCategories.firstWhere((item) => item.id == id);
                        return '${category.customName ?? category.id} ${category.id}';
                      },
                      optionBuilder: (context, id) {
                        final category = filteredCategories.firstWhere((item) => item.id == id);
                        return Row(
                          children: [
                            FinanceCategoryIcon(
                              iconId: category.icon,
                              colorValue: category.colorValue,
                              size: 28,
                              iconSize: 16,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                category.customName ?? category.id,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      },
                      validator: (value) => value == null ? l10n.operationCategoryRequired : null,
                      onSelected: preset == null
                          ? (value) {
                              setState(() {
                                _categoryId = value;
                                _hasUnsavedChanges = true;
                              });
                              _documentFieldChanged(DocumentReviewField.category);
                            }
                          : null,
                    ),
                  ),
                  _documentFieldHint(
                    DocumentReviewField.category,
                    available: selectedCategoryId != null,
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
                  const SizedBox(height: 12),
                  FinanceLabeledField(
                    label: l10n.descriptionOptional,
                    child: TextField(
                      key: const ValueKey('operation_description'),
                      controller: _description,
                      onChanged: (_) => _documentFieldChanged(DocumentReviewField.description),
                      decoration: const InputDecoration(),
                    ),
                  ),
                  if (_description.text.trim().isNotEmpty)
                    _documentFieldHint(DocumentReviewField.description, available: true),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    key: const ValueKey('operation_more_options'),
                    tilePadding: EdgeInsets.zero,
                    initiallyExpanded: widget.documentImport != null,
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
                      _documentFieldHint(
                        DocumentReviewField.date,
                        available: _documentDateConfirmed,
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
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey('operation_save'),
                    onPressed:
                        _saving ||
                            (widget.documentImport != null &&
                                (!_confirmedPerformed || !_documentDateConfirmed)) ||
                            (preset != null && availableAccounts.isEmpty)
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
    if (widget.documentImport != null) {
      _reviewSaveTimer?.cancel();
      _reviewSaveTimer = Timer(const Duration(milliseconds: 400), _persistDocumentReview);
    }
    if (!_hasUnsavedChanges && mounted) setState(() => _hasUnsavedChanges = true);
  }

  void _documentFieldChanged(DocumentReviewField field) {
    if (widget.documentImport == null || !mounted) return;
    setState(() => _documentEditedFields.add(field));
    _markChanged();
  }

  Widget _documentFieldHint(DocumentReviewField field, {bool? available, String? currency}) {
    final source = widget.documentImport;
    if (source == null) return const SizedBox.shrink();
    var hasValue = available ?? false;
    if (field == DocumentReviewField.amount) {
      try {
        MoneyParser.minorUnits(_amount.text, currency ?? source.suggestion.currency ?? '');
        hasValue = currency != null || source.suggestion.currency != null;
      } on FormatException {
        hasValue = false;
      }
    }
    if (field == DocumentReviewField.currency) hasValue = currency != null;
    final mismatch =
        field == DocumentReviewField.currency &&
        currency != null &&
        source.suggestion.currency != null &&
        currency != source.suggestion.currency;
    return DocumentFieldReviewHint(
      key: ValueKey('document_field_${field.name}'),
      field: field,
      status: mismatch
          ? DocumentReviewStatus.needsReview
          : source.suggestion.statusFor(
              field,
              available: hasValue,
              userEdited: _documentEditedFields.contains(field),
            ),
      detail: mismatch
          ? AppLocalizations.of(
              context,
            ).documentCurrencyMismatch(currency, source.suggestion.currency!)
          : null,
    );
  }

  Future<void> _popAfterSave([Object? result]) async {
    if (!mounted) return;
    final documentCompletion = widget.documentImport != null ? widget.onDocumentSaved : null;
    final preset = widget.initialBudgetItemPreset;
    final uid = ref.read(authSessionProvider).valueOrNull?.id;
    final rootContext = Navigator.of(context, rootNavigator: true).overlay?.context;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _hasUnsavedChanges = false);
    await WidgetsBinding.instance.endOfFrame;
    // The proposal may become approved during this frame and replace the form.
    // Its owner still needs the confirmed outcome to close the import flow.
    if (documentCompletion != null && result is MovementSaveResult) {
      await documentCompletion(result);
      return;
    }
    if (mounted) {
      if (widget.documentImport != null && !context.canPop()) {
        context.go('/home');
        if (result is MovementSaveResult) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                l10n.expenseRegistered(
                  CurrencyFormatter.formatMinor(result.amountMinor, result.currency),
                ),
              ),
            ),
          );
        }
      } else {
        context.pop(result);
      }
    }
    if (result is MovementSaveResult &&
        result.status == MovementSaveStatus.confirmed &&
        result.type == OperationType.expense &&
        preset != null &&
        uid != null &&
        rootContext != null &&
        rootContext.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.expenseRegistered(
              CurrencyFormatter.formatMinor(result.amountMinor, result.currency),
            ),
          ),
          action: SnackBarAction(
            label: l10n.planningFollowUpText('finishAfterSave'),
            onPressed: () => showModalBottomSheet<void>(
              context: rootContext,
              isScrollControlled: true,
              builder: (_) => PlanningFollowUpLauncherSheet(
                userId: uid,
                budgetId: preset.budgetId,
                itemId: preset.itemId,
              ),
            ),
          ),
        ),
      );
    }
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
    if (widget.documentImport != null) {
      await _saveImportedDocument(userId, account, amountMinor);
      return;
    }
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
        final editSignature = [
          draft.amountMinor,
          draft.currency,
          draft.accountId,
          draft.categoryId,
          draft.monthKey,
          draft.occurredAt.millisecondsSinceEpoch,
          draft.description.trim(),
        ].join('|');
        if (_editRequestSignature != editSignature) {
          _editRequestSignature = editSignature;
          _editRequestId = newRequestId();
        }
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
                revision: existing.revision,
              ),
              requestId: _editRequestId!,
            );
        ref
          ..invalidate(canonicalAccountsProvider(userId))
          ..invalidate(activityReportProvider(userId));
        invalidateOperationLists(ref, userId);
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
    if (widget.initialAccountId != null ||
        widget.initialOperation != null ||
        widget.documentImport != null) {
      return null;
    }
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

  Future<void> _persistDocumentReview() async {
    if (_documentSaved || widget.documentImport == null) return;
    final source = widget.documentImport!, uid = _documentReviewUid;
    final repository = _documentReviewRepository;
    if (uid == null || repository == null) return;
    final review = <String, Object?>{
      'amount': _amount.text,
      'description': _description.text,
      'accountId': _accountId,
      'categoryId': _categoryId,
      'date': _occurredAt.toIso8601String(),
      'dateConfirmed': _documentDateConfirmed,
      'performed': _confirmedPerformed,
      'editedFields': _documentEditedFields.map((field) => field.name).toList(),
    };
    final result = await repository.loadDraft(uid, source.generation);
    await result.match<Future<void>>((_) async {}, (draft) async {
      if (draft?.importId == source.id) {
        await repository.saveDraft(
          uid,
          DocumentDraft(
            file: draft!.file,
            importId: source.id,
            generation: source.generation,
            review: {...draft.review, ...review},
          ),
        );
      }
    });
  }

  Future<void> _restoreDocumentReview() async {
    if (_documentReviewLoading || _documentReviewLoaded) return;
    final source = widget.documentImport;
    final uid = ref.read(authSessionProvider).valueOrNull?.id;
    if (source == null || uid == null) return;
    _documentReviewLoading = true;
    final repository = ref.read(documentImportRepositoryProvider);
    _documentReviewRepository = repository;
    _documentReviewUid = uid;
    final result = await repository.loadDraft(uid, source.generation);
    if (!mounted) return;
    _documentReviewLoaded = true;
    _documentReviewLoading = false;
    result.match(
      (_) {
        setState(() {});
      },
      (draft) {
        if (draft?.importId != source.id) {
          setState(() {});
          return;
        }
        final r = draft!.review;
        setState(() {
          _documentEditedFields.addAll(
            DocumentReviewField.values.where(
              (field) =>
                  r['editedFields'] is List && (r['editedFields'] as List).contains(field.name),
            ),
          );
          if (r['amount'] is String) _amount.text = r['amount']! as String;
          if (r['description'] is String) _description.text = r['description']! as String;
          if (r['accountId'] is String) _accountId = r['accountId']! as String;
          if (r['categoryId'] is String) _categoryId = r['categoryId']! as String;
          var invalidDraftDate = false;
          if (r['date'] is String) {
            final restored = DateTime.tryParse(r['date']! as String);
            invalidDraftDate = restored == null || restored.year < 2000 || restored.year > 2100;
            if (!invalidDraftDate) _occurredAt = restored;
          }
          _confirmedPerformed = r['performed'] == true;
          _documentDateConfirmed =
              !invalidDraftDate && (r['dateConfirmed'] == true || source.suggestion.date != null);
          // Older drafts have values but no field-origin markers; preserve their user's choices.
          if (r['amount'] is String &&
              r['amount'] !=
                  (source.suggestion.amountMinor != null && source.suggestion.currency != null
                      ? _minorAmountInput(
                          source.suggestion.amountMinor!,
                          source.suggestion.currency!,
                        )
                      : '')) {
            _documentEditedFields.add(DocumentReviewField.amount);
          }
          if (r['description'] is String &&
              r['description'] != (source.suggestion.description ?? '')) {
            _documentEditedFields.add(DocumentReviewField.description);
          }
          if (r['accountId'] is String && r['accountId'] != source.suggestion.accountId) {
            _documentEditedFields.addAll([
              DocumentReviewField.account,
              DocumentReviewField.currency,
            ]);
          }
          if (r['categoryId'] is String && r['categoryId'] != source.suggestion.categoryId) {
            _documentEditedFields.add(DocumentReviewField.category);
          }
          final suggestedDate = source.suggestion.date;
          if (_documentDateConfirmed &&
              (suggestedDate == null ||
                  _occurredAt.year != suggestedDate.year ||
                  _occurredAt.month != suggestedDate.month ||
                  _occurredAt.day != suggestedDate.day)) {
            _documentEditedFields.add(DocumentReviewField.date);
          }
        });
      },
    );
  }

  Future<void> _saveImportedDocument(String uid, FinanceAccount account, int amount) async {
    final l = AppLocalizations.of(context), source = widget.documentImport!;
    final completion = widget.onDocumentSaved;
    final saved = MovementSaveResult(
      type: OperationType.expense,
      status: MovementSaveStatus.confirmed,
      amountMinor: amount,
      currency: account.currency,
      idempotencyKey: 'doc_${source.id}',
      occurredAt: _occurredAt,
      description: _description.text.trim(),
      accountName: account.name,
    );
    final repository = ref.read(documentImportRepositoryProvider);
    final local = await repository.loadDraft(uid, source.generation);
    await local.match<Future<void>>((_) async {}, (draft) async {
      if (draft == null) return;
      await repository.saveDraft(
        uid,
        DocumentDraft(
          file: draft.file,
          importId: source.id,
          generation: source.generation,
          review: {
            ...draft.review,
            'amount': _amount.text,
            'description': _description.text,
            'accountId': account.id,
            'categoryId': _categoryId,
            'date': _occurredAt.toIso8601String(),
            'dateConfirmed': _documentDateConfirmed,
            'performed': _confirmedPerformed,
            'editedFields': _documentEditedFields.map((field) => field.name).toList(),
          },
        ),
      );
    });
    if (!await ref.read(documentConnectionProvider).hasNetwork()) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.documentOffline)));
      }
      return;
    }
    final result = await repository.approve(
      DocumentApproval(
        source: source,
        accountId: account.id,
        categoryId: _categoryId!,
        currency: account.currency,
        amountMinor: amount,
        occurredAt: _occurredAt,
        monthKey: _currentMonthKey(_occurredAt),
        description: _description.text,
        creditCard: account.isCreditCard,
        duplicatesReviewed: _duplicatesReviewed,
      ),
    );
    if (!mounted) {
      if (result.isRight() && completion != null) await completion(saved);
      return;
    }
    await result.match<Future<void>>(
      (failure) async {
        setState(() => _saving = false);
        if (failure.message.contains('possible-duplicate')) {
          final choice = await showDialog<String>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(l.documentDuplicateTitle),
              content: Text(l.documentDuplicateBody),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, 'activity'), child: Text(l.activity)),
                TextButton(onPressed: () => Navigator.pop(c, 'cancel'), child: Text(l.cancel)),
                FilledButton(
                  onPressed: () => Navigator.pop(c, 'save'),
                  child: Text(l.documentSaveAnyway),
                ),
              ],
            ),
          );
          if (!mounted) return;
          if (choice == 'activity') {
            await context.push('/activity');
          }
          if (choice == 'save') {
            _duplicatesReviewed = true;
            await _save(uid, [account]);
          }
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(documentError(l, failure.message))));
        }
      },
      (id) async {
        _documentSaved = true;
        _reviewSaveTimer?.cancel();
        ref
          ..invalidate(resourceUsageProvider)
          ..invalidate(canonicalAccountsProvider(uid))
          ..invalidate(activityReportProvider(uid));
        invalidateOperationLists(ref, uid);
        if (completion != null) {
          setState(() => _hasUnsavedChanges = false);
          await completion(saved);
        } else {
          await _popAfterSave(saved);
        }
      },
    );
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
          _documentDateConfirmed = true;
          _occurredAt = DateTime(
            selected.year,
            selected.month,
            selected.day,
            _occurredAt.hour,
            _occurredAt.minute,
          );
        },
      );
      _markChanged();
      _documentFieldChanged(DocumentReviewField.date);
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
