import 'package:flutter_test/flutter_test.dart';

import 'package:personal_finance/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats Colombian pesos without decimal places', () {
      expect(CurrencyFormatter.cop(12480), contains('12.480'));
    });
  });
}
