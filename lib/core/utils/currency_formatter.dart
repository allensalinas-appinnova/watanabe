import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static final _cop = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$ ',
    decimalDigits: 0,
  );

  static String cop(num value) => _cop.format(value);
}
