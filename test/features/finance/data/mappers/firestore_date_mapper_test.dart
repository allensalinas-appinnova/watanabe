import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/data/mappers/firestore_date_mapper.dart';

void main() {
  test('maps a Firestore Timestamp', () {
    final date = DateTime.utc(2026, 10, 5, 14, 30);

    expect(
      FirestoreDateMapper.toDateTime(Timestamp.fromDate(date))?.isAtSameMomentAs(date),
      isTrue,
    );
  });

  test('maps an ISO-8601 string from the web client', () {
    final date = DateTime.parse('2026-10-05T14:30:00.000Z');

    expect(FirestoreDateMapper.toDateTime(date.toIso8601String()), date);
  });

  test('returns null for an invalid or missing value', () {
    expect(FirestoreDateMapper.toDateTime('not-a-date'), isNull);
    expect(FirestoreDateMapper.toDateTime(null), isNull);
  });
}
