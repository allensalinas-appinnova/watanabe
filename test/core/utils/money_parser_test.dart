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

    test('accepts the nominal maximum in each currency precision', () {
      expect(MoneyParser.minorUnits('1000000000', 'COP'), 1000000000);
      expect(MoneyParser.minorUnits('1000000000.00', 'BRL'), 100000000000);
      expect(MoneyParser.minorUnits('1000000000,00', 'MXN'), 100000000000);
    });

    test('rejects values above the maximum and oversized input without overflow', () {
      expect(
        () => MoneyParser.minorUnits('1000000001', 'COP'),
        throwsA(
          isA<FormatException>().having((error) => error.message, 'message', 'amount-too-large'),
        ),
      );
      expect(
        () => MoneyParser.minorUnits('1000000000.01', 'BRL'),
        throwsA(
          isA<FormatException>().having((error) => error.message, 'message', 'amount-too-large'),
        ),
      );
      expect(
        () => MoneyParser.minorUnits(List.filled(1000, '9').join(), 'COP'),
        throwsFormatException,
      );
    });

    test('allows zero only for fields whose contract permits it', () {
      expect(MoneyParser.minorUnits('0', 'COP', allowZero: true), 0);
      expect(() => MoneyParser.minorUnits('0', 'COP'), throwsFormatException);
    });
  });
}
