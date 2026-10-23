import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/activity_report.dart';
import '../../domain/entities/balance_adjustment.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';

enum ActivityExportAction { save, share }

typedef ActivityExportCallback =
    Future<bool> Function({
      required List<FinancialOperation> operations,
      required ActivityExportAction action,
    });

class ActivityExportReviewSheet extends StatefulWidget {
  const ActivityExportReviewSheet({
    required this.report,
    required this.accountLabel,
    required this.periodLabel,
    required this.typeLabel,
    required this.accounts,
    required this.categories,
    required this.locale,
    required this.onExport,
    super.key,
  });

  final ActivityReport report;
  final String accountLabel;
  final String periodLabel;
  final String typeLabel;
  final List<FinanceAccount> accounts;
  final List<FinanceCategory> categories;
  final String locale;
  final ActivityExportCallback onExport;

  @override
  State<ActivityExportReviewSheet> createState() => _ActivityExportReviewSheetState();
}

class _ActivityExportReviewSheetState extends State<ActivityExportReviewSheet> {
  bool _includePending = false;
  ActivityExportAction? _busyAction;
  ActivityExportAction? _retryAction;
  bool _hasError = false;

  List<FinancialOperation> get _includedOperations => widget.report.operations
      .where(
        (operation) =>
            operation.status == OperationStatus.confirmed ||
            (_includePending && operation.status == OperationStatus.pending),
      )
      .toList(growable: false);

