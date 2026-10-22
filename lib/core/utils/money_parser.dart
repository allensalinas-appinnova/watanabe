/// Parses user-entered amounts into integer minor units without using doubles.
abstract final class MoneyParser {
  static const zeroDecimalCurrencies = {'CLP', 'COP', 'JPY', 'KRW', 'PYG'};
  static const maxMajorUnits = 1000000000;
  static const tooLargeErrorCode = 'amount-too-large';

  static int maxMinorUnits(String currency) =>
      maxMajorUnits * _powerOfTen(zeroDecimalCurrencies.contains(currency.toUpperCase()) ? 0 : 2);

  static int minorUnits(String raw, String currency, {bool allowZero = false}) {
    final input = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (input.isEmpty) throw const FormatException('Amount is required.');

    final decimals = zeroDecimalCurrencies.contains(currency.toUpperCase()) ? 0 : 2;
    final separatorIndex = input.lastIndexOf(RegExp(r'[.,]'));
    var integerPart = input;
    var fractionalPart = '';
    if (separatorIndex >= 0) {
      final candidateFraction = input.substring(separatorIndex + 1);
      final hasOtherSeparator = input
          .substring(0, separatorIndex)
          .contains(
            RegExp(r'[.,]'),
          );
      if (decimals > 0 && candidateFraction.length == 3 && !hasOtherSeparator) {
        throw const FormatException('Use at most two decimal places.');
      }
      final isThousandsOnly = decimals == 0 && candidateFraction.length == 3 && !hasOtherSeparator;
      if (!isThousandsOnly && candidateFraction.length <= 2) {
        integerPart = input.substring(0, separatorIndex);
        fractionalPart = candidateFraction;
      }
    }

    integerPart = integerPart.replaceAll(RegExp(r'[.,]'), '');
    if (!RegExp(r'^\d+$').hasMatch(integerPart) ||
        !RegExp(r'^\d*$').hasMatch(fractionalPart) ||
        fractionalPart.length > decimals) {
      throw const FormatException('Invalid amount.');
    }
    // Check the whole-unit magnitude before parsing so very long input cannot
    // overflow an int (or lose precision on runtimes with bounded integers).
    final significantInteger = integerPart.replaceFirst(RegExp(r'^0+'), '');
    if (significantInteger.length > maxMajorUnits.toString().length ||
        (significantInteger.length == maxMajorUnits.toString().length &&
            significantInteger.compareTo(maxMajorUnits.toString()) > 0)) {
      throw const FormatException(tooLargeErrorCode);
    }
    final fraction = fractionalPart.padRight(decimals, '0');
    final minor =
        int.parse(integerPart) * _powerOfTen(decimals) +
        (fraction.isEmpty ? 0 : int.parse(fraction));
    if (minor > maxMinorUnits(currency)) {
      throw const FormatException(tooLargeErrorCode);
    }
    if (minor < 0 || (!allowZero && minor == 0)) {
      throw const FormatException('Amount must be positive.');
    }
    return minor;
  }

  static int _powerOfTen(int exponent) {
    var value = 1;
    for (var index = 0; index < exponent; index++) {
      value *= 10;
    }
    return value;
  }
}
