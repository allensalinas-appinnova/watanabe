import 'dart:math' as math;

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/balance_adjustment.dart';
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
    this.balanceAdjustment = 'Balance adjustment',
    this.previousBalance = 'Previous balance',
    this.targetBalance = 'Target balance',
    this.difference = 'Difference',
    this.expenseRefund = 'Expense refund',
    this.debtAdjustment = 'Debt adjustment',
    this.command = 'Command',
    this.principal = 'Principal change',
    this.charges = 'Charges change',
    this.reversal = 'Reversal of',
    this.paymentType = 'Payment type',
    this.cardPayment = 'Credit card payment',
    this.loanPayment = 'Loan payment',
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
  final String balanceAdjustment;
  final String previousBalance;
  final String targetBalance;
  final String difference;
  final String expenseRefund;
  final String debtAdjustment;
  final String command;
  final String principal;
  final String charges;
  final String reversal;
  final String paymentType;
  final String cardPayment;
  final String loanPayment;
}

abstract final class ActivityCsvExporter {
  static String export({
    required Iterable<FinancialOperation> operations,
    Iterable<BalanceAdjustmentActivityEntry> adjustments = const [],
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
        labels.previousBalance,
        labels.targetBalance,
        labels.difference,
        labels.command,
        labels.principal,
        labels.charges,
        labels.reversal,
        labels.paymentType,
      ],
      for (final operation in operations)
        if (operation.status != OperationStatus.rejected)
          [
            _localDateTimeWithOffset(operation.occurredAt),
            switch (operation.type) {
              OperationType.income => labels.income,
              OperationType.expense => labels.expense,
              OperationType.transfer => labels.transfer,
              OperationType.expenseRefund => labels.expenseRefund,
              OperationType.debtAdjustment => labels.debtAdjustment,
            },
            operation.description,
            operation.type == OperationType.transfer
                ? '${accountNames[operation.sourceAccountId] ?? labels.unknownAccount} → '
                      '${accountNames[operation.destinationAccountId] ?? labels.unknownAccount}'
                : accountNames[operation.accountId] ?? labels.unknownAccount,
            operation.type == OperationType.transfer
                ? ''
                : categoryNames[operation.categoryId] ?? labels.unknownCategory,
            _decimalAmount(
              operation.amountMinor *
                  operation.projectionDirection *
                  (operation.type == OperationType.expenseRefund ? -1 : 1),
              operation.currency,
            ),
            operation.currency,
            switch (operation.status) {
              OperationStatus.pending => labels.pending,
              OperationStatus.confirmed => labels.confirmed,
              OperationStatus.rejected => labels.rejected,
            },
            operation.previousBalanceMinor == null
                ? ''
                : _decimalAmount(operation.previousBalanceMinor!, operation.currency),
            operation.targetBalanceMinor == null
                ? ''
                : _decimalAmount(operation.targetBalanceMinor!, operation.currency),
            operation.balanceDeltaMinor == null
                ? ''
                : _decimalAmount(operation.balanceDeltaMinor!, operation.currency),
            operation.debtCommandId ?? '',
            operation.debtCommandId == null
                ? ''
                : _decimalAmount(
                    operation.principalDeltaMinor * operation.projectionDirection,
                    operation.currency,
                  ),
            operation.debtCommandId == null
                ? ''
                : _decimalAmount(
                    operation.chargesDeltaMinor * operation.projectionDirection,
                    operation.currency,
                  ),
            operation.reversalOf ?? '',
            if (operation.isDebtPaymentComponent)
              (accounts
                          .where((account) => account.id == operation.debtAccountId)
                          .firstOrNull
                          ?.isCreditCard ==
                      true
                  ? labels.cardPayment
                  : labels.loanPayment)
            else
              '',
          ],
      for (final entry in adjustments)
        [
          _localDateTimeWithOffset(entry.adjustedAt),
          labels.balanceAdjustment,
          '',
          accountNames[entry.adjustment.accountId] ?? labels.unknownAccount,
          '',
          '',
          entry.adjustment.currency,
          labels.confirmed,
          _decimalAmount(entry.adjustment.previousBalanceMinor, entry.adjustment.currency),
          _decimalAmount(entry.adjustment.targetBalanceMinor, entry.adjustment.currency),
          _decimalAmount(entry.adjustment.deltaMinor, entry.adjustment.currency),
          '',
          '',
          '',
          '',
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
