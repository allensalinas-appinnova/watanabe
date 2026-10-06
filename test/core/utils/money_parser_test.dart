import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/utils/money_parser.dart';

void main() {
  group('MoneyParser', () {
    test('parses Latin American decimal notation without doubles', () {
      expect(MoneyParser.minorUnits('1.234,56', 'BRL'), 123456);
      expect(MoneyParser.minorUnits('1,234.56', 'USD'), 123456);
    });

    test('parses zero-decimal currencies as integer units', () {
      expect(MoneyParser.minorUnits('1.234', 'COP'), 1234);
    });

    test('rejects invalid and non-positive amounts', () {
      expect(() => MoneyParser.minorUnits('', 'COP'), throwsFormatException);
      expect(() => MoneyParser.minorUnits('0', 'COP'), throwsFormatException);
      expect(() => MoneyParser.minorUnits('1,234', 'BRL'), throwsFormatException);
    });
  });
}
