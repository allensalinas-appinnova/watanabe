import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/commitments/presentation/utils/payment_date_suggestion.dart';

void main() {
  group('nextNominalPaymentDate', () {
    test('uses profile calendar date and accepts a due date that is today', () {
      final date = nextNominalPaymentDate(
        instant: DateTime.utc(2026, 10, 6, 20), // Oct 6 in Bogotá.
        timeZone: 'America/Bogota',
        dueDay: 6,
      );
      expect(date, DateTime(2026, 10, 6));
    });

    test('moves to the next month when the nominal day has passed', () {
      final date = nextNominalPaymentDate(
        instant: DateTime.utc(2026, 10, 7, 12),
        timeZone: 'America/Bogota',
        dueDay: 6,
      );
      expect(date, DateTime(2026, 11, 6));
    });

    test('clamps days 29 through 31 to the final day of February', () {
      for (final dueDay in [29, 30, 31]) {
        final date = nextNominalPaymentDate(
          instant: DateTime.utc(2027, 2, 1),
          timeZone: 'UTC',
          dueDay: dueDay,
        );
        expect(date, DateTime(2027, 2, 28));
      }
      final leap = nextNominalPaymentDate(
        instant: DateTime.utc(2028, 2, 1),
        timeZone: 'UTC',
        dueDay: 31,
      );
      expect(leap, DateTime(2028, 2, 29));
    });

    test('crosses month and year boundaries without shifting a nominal day', () {
      final date = nextNominalPaymentDate(
        instant: DateTime.utc(2026, 12, 30),
        timeZone: 'UTC',
        dueDay: 29,
      );
      expect(date, DateTime(2027, 1, 29));
    });
  });
}
