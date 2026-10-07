import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static const zeroDecimalCurrencies = {'CLP', 'COP', 'JPY', 'KRW', 'PYG'};

  static final _cop = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$ ',
    decimalDigits: 0,
  );

  static String cop(num value) => _cop.format(value);

  static int decimalDigits(String currency) =>
      zeroDecimalCurrencies.contains(currency.toUpperCase()) ? 0 : 2;

  static String formatMinor(int amountMinor, String currency) {
    final decimals = decimalDigits(currency);
    final divisor = decimals == 0 ? 1 : 100;
    return NumberFormat.currency(
      name: currency,
      decimalDigits: decimals,
    ).format(amountMinor / divisor);
  }
}
