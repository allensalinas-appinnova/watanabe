import 'package:flutter_test/flutter_test.dart';

import 'package:personal_finance/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats Colombian pesos without decimal places', () {
      expect(CurrencyFormatter.cop(12480), contains('12.480'));
    });

    test('formats minor units using the currency scale', () {
      expect(CurrencyFormatter.formatMinor(100, 'COP'), contains('100'));
      expect(CurrencyFormatter.formatMinor(10000, 'USD'), contains('100.00'));
    });

    test('separates the currency code from the amount', () {
      expect(CurrencyFormatter.formatMinor(100000, 'COP', locale: 'es_CO'), 'COP 100.000');
      expect(CurrencyFormatter.formatMinor(123456, 'BRL', locale: 'pt_BR'), 'BRL 1.234,56');
    });

    test('normalizes currency code casing without changing the amount', () {
      expect(CurrencyFormatter.formatMinor(1000, 'cop', locale: 'es_CO'), 'COP 1.000');
    });

    test('uses a visible space after the currency code in amount inputs', () {
      expect(CurrencyFormatter.inputPrefix('COP'), 'COP ');
      expect(CurrencyFormatter.inputPrefix('mxn'), 'MXN ');
    });
  });
}
