import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/budget_flow_type.dart';
import '../../domain/entities/budget_item.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import '../providers/canonical_finance_providers.dart';
import 'canonical_budget_detail_screen.dart';

class CanonicalBudgetItemEditScreen extends ConsumerStatefulWidget {
  const CanonicalBudgetItemEditScreen({
    required this.budgetId,
    this.itemId,
    this.initialItem,
    super.key,
  });

  final String budgetId;
  final String? itemId;
  final BudgetItem? initialItem;

  bool get isCreating => itemId == null;

  @override
  ConsumerState<CanonicalBudgetItemEditScreen> createState() =>
      _CanonicalBudgetItemEditScreenState();
}

class _CanonicalBudgetItemEditScreenState extends ConsumerState<CanonicalBudgetItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _day = TextEditingController();
  BudgetItem? _loadedItem;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  void _populate(BudgetItem item, String currency) {
    if (_loadedItem?.id == item.id) return;
    _loadedItem = item;
    _description.text = item.description;
    _amount.text = _minorToInput(item.amountMinor, CurrencyFormatter.decimalDigits(currency));
    _day.text = item.dayOfMonth.toString();
  }

  String _minorToInput(int amountMinor, int decimals) {
    if (decimals == 0) return amountMinor.toString();
    final major = amountMinor ~/ 100;
    final minor = (amountMinor % 100).toString().padLeft(2, '0');
    return '$major.$minor';
  }

  Future<void> _save(String userId, Budget budget, BudgetItem? item) async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    final amountText = _amount.text.trim();
    int amountMinor;
    try {
      amountMinor = MoneyParser.minorUnits(amountText, budget.currency);
    } on FormatException {
      _formKey.currentState!.validate();
      return;
    }
    final day = int.tryParse(_day.text.trim());
    if (day == null || day < 1 || day > 31) {
      setState(() => _error = l10n.budgetDayRange);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final actions = ref.read(canonicalActionsProvider);
      if (item == null) {
        await actions.addBudgetItem(
          userId,
          budget.id,
          CanonicalBudgetItemDraft(
            description: _description.text.trim(),
            amountMinor: amountMinor,
            dayOfMonth: day,
          ),
        );
      } else {
        await actions.updateBudgetItem(
          userId,
          budget.id,
          BudgetItem(
            id: item.id,
            description: _description.text.trim(),
            amountMinor: amountMinor,
            dayOfMonth: day,
            createdAt: item.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      }
      ref
        ..invalidate(
          canonicalFinanceRepositoryItemsProvider((userId: userId, budgetId: budget.id)),
        )
        ..invalidate(canonicalBudgetProvider((userId: userId, budgetId: budget.id)))
        ..invalidate(canonicalBudgetsProvider((userId: userId, monthKey: budget.monthKey)));
      if (mounted) {
        // Returning to the refreshed detail is the success feedback. A snackbar
        // here survives the pop and can cover the next screen's fixed action.
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = widget.isCreating ? l10n.budgetAddItemFailed : l10n.budgetEditFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final budgetKey = (userId: user.id, budgetId: widget.budgetId);
    final budgetState = ref.watch(canonicalBudgetProvider(budgetKey));
    final itemsState = ref.watch(canonicalFinanceRepositoryItemsProvider(budgetKey));
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: budgetState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _EditLoadError(message: l10n.genericError),
          data: (budget) {
            if (budget == null) return _EditLoadError(message: l10n.genericError);
            return itemsState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _EditLoadError(message: l10n.genericError),
              data: (items) {
                BudgetItem? item = widget.initialItem;
                if (!widget.isCreating) {
                  item ??= items.cast<BudgetItem?>().firstWhere(
                    (candidate) => candidate?.id == widget.itemId,
                    orElse: () => null,
                  );
                  if (item == null) return _EditLoadError(message: l10n.genericError);
                  _populate(item, budget.currency);
                }
                final loadedItem = item;
                final locale = Localizations.localeOf(context).toLanguageTag();
                final month = DateFormatLocal.monthLabel(budget, locale);
                final decimals = CurrencyFormatter.decimalDigits(budget.currency);
                return Column(
                  children: [
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                          children: [
                            Text(
                              l10n.appTitle,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.blueDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton.icon(
                              key: ValueKey(
                                widget.isCreating
                                    ? 'budget_item_add_back'
                                    : 'budget_item_edit_back',
                              ),
                              onPressed: _saving ? null : () => context.pop(),
                              style: TextButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.zero,
                              ),
                              icon: const Icon(Icons.chevron_left),
                              label: Text(l10n.budgetDetailTitle),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${(budget.flowType == BudgetFlowType.income ? l10n.income : l10n.expense).toUpperCase()} · ${month.toUpperCase()}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.isCreating ? l10n.budgetAddItem : l10n.budgetEditItemTitle,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.isCreating
                                  ? l10n.budgetAddItemSubtitle
                                  : l10n.budgetEditItemSubtitle,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(height: 28),
                            _LabeledInput(
                              label: l10n.budgetDescription,
                              child: TextFormField(
                                key: ValueKey(
                                  widget.isCreating
                                      ? 'budget_item_create_description'
                                      : 'budget_item_edit_description',
                                ),
                                controller: _description,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: const InputDecoration(),
                                validator: (value) => value == null || value.trim().isEmpty
                                    ? l10n.budgetDescriptionRequired
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _LabeledInput(
                              label: l10n.budgetPlannedAmount(budget.currency),
                              child: TextFormField(
                                key: ValueKey(
                                  widget.isCreating
                                      ? 'budget_item_create_amount'
                                      : 'budget_item_edit_amount',
                                ),
                                controller: _amount,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: decimals > 0,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                                ],
                                decoration: const InputDecoration(),
                                validator: (value) {
                                  try {
                                    MoneyParser.minorUnits(value ?? '', budget.currency);
                                    return null;
                                  } on FormatException {
                                    return l10n.budgetAmountPositive;
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            _LabeledInput(
                              label: l10n.budgetExpectedDay,
                              child: TextFormField(
                                key: ValueKey(
                                  widget.isCreating
                                      ? 'budget_item_create_day'
                                      : 'budget_item_edit_day',
                                ),
                                controller: _day,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(),
                                validator: (value) {
                                  final day = int.tryParse(value ?? '');
                                  return day == null || day < 1 || day > 31
                                      ? l10n.budgetDayRange
                                      : null;
                                },
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              l10n.budgetDayRange,
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                l10n.budgetTotalUpdatesHint,
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ),
                            if (_error case final error?) ...[
                              const SizedBox(height: 12),
                              Text(
                                error,
                                key: ValueKey(
                                  widget.isCreating
                                      ? 'budget_item_create_error'
                                      : 'budget_item_edit_error',
                                ),
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          key: ValueKey(
                            widget.isCreating ? 'budget_item_create_save' : 'budget_item_edit_save',
                          ),
                          onPressed: _saving ? null : () => _save(user.id, budget, loadedItem),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.blueDark,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _saving
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  widget.isCreating ? l10n.budgetAddItem : l10n.budgetSaveChanges,
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LabeledInput extends StatelessWidget {
  const _LabeledInput({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
            letterSpacing: .5,
          ),
        ),
      ),
      child,
    ],
  );
}

class _EditLoadError extends StatelessWidget {
  const _EditLoadError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

abstract final class DateFormatLocal {
  static String monthLabel(Budget budget, String locale) =>
      DateFormat('MMMM yyyy', locale).format(DateTime.parse('${budget.monthKey}-01'));
}
