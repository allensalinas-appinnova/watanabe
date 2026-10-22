import '../../l10n/generated/app_localizations.dart';
import 'money_parser.dart';

abstract final class FinanceInputValidators {
  static String? amount(
    String? value,
    String currency,
    AppLocalizations l10n, {
    bool allowZero = false,
  }) {
    try {
      MoneyParser.minorUnits(value ?? '', currency, allowZero: allowZero);
      return null;
    } on FormatException catch (error) {
      if (error.message == MoneyParser.tooLargeErrorCode) return l10n.amountTooLarge;
      return allowZero ? l10n.invalidInitialBalance : l10n.amountInvalid;
    }
  }

  static String? requiredText(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;

  static bool isValidEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
}