  Future<void> _export(ActivityExportAction action) async {
    if (_busyAction != null) return;
    final operations = _includedOperations;
    if (operations.isEmpty && widget.report.adjustments.isEmpty) return;
    setState(() {
      _busyAction = action;
      _retryAction = action;
      _hasError = false;
    });
    try {
      final completed = await widget.onExport(operations: operations, action: action);
      if (!mounted) return;
      if (completed) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pendingCount = widget.report.pendingOperationCount;
    final included = _includedOperations;
    final confirmedCount = widget.report.confirmedOperationCount;
    final currencies = {
      ...widget.report.operations.map((operation) => operation.currency),
      ...widget.report.adjustments.map((entry) => entry.adjustment.currency),
    }.toList()..sort();
    final currencySummary = currencies.isEmpty ? '—' : currencies.join(' · ');
    final maxHeight = MediaQuery.sizeOf(context).height * .9;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.appTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(l10n.activityExportTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  l10n.activityExportSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _ExportDetailsCard(
                  accountLabel: widget.accountLabel,
                  periodLabel: widget.periodLabel,
                  typeLabel: widget.typeLabel,
                  currencySummary: currencySummary,
                  confirmedCount: confirmedCount,
                  includedCount: included.length + widget.report.adjustments.length,
                  operations: included.take(3).toList(growable: false),
                  adjustments: widget.report.adjustments.take(3).toList(growable: false),
                  accounts: widget.accounts,
                  categories: widget.categories,
                  locale: widget.locale,
                ),
                if (pendingCount > 0) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    key: const ValueKey('activity_export_include_pending'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _includePending,
                    onChanged: _busyAction == null
                        ? (value) => setState(() => _includePending = value ?? false)
                        : null,
                    title: Text(l10n.activityExportIncludePending),
                    subtitle: Text(
                      _includePending
                          ? l10n.activityExportPendingIncluded(pendingCount)
                          : l10n.activityExportPendingExcluded(pendingCount),
                    ),
                  ),
                ],
                if (_busyAction != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.activityExportPreparing(included.length),
                    key: const ValueKey('activity_export_preparing'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                if (_hasError) ...[
                  const SizedBox(height: 8),
                  Container(
                    key: const ValueKey('activity_export_error'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.activityExportErrorTitle,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(l10n.activityExportErrorMessage),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  l10n.activityExportAllResults,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.activityExportNoNotes,
                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('activity_export_save'),
                    onPressed:
                        (included.isEmpty && widget.report.adjustments.isEmpty) ||
                            _busyAction != null
                        ? null
                        : () => _export(ActivityExportAction.save),
                    child: _busyAction == ActivityExportAction.save
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.activityExportSave),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    key: const ValueKey('activity_export_share'),
                    onPressed:
                        (included.isEmpty && widget.report.adjustments.isEmpty) ||
                            _busyAction != null
                        ? null
                        : () => _export(ActivityExportAction.share),
                    child: _busyAction == ActivityExportAction.share
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.activityExportShare),
                  ),
                ),
                if (_hasError && _retryAction != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      key: const ValueKey('activity_export_retry'),
                      onPressed: () => _export(_retryAction!),
                      child: Text(l10n.retry),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    key: const ValueKey('activity_export_close'),
                    onPressed: _busyAction == null ? () => Navigator.of(context).pop() : null,
                    child: Text(l10n.close),
                  ),
                ),
                Center(
                  child: Text(
                    l10n.activityExportCloseHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _ExportDetailsCard extends StatelessWidget {
  const _ExportDetailsCard({
    required this.accountLabel,
    required this.periodLabel,
    required this.typeLabel,
    required this.currencySummary,
    required this.confirmedCount,
    required this.includedCount,
    required this.operations,
    required this.adjustments,
    required this.accounts,
    required this.categories,
    required this.locale,
  });

  final String accountLabel;
  final String periodLabel;
  final String typeLabel;
  final String currencySummary;
  final int confirmedCount;
  final int includedCount;
  final List<FinancialOperation> operations;
  final List<BalanceAdjustmentActivityEntry> adjustments;
  final List<FinanceAccount> accounts;
  final List<FinanceCategory> categories;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('activity_export_details'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _ExportDetailLine(label: l10n.activityExportAccount, value: accountLabel),
          _ExportDetailLine(label: l10n.activityExportPeriod, value: periodLabel),
          _ExportDetailLine(label: l10n.activityExportType, value: typeLabel),
          _ExportDetailLine(
            label: l10n.activityExportCurrencyFormat,
            value: '$currencySummary · CSV',
          ),
          const Divider(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.activityExportConfirmedCount(confirmedCount),
              style: theme.textTheme.labelLarge,
            ),
          ),
          if (includedCount != confirmedCount)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.activityExportIncludedCount(includedCount),
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (final operation in operations)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _OperationPreview(
                operation: operation,
                accounts: accounts,
                categories: categories,
                locale: locale,
                l10n: l10n,
              ),
            ),
          for (final entry in adjustments)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _AdjustmentPreview(
                entry: entry,
                accounts: accounts,
                locale: locale,
                l10n: l10n,
              ),
            ),
          if (includedCount > operations.length + adjustments.length)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.activityExportMoreCount(
                    includedCount - operations.length - adjustments.length,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExportDetailLine extends StatelessWidget {
  const _ExportDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _OperationPreview extends StatelessWidget {
  const _OperationPreview({
    required this.operation,
    required this.accounts,
    required this.categories,
    required this.locale,
    required this.l10n,
  });

  final FinancialOperation operation;
  final List<FinanceAccount> accounts;
  final List<FinanceCategory> categories;
  final String locale;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final accountNames = {for (final account in accounts) account.id: account.name};
    final categoryNames = {
      for (final category in categories) category.id: category.customName ?? category.id,
    };
    final account = operation.type == OperationType.transfer
        ? '${accountNames[operation.sourceAccountId] ?? l10n.activityCsvUnknownAccount} → '
              '${accountNames[operation.destinationAccountId] ?? l10n.activityCsvUnknownAccount}'
        : accountNames[operation.accountId] ?? l10n.activityCsvUnknownAccount;
    final category = operation.type == OperationType.transfer
        ? ''
        : categoryNames[operation.categoryId] ?? l10n.activityCsvUnknownCategory;
    final date = DateFormat.yMMMd(locale).add_Hm().format(operation.occurredAt.toLocal());
    final title = operation.description.isNotEmpty
        ? operation.description
        : switch (operation.type) {
            OperationType.income => l10n.income,
            OperationType.expense => l10n.expense,
            OperationType.transfer => l10n.transferOperationLabel,
            OperationType.expenseRefund => l10n.debtRefund,
            OperationType.debtAdjustment => l10n.debtAdjust,
          };
    final amount = CurrencyFormatter.formatMinor(
      operation.amountMinor,
      operation.currency,
      locale: locale,
    );
    final status = operation.status == OperationStatus.pending
        ? l10n.activityCsvPending
        : l10n.activityCsvConfirmed;
    final subtitle = [date, account, if (category.isNotEmpty) category, status].join(' · ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final details = Text(
          subtitle.isEmpty ? title : '$title\n$subtitle',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        );
        final amountLabel = Text(
          '$amount · ${operation.currency}',
          textAlign: constraints.maxWidth < 300 ? TextAlign.start : TextAlign.end,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        );
        if (constraints.maxWidth < 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [details, const SizedBox(height: 2), amountLabel],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: details),
            const SizedBox(width: 8),
            amountLabel,
          ],
        );
      },
    );
  }
}

class _AdjustmentPreview extends StatelessWidget {
  const _AdjustmentPreview({
    required this.entry,
    required this.accounts,
    required this.locale,
    required this.l10n,
  });

  final BalanceAdjustmentActivityEntry entry;
  final List<FinanceAccount> accounts;
  final String locale;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final row = entry.adjustment;
    var name = l10n.activityCsvUnknownAccount;
    for (final account in accounts) {
      if (account.id == row.accountId) name = account.name;
    }
    String amount(int value) => CurrencyFormatter.formatMinor(value, row.currency, locale: locale);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        '${l10n.activityBalanceAdjustmentType} · $name\n${DateFormat.yMMMd(locale).add_Hm().format(entry.adjustedAt.toLocal())}\n${l10n.activityBalanceAdjustmentEntry(amount(row.previousBalanceMinor), amount(row.targetBalanceMinor), amount(row.deltaMinor))}',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
