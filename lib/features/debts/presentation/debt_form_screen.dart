import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/discard_changes_scope.dart';
import '../../../core/routing/finance_route_header.dart';
import '../../../core/utils/async_value_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/money_parser.dart';
import '../../../core/utils/request_id.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../finance/domain/entities/finance_account.dart';
import '../../finance/domain/entities/financial_operation.dart';
import '../../finance/presentation/models/picker_usage_order.dart';
import '../../finance/presentation/providers/canonical_finance_providers.dart';
import '../../finance/presentation/widgets/finance_account_option.dart';
import '../../finance/presentation/widgets/finance_category_icon.dart';
import '../../finance/presentation/widgets/finance_popup_selector.dart';
import '../domain/debt_command.dart';
import 'debt_error_message.dart';
import 'debt_providers.dart';

String debtActionLabel(AppLocalizations l, String action) => switch (action) {
  'create' => l.debtAdd,
  'update' => l.editAccount,
  'purchase' => l.debtPurchase,
  'pay' => l.debtPay,
  'charge' => l.debtCharge,
  'disburse' => l.debtDisburse,
  'refund' => l.debtRefund,
  'adjust' => l.debtAdjust,
  'archive' => l.archive,
  _ => l.debtTitle,
};

class DebtFormScreen extends ConsumerStatefulWidget {
  const DebtFormScreen({
    super.key,
    this.accountId,
    this.action = 'create',
    this.originalOperationId,
    this.initialComponents = const [],
  });
  final String? accountId;
  final String action;
  final String? originalOperationId;
  final List<FinancialOperation> initialComponents;
  @override
  ConsumerState<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends ConsumerState<DebtFormScreen> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  final _fields = <String, TextEditingController>{};
  String _product = 'creditCard', _currency = 'COP', _mode = 'existing';
  String? _bankId, _categoryId;
  late DateTime _date;
  bool _saving = false, _dirty = false, _initialized = false;
  bool _includeInDashboard = true;
  String? _error;
  TextEditingController field(String key, [String initial = '']) =>
      _fields.putIfAbsent(key, () => TextEditingController(text: initial));
  bool get _create => widget.action == 'create';
  bool get _card => _product == 'creditCard';
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    if (widget.initialComponents.isNotEmpty) {
      final first = widget.initialComponents.first;
      _date = first.occurredAt.toLocal();
      _categoryId = widget.initialComponents
          .where((op) => op.categoryId != null)
          .firstOrNull
          ?.categoryId;
      _currency = first.currency;
      field('description', first.description);
      if (first.originalOperationId != null) {
        field('originalOperationId', first.originalOperationId!);
      }
      void seedMoney(String name, int minor) {
        final decimals = CurrencyFormatter.decimalDigits(_currency);
        field(name, decimals == 0 ? '$minor' : (minor / 100).toStringAsFixed(2));
      }

      seedMoney(
        'amountMinor',
        widget.initialComponents.fold(0, (total, op) => total + op.amountMinor),
      );
      seedMoney(
        'principalMinor',
        -widget.initialComponents.fold(0, (total, op) => total + op.principalDeltaMinor),
      );
      seedMoney(
        'previousChargesMinor',
        -widget.initialComponents.fold(0, (total, op) => total + op.chargesDeltaMinor),
      );
      seedMoney(
        'newChargesMinor',
        widget.initialComponents
            .where((op) => op.debtKind == 'newChargePaid')
            .fold(0, (total, op) => total + op.amountMinor),
      );
      _bankId = widget.action == 'disburse'
          ? first.destinationAccountId
          : first.sourceAccountId ?? first.accountId;
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return Scaffold(body: Center(child: Text(l.sessionExpired)));
    final accountsState = ref.watch(canonicalAccountsProvider(user.id));
    final profileState = ref.watch(canonicalUserProfileProvider(user.id));
    if (_create && (profileState.isLoading || profileState.hasError)) {
      return Scaffold(
        body: Center(
          child: profileState.isLoading
              ? const CircularProgressIndicator()
              : TextButton(
                  onPressed: () => ref.invalidate(canonicalUserProfileProvider(user.id)),
                  child: Text(l.retry),
                ),
        ),
      );
    }
    final accounts = accountsState.valueOrNull ?? const <FinanceAccount>[];
    final recentOperations =
        ref.watch(canonicalRecentOperationsProvider(user.id)).valueOrNull ??
        const <FinancialOperation>[];
    final matches = accounts.where((a) => a.id == widget.accountId);
    final account = matches.isEmpty ? null : matches.first;
    if (!_create && (account == null || !account.isDebt)) {
      return Scaffold(
        appBar: FinanceRouteHeader(
          title: l.debtTitle,
          backLabel: l.cancel,
          onBack: () => popOrGo(context, '/accounts'),
        ),
        body: Center(
          child: accountsState.isLoading
              ? const CircularProgressIndicator()
              : Text(l.debtErrorReference),
        ),
      );
    }
    if (!_initialized) {
      _initialized = true;
      final profile = profileState.valueOrNull;
      _currency = account?.currency ?? profile?.defaultCurrency ?? 'COP';
      _product = account?.type ?? 'creditCard';
      _includeInDashboard = account?.includeInDashboard ?? true;
      field('name', account?.name ?? '');
      field('creditor', account?.creditor ?? '');
      field('lastFour', account?.lastFour ?? '');
      if (account?.limitMinor != null) {
        field(
          'limitMinor',
          CurrencyFormatter.decimalDigits(_currency) == 0
              ? '${account!.limitMinor}'
              : (account!.limitMinor! / 100).toStringAsFixed(2),
        );
      }
      if (widget.action == 'adjust') {
        final original = widget.initialComponents.firstOrNull;
        final target = -(original?.targetBalanceMinor ?? account!.currentBalanceMinor);
        field(
          'targetDebtMinor',
          CurrencyFormatter.decimalDigits(_currency) == 0
              ? '$target'
              : (target / 100).toStringAsFixed(2),
        );
      }
    }
    final categoriesState = ref.watch(canonicalCategoriesProvider(user.id));
    final categories = categoriesState.valueOrNull ?? const [];
    final banks = accounts
        .where((a) => !a.isDebt && a.status == 'active' && a.currency == _currency)
        .toList();
    final bankUsageOrder = orderPickerOptionsByUsage(
      options: banks,
      recentOperations: recentOperations,
      idOf: (bank) => bank.id,
      usageIdsOf: accountUsageIds,
      compareAlphabetically: (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    final bankNeeded =
        widget.action == 'pay' || widget.action == 'disburse' || (_create && _mode == 'received');
    final categoryNeeded =
        ['purchase', 'charge'].contains(widget.action) ||
        (widget.action == 'pay' && !_card && _hasPositiveNewCharges);
    final validCategories = categories
        .where((c) => c.type.name == 'expense' && !c.isArchived)
        .toList();
    final suggestedCategory = validCategories.where((category) => category.id == 'interest_fees');
    final suggestedCategoryId = suggestedCategory.isEmpty ? null : suggestedCategory.first.id;
    final shouldSuggestFeesCategory =
        widget.action == 'charge' || (widget.action == 'pay' && !_card && _hasPositiveNewCharges);
    if (shouldSuggestFeesCategory &&
        _categoryId == null &&
        suggestedCategoryId != null &&
        categoriesState.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _categoryId == null) setState(() => _categoryId = suggestedCategoryId);
      });
    }
    final categoryUsageOrder = orderPickerOptionsByUsage(
      options: validCategories,
      recentOperations: recentOperations,
      idOf: (category) => category.id,
      usageIdsOf: (operation) => categoryUsageIds(operation, OperationType.expense),
      compareAlphabetically: (left, right) => (left.customName ?? left.id).toLowerCase().compareTo(
        (right.customName ?? right.id).toLowerCase(),
      ),
    );
    final title = debtActionLabel(l, widget.action);
    Widget input(
      String key,
      String label, {
      bool money = false,
      bool optional = false,
      bool negative = false,
      String initial = '',
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey('debt_$key'),
        controller: field(key, initial),
        enabled: !_saving,
        maxLength: money
            ? 24
            : key == 'description'
            ? 500
            : key == 'lastFour'
            ? 4
            : 80,
        keyboardType: money
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label, prefixText: money ? '$_currency ' : null),
        onChanged: (_) => setState(() => _dirty = true),
        validator: (value) {
          if (optional && (value?.trim().isEmpty ?? true)) return null;
          if (!money) return (value?.trim().isEmpty ?? true) ? l.debtErrorReference : null;
          try {
            _money(key, allowNegative: negative);
            return null;
          } catch (_) {
            return l.debtErrorSplit;
          }
        },
      ),
    );
    return DiscardChangesScope(
      isDirty: _dirty,
      child: Scaffold(
        appBar: FinanceRouteHeader(
          title: title,
          backLabel: l.cancel,
          onBack: () => popOrGo(context, '/accounts'),
        ),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              key: const ValueKey('debt_form_list'),
              padding: const EdgeInsets.all(24),
              children: [
                if (account != null)
                  Text(account.name, style: Theme.of(context).textTheme.headlineSmall),
                Text(l.debtOnline),
                if (accountsState.hasError)
                  TextButton(
                    onPressed: () => ref.invalidate(canonicalAccountsProvider(user.id)),
                    child: Text(l.retry),
                  ),
                if (categoryNeeded && categoriesState.hasError)
                  TextButton(
                    onPressed: () => ref.invalidate(canonicalCategoriesProvider(user.id)),
                    child: Text(l.retry),
                  ),
                const SizedBox(height: 20),
                if (_create) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _product,
                    decoration: InputDecoration(labelText: l.debtProduct),
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(value: 'creditCard', child: Text(l.debtCreditCard)),
                      DropdownMenuItem(value: 'bankLoan', child: Text(l.debtBankLoan)),
                      DropdownMenuItem(value: 'personalLoan', child: Text(l.debtPersonalLoan)),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() {
                            _product = v!;
                            _mode = 'existing';
                            _dirty = true;
                          }),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_create || widget.action == 'update') ...[
                  input('name', l.accountName),
                  if (_create) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: InputDecoration(labelText: l.activityCsvCurrency),
                      items: {
                        ...['COP', 'MXN', 'BRL', 'USD', 'EUR'],
                        _currency,
                      }.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() {
                              _currency = v!;
                              _bankId = null;
                              _dirty = true;
                            }),
                    ),
                    const SizedBox(height: 16),
                    if (!_card) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _mode,
                        decoration: InputDecoration(labelText: l.debtOpeningMode),
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(value: 'existing', child: Text(l.debtExisting)),
                          DropdownMenuItem(value: 'received', child: Text(l.debtReceived)),
                        ],
                        onChanged: _saving
                            ? null
                            : (v) => setState(() {
                                _mode = v!;
                                _dirty = true;
                              }),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_card)
                      input(
                        'debtMinor',
                        l.debtRegistered,
                        money: true,
                        negative: true,
                        initial: '0',
                      )
                    else ...[
                      input('principalMinor', l.debtPrincipal, money: true, initial: '0'),
                      input('chargesMinor', l.debtCharges, money: true, initial: '0'),
                    ],
                  ],
                  input('creditor', l.debtCreditor, optional: true),
                  if (!_create)
                    SwitchListTile(
                      value: _includeInDashboard,
                      title: Text(l.accountIncludeInHomeBalance),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _includeInDashboard = value;
                              _dirty = true;
                            }),
                    ),
                  if (_card) ...[
                    input('lastFour', l.debtLastFour, optional: true),
                    input('limitMinor', l.debtLimit, money: true, optional: true),
                  ],
                ],
                if (!['update', 'archive'].contains(widget.action)) ...[
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                _date = date;
                                _dirty = true;
                              });
                            }
                          },
                    child: Text(
                      '${_create ? l.debtReferenceDate : l.date}: ${MaterialLocalizations.of(context).formatMediumDate(_date)}',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (bankNeeded) ...[
                  FinancePopupSelector<String>(
                    key: ValueKey('debt_bank_$_currency'),
                    controlKey: ValueKey('debt_bank_${_currency}_tap'),
                    title: l.debtBank,
                    placeholder: l.selectionChoosePrompt,
                    initialValue: _bankId,
                    options: bankUsageOrder.ordered.map((bank) => bank.id).toList(),
                    frequentOptions: bankUsageOrder.frequent.map((bank) => bank.id).toList(),
                    optionLabel: (id) {
                      final bank = banks.firstWhere((item) => item.id == id);
                      return financeAccountSelectionLabel(bank, l);
                    },
                    searchText: (id) {
                      final bank = banks.firstWhere((item) => item.id == id);
                      return '${financeAccountSelectionLabel(bank, l)} ${bank.currency}';
                    },
                    optionBuilder: (context, id) => FinanceAccountOption(
                      account: banks.firstWhere((item) => item.id == id),
                    ),
                    validator: (value) => value == null ? l.debtErrorReference : null,
                    onSelected: _saving
                        ? null
                        : (value) => setState(() {
                            _bankId = value;
                            _dirty = true;
                          }),
                  ),
                  const SizedBox(height: 16),
                ],
                if (['purchase', 'charge', 'pay', 'disburse', 'refund'].contains(widget.action))
                  input('amountMinor', l.amount, money: true),
                if (widget.action == 'pay' && !_card) ...[
                  input('principalMinor', l.debtPrincipal, money: true, initial: '0'),
                  input('previousChargesMinor', l.debtPreviousCharges, money: true, initial: '0'),
                  input('newChargesMinor', l.debtNewCharges, money: true, initial: '0'),
                ],
                if (widget.action == 'adjust') ...[
                  if (_card)
                    input('targetDebtMinor', l.balanceAdjustmentTarget, money: true, negative: true)
                  else ...[
                    input('targetPrincipalMinor', l.debtPrincipal, money: true),
                    input('targetChargesMinor', l.debtCharges, money: true),
                  ],
                ],
                if (categoryNeeded) ...[
                  FinancePopupSelector<String>(
                    key: ValueKey('debt_category_selector_${_categoryId ?? 'unselected'}'),
                    controlKey: const ValueKey('debt_category_selector_tap'),
                    title: widget.action == 'pay' ? l.debtNewChargesCategory : l.category,
                    placeholder: l.selectionChoosePrompt,
                    initialValue: _categoryId,
                    options: categoryUsageOrder.ordered.map((category) => category.id).toList(),
                    frequentOptions: categoryUsageOrder.frequent
                        .map((category) => category.id)
                        .toList(),
                    optionLabel: (id) {
                      final category = validCategories.firstWhere((item) => item.id == id);
                      return category.customName ?? category.id;
                    },
                    searchText: (id) {
                      final category = validCategories.firstWhere((item) => item.id == id);
                      return '${category.customName ?? category.id} ${category.id}';
                    },
                    optionBuilder: (context, id) {
                      final category = validCategories.firstWhere((item) => item.id == id);
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
                    validator: (value) => value == null ? l.debtErrorReference : null,
                    onSelected: _saving
                        ? null
                        : (value) => setState(() {
                            _categoryId = value;
                            _dirty = true;
                          }),
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.action == 'refund' && widget.originalOperationId == null)
                  input('originalOperationId', l.debtOriginalPurchase),
                if (!['update', 'archive'].contains(widget.action))
                  input('description', l.activityCsvDescription, optional: true),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton(
                  key: const ValueKey('debt_save'),
                  onPressed: _saving ? null : () => _save(user.id, banks),
                  child: _saving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator())
                      : Text(l.debtReview),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _money(String key, {bool allowNegative = false}) {
    final raw = field(key).text.trim();
    final negative = allowNegative && raw.startsWith('-');
    final minor = MoneyParser.minorUnits(
      negative ? raw.substring(1) : raw,
      _currency,
      allowZero: true,
    );
    return negative ? -minor : minor;
  }

  Future<void> _save(String uid, List<FinanceAccount> banks) async {
    if (!_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    final data = <String, Object?>{
      'action': widget.action,
      if (!_create) 'accountId': widget.accountId,
    };
    if (_create || widget.action == 'update') {
      data['name'] = field('name').text;
      if (!_create) data['includeInDashboard'] = _includeInDashboard;
      for (final key in ['creditor', if (_card) 'lastFour']) {
        if (!_create || field(key).text.trim().isNotEmpty) data[key] = field(key).text.trim();
      }
      if (_card && field('limitMinor').text.trim().isNotEmpty) {
        data['limitMinor'] = _money('limitMinor');
      }
      if (_card && !_create && field('limitMinor').text.trim().isEmpty) data['limitMinor'] = null;
      if (_create) {
        data.addAll({
          'product': _product,
          'currency': _currency,
          'mode': _mode,
          'referenceAt': _date.toUtc().toIso8601String(),
        });
        if (_card) {
          data['debtMinor'] = _money('debtMinor', allowNegative: true);
        } else {
          data['principalMinor'] = _money('principalMinor');
          data['chargesMinor'] = _money('chargesMinor');
        }
      }
    }
    if (!['create', 'update', 'archive'].contains(widget.action)) {
      data['occurredAt'] = _date.toUtc().toIso8601String();
      data['description'] = field('description').text;
    }
    if (_bankId != null &&
        (widget.action == 'pay' ||
            widget.action == 'disburse' ||
            (_create && _mode == 'received'))) {
      data['bankAccountId'] = _bankId;
    }
    final categoryRequired =
        widget.action == 'purchase' ||
        widget.action == 'charge' ||
        (widget.action == 'pay' && !_card && _money('newChargesMinor') > 0);
    if (categoryRequired && _categoryId != null) data['categoryId'] = _categoryId;
    if (['purchase', 'charge', 'pay', 'disburse', 'refund'].contains(widget.action)) {
      data['amountMinor'] = _money('amountMinor');
    }
    if (widget.action == 'pay' && !_card) {
      final split = DebtPaymentSplit(
        principalMinor: _money('principalMinor'),
        previousChargesMinor: _money('previousChargesMinor'),
        newChargesMinor: _money('newChargesMinor'),
      );
      if (!split.matches(_money('amountMinor')) ||
          (split.newChargesMinor > 0 && _categoryId == null)) {
        setState(() => _error = l.debtErrorSplit);
        return;
      }
      data.addAll({
        'principalMinor': split.principalMinor,
        'previousChargesMinor': split.previousChargesMinor,
        'newChargesMinor': split.newChargesMinor,
      });
    }
    if (widget.action == 'adjust') {
      if (_card) {
        data['targetDebtMinor'] = _money('targetDebtMinor', allowNegative: true);
      } else {
        data
          ..['targetPrincipalMinor'] = _money('targetPrincipalMinor')
          ..['targetChargesMinor'] = _money('targetChargesMinor');
      }
    }
    if (widget.action == 'refund') {
      data['originalOperationId'] =
          widget.originalOperationId ?? field('originalOperationId').text.trim();
    }
    final bankName = banks.where((b) => b.id == _bankId).map((b) => b.name).join();
    final review = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.debtReview),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(debtActionLabel(l, widget.action)),
              if (bankName.isNotEmpty) Text('${l.debtBank}: $bankName'),
              for (final entry in data.entries.where((e) => e.key.endsWith('Minor')))
                Text(
                  '${_amountLabel(l, entry.key)}: ${CurrencyFormatter.formatMinor(entry.value! as int, _currency)}',
                ),
              if (widget.action == 'pay' && !_card) Text(l.debtNewChargesExpenseNote),
              Text(l.debtOnline),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.save)),
        ],
      ),
    );
    if (review != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(debtRepositoryProvider)
        .execute(
          uid,
          DebtCommand(
            requestId: _requestId,
            fields: widget.initialComponents.isEmpty
                ? data
                : {
                    'action': 'correct',
                    'accountId': widget.accountId,
                    'originalRequestId': widget.initialComponents.first.debtCommandId,
                    'replacement': data,
                  },
          ),
        );
    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _saving = false;
        _error = debtErrorMessage(l, failure);
      }),
      (saved) async {
        ref
          ..invalidate(canonicalAccountsProvider(uid))
          ..invalidate(activityReportProvider(uid));
        invalidateOperationLists(ref, uid);
        setState(() {
          _dirty = false;
          _saving = false;
        });
        if (saved.overLimit) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.debtOverLimit)));
        }
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) popOrGo(context, '/accounts');
      },
    );
  }

  String _amountLabel(AppLocalizations l, String key) => switch (key) {
    'principalMinor' || 'targetPrincipalMinor' => l.debtPrincipal,
    'chargesMinor' || 'targetChargesMinor' => l.debtCharges,
    'previousChargesMinor' => l.debtPreviousCharges,
    'newChargesMinor' => l.debtNewCharges,
    'limitMinor' => l.debtLimit,
    'targetDebtMinor' || 'debtMinor' => l.debtRegistered,
    _ => l.amount,
  };

  bool get _hasPositiveNewCharges {
    try {
      return _money('newChargesMinor') > 0;
    } on Object {
      return false;
    }
  }
}
