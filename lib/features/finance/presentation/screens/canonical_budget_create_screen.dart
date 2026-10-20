import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import '../providers/canonical_finance_providers.dart';
import '../widgets/budget_month_picker.dart';
import '../widgets/finance_category_icon.dart';
import '../widgets/finance_components.dart';

class CanonicalBudgetCreateScreen extends ConsumerStatefulWidget {
  const CanonicalBudgetCreateScreen({super.key});

  @override
  ConsumerState<CanonicalBudgetCreateScreen> createState() => _CanonicalBudgetCreateScreenState();
}

class _CanonicalBudgetCreateScreenState extends ConsumerState<CanonicalBudgetCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_BudgetItemDraftControllers> _items = [];
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _flowType = 'expense';
  String? _categoryId;
  String? _errorMessage;
  bool _saving = false;
  int _nextItemId = 0;

  @override
  void initState() {
    super.initState();
    _items.add(_newItem());
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_newItem()));
  }

  _BudgetItemDraftControllers _newItem() {
    final item = _BudgetItemDraftControllers(
      id: _nextItemId++,
      day: DateTime.now().day,
    );
    item.amount.addListener(_onAmountChanged);
    return item;
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  void _removeItem(_BudgetItemDraftControllers item) {
    if (_items.length == 1) return;
    setState(() => _items.remove(item));
    item.dispose();
  }

  int _totalMinor(String currency) {
    var total = 0;
    for (final item in _items) {
      try {
        total += MoneyParser.minorUnits(item.amount.text, currency);
      } on FormatException {
        // Partial/invalid input remains visible and is reported on submit.
      }
    }
    return total;
  }

  Future<void> _selectMonth() async {
    final selected = await showBudgetMonthPicker(context, _month);
    if (selected != null && mounted) {
      setState(() {
        _month = DateTime(selected.year, selected.month);
        _errorMessage = null;
      });
    }
  }

  Future<void> _save(String userId, String currency, List<FinanceCategory> categories) async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    final matchingCategories = categories
        .where((category) => category.type.name == _flowType && !category.isArchived)
        .toList();
    if (matchingCategories.isEmpty) {
      setState(() => _errorMessage = l10n.budgetNoCategories);
      return;
    }
    if (_categoryId == null || !matchingCategories.any((item) => item.id == _categoryId)) {
      setState(() => _errorMessage = l10n.budgetSelectCategory);
      return;
    }

    final drafts = <CanonicalBudgetItemDraft>[];
    try {
      for (final item in _items) {
        final description = item.description.text.trim();
        if (description.isEmpty) throw const FormatException('description');
        final amountMinor = MoneyParser.minorUnits(item.amount.text, currency);
        if (item.day < 1 || item.day > 31) throw const FormatException('day');
        drafts.add(
          CanonicalBudgetItemDraft(
            description: description,
            amountMinor: amountMinor,
            dayOfMonth: item.day,
          ),
        );
      }
    } on FormatException {
      setState(() => _errorMessage = l10n.budgetValidateItems);
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(canonicalActionsProvider)
          .createBudget(
            userId,
            categoryId: _categoryId!,
            flowType: _flowType,
            monthKey: DateFormat('yyyy-MM').format(_month),
            currency: currency,
            items: drafts,
          );
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().toLowerCase();
      setState(() {
        _errorMessage =
            message.contains('already exists') ||
                message.contains('already-exists') ||
                message.contains('budget-already-exists')
            ? l10n.budgetAlreadyExists
            : l10n.budgetSaveFailed;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));

    final categoriesAsync = ref.watch(canonicalCategoriesProvider(user.id));
    final categories = categoriesAsync.valueOrNull ?? const <FinanceCategory>[];
    final profile = ref.watch(canonicalUserProfileProvider(user.id)).valueOrNull;
    final currency = profile?.defaultCurrency ?? 'COP';
    final availableCategories = categories
        .where((category) => category.type.name == _flowType && !category.isArchived)
        .toList();
    if (_categoryId != null && !availableCategories.any((item) => item.id == _categoryId)) {
      _categoryId = null;
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthLabel = DateFormat('MMMM yyyy', locale).format(_month);
    final total = CurrencyFormatter.formatMinor(_totalMinor(currency), currency);

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.appTitle,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.blueDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('budget_create_back'),
                          tooltip: l10n.cancel,
                          onPressed: _saving ? null : () => context.pop(),
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.budgetCreateTitle,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.budgetCreateSubtitle, style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 20),
                    FinanceLabeledField(
                      label: l10n.budgetMonth,
                      child: OutlinedButton(
                        key: const ValueKey('budget_month_selector'),
                        onPressed: _saving ? null : _selectMonth,
                        style: _selectorStyle(context),
                        child: Row(
                          children: [
                            Expanded(child: Text(monthLabel, textAlign: TextAlign.left)),
                            const Icon(Icons.keyboard_arrow_down),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FinanceLabeledField(
                      label: l10n.type,
                      child: DropdownButtonFormField<String>(
                        key: const ValueKey('budget_type_selector'),
                        initialValue: _flowType,
                        isExpanded: true,
                        decoration: const InputDecoration(),
                        items: [
                          DropdownMenuItem(
                            key: const ValueKey('budget_type_expense'),
                            value: 'expense',
                            child: Text(l10n.expenseCategories),
                          ),
                          DropdownMenuItem(
                            key: const ValueKey('budget_type_income'),
                            value: 'income',
                            child: Text(l10n.incomeCategories),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() {
                                _flowType = value ?? 'expense';
                                _categoryId = null;
                                _errorMessage = null;
                              }),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FinanceLabeledField(
                      label: l10n.budgetCategory,
                      child: categoriesAsync.isLoading
                          ? const LinearProgressIndicator()
                          : DropdownButtonFormField<String>(
                              key: const ValueKey('budget_category_selector'),
                              initialValue: _categoryId,
                              isExpanded: true,
                              decoration: const InputDecoration(),
                              hint: Text(l10n.budgetSelectCategory),
                              items: availableCategories
                                  .map(
                                    (category) => DropdownMenuItem(
                                      key: ValueKey('budget_category_option_${category.id}'),
                                      value: category.id,
                                      child: Row(
                                        children: [
                                          FinanceCategoryIcon(
                                            iconId: category.icon,
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
                              onChanged: _saving || availableCategories.isEmpty
                                  ? null
                                  : (value) => setState(() {
                                      _categoryId = value;
                                      _errorMessage = null;
                                    }),
                              validator: (value) =>
                                  value == null ? l10n.budgetSelectCategory : null,
                            ),
                    ),
                    if (!categoriesAsync.isLoading && !categoriesAsync.hasError) ...[
                      if (availableCategories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            l10n.budgetNoCategories,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: OutlinedButton(
                          key: ValueKey(
                            availableCategories.isEmpty
                                ? 'budget_create_category'
                                : 'budget_manage_categories',
                          ),
                          onPressed: () => context.push('/categories'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            availableCategories.isEmpty
                                ? l10n.createCategory
                                : l10n.manageCategories,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.budgetPlannedItems,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          key: const ValueKey('budget_add_item'),
                          onPressed: _saving ? null : _addItem,
                          icon: const Icon(Icons.add),
                          label: Text(l10n.budgetAddItem),
                        ),
                      ],
                    ),
                    for (var index = 0; index < _items.length; index++) ...[
                      const SizedBox(height: 8),
                      _BudgetItemEditor(
                        key: ValueKey('budget_item_${_items[index].id}'),
                        item: _items[index],
                        index: index,
                        currency: currency,
                        canRemove: _items.length > 1,
                        saving: _saving,
                        onRemove: () => _removeItem(_items[index]),
                        onDayChanged: (day) => setState(() => _items[index].day = day),
                        l10n: l10n,
                      ),
                    ],
                    if (categoriesAsync.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(l10n.genericError, style: const TextStyle(color: Colors.red)),
                      ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _errorMessage!,
                            key: const ValueKey('budget_create_error'),
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Material(
              color: Colors.white,
              elevation: 3,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(l10n.plannedAmountLabel)),
                          Text(
                            total,
                            key: const ValueKey('budget_planned_total'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.blueDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('budget_save'),
                          onPressed: _saving || categoriesAsync.isLoading
                              ? null
                              : () => _save(user.id, currency, categories),
                          child: _saving
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(l10n.budgetSave),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _selectorStyle(BuildContext context) => OutlinedButton.styleFrom(
    foregroundColor: AppColors.navy,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    side: const BorderSide(color: AppColors.line),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

class _BudgetItemEditor extends StatelessWidget {
  const _BudgetItemEditor({
    super.key,
    required this.item,
    required this.index,
    required this.currency,
    required this.canRemove,
    required this.saving,
    required this.onRemove,
    required this.onDayChanged,
    required this.l10n,
  });

  final _BudgetItemDraftControllers item;
  final int index;
  final String currency;
  final bool canRemove;
  final bool saving;
  final VoidCallback onRemove;
  final ValueChanged<int> onDayChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${l10n.budgetItem} ${index + 1}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.muted),
              ),
            ),
            if (canRemove)
              IconButton(
                key: ValueKey('budget_remove_item_$index'),
                tooltip: l10n.budgetRemoveItem,
                onPressed: saving ? null : onRemove,
                icon: const Icon(Icons.close, size: 20),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        TextFormField(
          key: ValueKey('budget_item_description_$index'),
          controller: item.description,
          enabled: !saving,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: l10n.budgetItemDescription,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? l10n.budgetDescriptionRequired : null,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('budget_item_amount_$index'),
                controller: item.amount,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: l10n.amount,
                  prefixText: '$currency ',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (value) {
                  try {
                    MoneyParser.minorUnits(value ?? '', currency);
                    return null;
                  } on FormatException {
                    return l10n.budgetAmountPositive;
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<int>(
              key: ValueKey('budget_item_day_$index'),
              value: item.day,
              underline: const SizedBox.shrink(),
              items: [
                for (var day = 1; day <= 31; day++)
                  DropdownMenuItem(value: day, child: Text('${l10n.day} $day')),
              ],
              onChanged: saving
                  ? null
                  : (day) {
                      if (day != null) onDayChanged(day);
                    },
            ),
          ],
        ),
      ],
    ),
  );
}

class _BudgetItemDraftControllers {
  _BudgetItemDraftControllers({required this.id, required this.day});

  final int id;
  final TextEditingController description = TextEditingController();
  final TextEditingController amount = TextEditingController();
  int day;

  void dispose() {
    description.dispose();
    amount.dispose();
  }
}
