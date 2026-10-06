import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/domain/value_objects/month_key.dart';

void main() {
  test('creates a local calendar month key', () {
    expect(MonthKey.fromDate(DateTime(2026, 10, 5)).value, '2026-10');
  });

  test('rejects invalid month keys', () {
    expect(() => MonthKey.parse('2026-13'), throwsFormatException);
    expect(() => MonthKey.parse('October 2026'), throwsFormatException);
  });
}
