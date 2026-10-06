import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/domain/value_objects/money.dart';

void main() {
  test('stores exact minor units without floating point conversion', () {
    const money = Money(amountMinor: 12505, currency: 'BRL');

    expect(money.amountMinor, 12505);
    expect(money.currency, 'BRL');
  });

  test('copyWith preserves the other money fields', () {
    const money = Money(amountMinor: 1000, currency: 'COP');

    final updated = money.copyWith(amountMinor: 2500);

    expect(updated.amountMinor, 2500);
    expect(updated.currency, 'COP');
  });
}
