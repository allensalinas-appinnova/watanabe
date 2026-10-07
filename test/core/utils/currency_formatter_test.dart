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
  });
}
