import 'dart:math' as math;

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/financial_operation.dart';

class ActivityCsvLabels {
  const ActivityCsvLabels({
    required this.date,
    required this.type,
    required this.description,
    required this.account,
    required this.category,
    required this.amount,
    required this.currency,
    required this.status,
    required this.income,
    required this.expense,
    required this.transfer,
    required this.pending,
    required this.confirmed,
    required this.rejected,
    required this.unknownAccount,
    required this.unknownCategory,
  });

  final String date;
  final String type;
  final String description;
  final String account;
  final String category;
  final String amount;
  final String currency;
  final String status;
  final String income;
  final String expense;
  final String transfer;
  final String pending;
  final String confirmed;
  final String rejected;
  final String unknownAccount;
  final String unknownCategory;
}

abstract final class ActivityCsvExporter {
  static String export({
    required Iterable<FinancialOperation> operations,
    required List<FinanceAccount> accounts,
    required List<FinanceCategory> categories,
    required ActivityCsvLabels labels,
  }) {
    final accountNames = {for (final account in accounts) account.id: account.name};
    final categoryNames = {
      for (final category in categories) category.id: category.customName ?? category.id,
    };
    final rows = <List<String>>[
      [
        labels.date,
        labels.type,
        labels.description,
        labels.account,
        labels.category,
        labels.amount,
        labels.currency,
        labels.status,
      ],
      for (final operation in operations)
        if (operation.status != OperationStatus.rejected)
          [
            _localDateTimeWithOffset(operation.occurredAt),
            switch (operation.type) {
              OperationType.income => labels.income,
              OperationType.expense => labels.expense,
              OperationType.transfer => labels.transfer,
            },
            operation.description,
            operation.type == OperationType.transfer
                ? '${accountNames[operation.sourceAccountId] ?? labels.unknownAccount} → '
                      '${accountNames[operation.destinationAccountId] ?? labels.unknownAccount}'
                : accountNames[operation.accountId] ?? labels.unknownAccount,
            operation.type == OperationType.transfer
                ? ''
                : categoryNames[operation.categoryId] ?? labels.unknownCategory,
            _decimalAmount(operation.amountMinor, operation.currency),
            operation.currency,
            switch (operation.status) {
              OperationStatus.pending => labels.pending,
              OperationStatus.confirmed => labels.confirmed,
              OperationStatus.rejected => labels.rejected,
            },
          ],
    ];
    return '\uFEFF${rows.map((row) => row.map(_cell).join(',')).join('\r\n')}\r\n';
  }

  static String _decimalAmount(int amountMinor, String currency) {
    final decimals = CurrencyFormatter.decimalDigits(currency);
    if (decimals == 0) return amountMinor.toString();
    final divisor = math.pow(10, decimals).toInt();
    final sign = amountMinor < 0 ? '-' : '';
    final absolute = amountMinor.abs();
    final whole = absolute ~/ divisor;
    final fraction = (absolute % divisor).toString().padLeft(decimals, '0');
    return '$sign$whole.$fraction';
  }

  static String _localDateTimeWithOffset(DateTime value) {
    final local = value.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absoluteMinutes = offset.inMinutes.abs();
    final hours = (absoluteMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (absoluteMinutes % 60).toString().padLeft(2, '0');
    return '${local.toIso8601String()}$sign$hours:$minutes';
  }

  static String _cell(String value) {
    // Guard spreadsheet software from interpreting user-controlled text as a formula.
    final safe = RegExp(r'^[\s]*[=+@\-]').hasMatch(value) ? "'$value" : value;
    return '"${safe.replaceAll('"', '""')}"';
  }
}
