import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';

Future<DateTime?> showBudgetMonthPicker(BuildContext context, DateTime initialMonth) =>
    showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(
        child: _BudgetMonthPicker(initialMonth: initialMonth),
      ),
    );

class _BudgetMonthPicker extends StatefulWidget {
  const _BudgetMonthPicker({required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<_BudgetMonthPicker> createState() => _BudgetMonthPickerState();
}

class _BudgetMonthPickerState extends State<_BudgetMonthPicker> {
  late int _year = widget.initialMonth.year;
  late int _month = widget.initialMonth.month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.budgetSelectMonth),
        leading: IconButton(
          key: const ValueKey('budget_month_close'),
          tooltip: l10n.cancel,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            children: [
              TextButton(
                key: const ValueKey('budget_month_year'),
                onPressed: _chooseYear,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(
                  '$_year',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  key: const ValueKey('budget_month_grid'),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    for (var month = 1; month <= 12; month++)
                      _monthButton(month, DateFormat.MMM(locale).format(DateTime(_year, month))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const ValueKey('budget_month_confirm'),
                  onPressed: () => Navigator.pop(context, DateTime(_year, _month)),
                  style: FilledButton.styleFrom(
                    alignment: Alignment.center,
                    backgroundColor: AppColors.blueDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Center(
                    child: Text(l10n.budgetConfirmMonth, textAlign: TextAlign.center),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthButton(int month, String label) {
    final selected = _month == month;
    return Semantics(
      button: true,
      selected: selected,
      label: DateFormat.MMMM(Localizations.localeOf(context).toString()).format(
        DateTime(_year, month),
      ),
      child: OutlinedButton(
        key: ValueKey('budget_month_option_$month'),
        onPressed: () => setState(() => _month = month),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          alignment: Alignment.center,
          foregroundColor: selected ? Colors.white : AppColors.navy,
          backgroundColor: selected ? AppColors.blueDark : Colors.white,
          side: BorderSide(color: selected ? AppColors.blueDark : AppColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.all(4),
        ),
        child: Center(child: Text(label, textAlign: TextAlign.center)),
      ),
    );
  }

  Future<void> _chooseYear() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(_year, _month),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      helpText: AppLocalizations.of(context).budgetSelectMonth,
    );
    if (selected != null && mounted) setState(() => _year = selected.year);
  }
}
