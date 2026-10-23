import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../providers/canonical_finance_providers.dart';

class ActivityFiltersScreen extends ConsumerStatefulWidget {
  const ActivityFiltersScreen({super.key});

  @override
  ConsumerState<ActivityFiltersScreen> createState() => _ActivityFiltersScreenState();
}

class _ActivityFiltersScreenState extends ConsumerState<ActivityFiltersScreen> {
  static const _maxSelectedAccounts = 10;
  Set<String> _accountIds = {};
  late DateTime _month;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isDateRange = false;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(activityQueryFiltersProvider);
    _accountIds = filters.accountIds.toSet();
    _isDateRange = filters.isDateRange;
    _month = _dateFromMonthKey(filters.monthKey) ?? filters.startAt ?? DateTime.now();
    _startDate = _dateOnly(filters.startAt ?? DateTime(_month.year, _month.month));
    _endDate = _dateOnly(
      filters.endAtExclusive?.subtract(const Duration(days: 1)) ??
          DateTime(_month.year, _month.month + 1, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    final accounts =
        ref.watch(canonicalAccountsProvider(user.id)).valueOrNull ?? const <FinanceAccount>[];
    final locale = Localizations.localeOf(context).toString();
    final monthLabel = DateFormat.yMMMM(locale).format(_month);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.activityFilterTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('activity_filters_close'),
                    tooltip: l10n.close,
                    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                    onPressed: () => popOrGo(context, '/activity'),
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                children: [
                  _SectionLabel(l10n.activityFilterAccount),
                  const SizedBox(height: 6),
                  _SelectionField(
                    key: const ValueKey('activity_filter_account_field'),
                    value: _accountName(accounts, _accountIds, l10n),
                    onTap: () => _chooseAccount(accounts),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(l10n.activityFilterPeriod),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _PeriodOption(
                          label: l10n.activityFilterMonth,
                          selected: !_isDateRange,
                          onTap: () => setState(() => _isDateRange = false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PeriodOption(
                          label: l10n.activityFilterDateRange,
                          selected: _isDateRange,
                          onTap: () => setState(() {
                            if (!_isDateRange) {
                              _startDate = DateTime(_month.year, _month.month);
                              _endDate = DateTime(_month.year, _month.month + 1, 0);
                            }
                            _isDateRange = true;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (!_isDateRange) ...[
                    _SelectionField(
                      key: const ValueKey('activity_filter_month_field'),
                      value: monthLabel,
                      onTap: _chooseMonth,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.activityFilterTimezoneHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            key: const ValueKey('activity_filter_start_date_field'),
                            label: l10n.activityFilterStartDate,
                            value: _dateLabel(_startDate, locale),
                            onTap: () => _chooseDate(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            key: const ValueKey('activity_filter_end_date_field'),
                            label: l10n.activityFilterEndDate,
                            value: _dateLabel(_endDate, locale),
                            onTap: () => _chooseDate(isStart: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.activityFilterRangeHint(monthLabel),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('activity_filter_reset'),
                      onPressed: () {
                        final now = DateTime.now();
                        setState(() {
                          _accountIds.clear();
                          _month = DateTime(now.year, now.month);
                          _startDate = DateTime(now.year, now.month);
                          _endDate = DateTime(now.year, now.month + 1, 0);
                          _isDateRange = false;
                        });
                      },
                      child: Text(l10n.activityFilterReset, textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const ValueKey('activity_filter_apply'),
                        onPressed: _apply,
                        child: Text(l10n.activityFilterApply, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseAccount(List<FinanceAccount> accounts) async {
    final l10n = AppLocalizations.of(context);
    final draftSelection = _accountIds.toSet();
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final activeAccounts = accounts.where((account) => account.status == 'active').toList();
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.activityFilterSelectAccount,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.activityFilterMultiSelectHint),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        CheckboxListTile(
                          key: const ValueKey('activity_account_option_all'),
                          value: draftSelection.isEmpty,
                          title: Text(l10n.activityFilterAllAccounts),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (_) => setSheetState(draftSelection.clear),
                        ),
                        for (final account in activeAccounts)
                          CheckboxListTile(
                            key: ValueKey('activity_account_option_${account.id}'),
                            value: draftSelection.contains(account.id),
                            title: Text('${account.name} · ${account.currency}'),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            onChanged:
                                draftSelection.length >= _maxSelectedAccounts &&
                                    !draftSelection.contains(account.id)
                                ? null
                                : (checked) => setSheetState(() {
                                    if (checked ?? false) {
                                      draftSelection.add(account.id);
                                    } else {
                                      draftSelection.remove(account.id);
                                    }
                                  }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('activity_account_selection_done'),
                      onPressed: () => Navigator.pop(context, draftSelection),
                      child: Text(l10n.activityFilterDone),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    setState(() => _accountIds = selected);
  }

  Future<void> _chooseMonth() async {
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => _ActivityMonthPicker(initialMonth: _month),
    );
    if (selected != null) {
      setState(() {
        _month = selected;
        _startDate = DateTime(selected.year, selected.month);
        _endDate = DateTime(selected.year, selected.month + 1, 0);
      });
    }
  }

  Future<void> _chooseDate({required bool isStart}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(_month.year, _month.month),
      lastDate: DateTime(_month.year, _month.month + 1, 0),
    );
    if (selected == null) return;
    setState(() {
      if (isStart) {
        _startDate = _dateOnly(selected);
        if (_startDate.isAfter(_endDate)) _endDate = _startDate;
      } else {
        _endDate = _dateOnly(selected);
        if (_endDate.isBefore(_startDate)) _startDate = _endDate;
      }
    });
  }

  void _apply() {
    ref
        .read(activityQueryFiltersProvider.notifier)
        .apply(
          ActivityQueryFilters(
            accountIds: _accountIds.toList(growable: false),
            monthKey: _isDateRange ? null : _monthKey(_month),
            startAt: _isDateRange ? _startDate : null,
            endAtExclusive: _isDateRange ? _endDate.add(const Duration(days: 1)) : null,
            hasBeenApplied: true,
          ),
        );
    popOrGo(context, '/activity');
  }

  String _accountName(
    List<FinanceAccount> accounts,
    Set<String> accountIds,
    AppLocalizations l10n,
  ) {
    if (accountIds.isEmpty) return l10n.activityFilterAllAccounts;
    if (accountIds.length == 1) {
      final id = accountIds.single;
      for (final account in accounts) {
        if (account.id == id) return '${account.name} · ${account.currency}';
      }
    }
    return l10n.activityFilterSelectedAccountCount(accountIds.length);
  }
}

String _monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

DateTime? _dateFromMonthKey(String? key) {
  if (key == null) return null;
  final parts = key.split('-');
  if (parts.length != 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return DateTime(year, month);
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _dateLabel(DateTime date, String locale) => DateFormat('d MMM y', locale).format(date);

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({required this.value, required this.onTap, super.key});
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PeriodOption extends StatelessWidget {
  const _PeriodOption({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Material(
      color: selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap, super.key});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionLabel(label),
      const SizedBox(height: 6),
      _SelectionField(value: value, onTap: onTap),
    ],
  );
}

class _ActivityMonthPicker extends StatefulWidget {
  const _ActivityMonthPicker({required this.initialMonth});
  final DateTime initialMonth;

  @override
  State<_ActivityMonthPicker> createState() => _ActivityMonthPickerState();
}

class _ActivityMonthPickerState extends State<_ActivityMonthPicker> {
  late int _year = widget.initialMonth.year;
  late int _month = widget.initialMonth.month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.activityFilterSelectMonth,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.close,
                      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
                      onPressed: () => setState(() => _year--),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('$_year', style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
                      onPressed: () => setState(() => _year++),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    itemCount: 12,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisExtent: 48,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final month = index + 1;
                      final selected = month == _month;
                      final label = DateFormat.MMM(locale).format(DateTime(_year, month));
                      return OutlinedButton(
                        key: ValueKey('activity_month_$month'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: selected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          backgroundColor: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surface,
                          side: BorderSide(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => setState(() => _month = month),
                        child: Text(label, textAlign: TextAlign.center),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('activity_month_confirm'),
                    onPressed: () => Navigator.pop(context, DateTime(_year, _month)),
                    child: Text(
                      l10n.activityFilterUseMonth(
                        DateFormat.yMMMM(locale).format(DateTime(_year, _month)),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
