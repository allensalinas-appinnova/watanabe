import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static const zeroDecimalCurrencies = {'CLP', 'COP', 'JPY', 'KRW', 'PYG'};

  static final _cop = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$ ',
    decimalDigits: 0,
  );

  static String cop(num value) => _cop.format(value);

  static String inputPrefix(String currency) => '${currency.toUpperCase()} ';

  static int decimalDigits(String currency) =>
      zeroDecimalCurrencies.contains(currency.toUpperCase()) ? 0 : 2;

  static String formatMinor(int amountMinor, String currency, {String? locale}) {
    final normalizedCurrency = currency.toUpperCase();
    final decimals = decimalDigits(currency);
    final divisor = decimals == 0 ? 1 : 100;
    final amountFormat = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = decimals
      ..maximumFractionDigits = decimals;

    // Keep a clear, predictable gap between the ISO currency code and amount.
    // NumberFormat.currency may use a narrow no-break space that looks cramped
    // on some fonts and screen sizes.
    return '$normalizedCurrency ${amountFormat.format(amountMinor / divisor)}';
  }
}
