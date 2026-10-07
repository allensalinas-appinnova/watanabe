import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/error/firebase_failure_mapper.dart';

void main() {
  test('maps Firebase network errors to retryable failures without leaking details', () {
    final failure = FirebaseFailureMapper.fromException(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'private account payload',
      ),
    );

    expect(failure, isA<NetworkFailure>());
    expect(failure.message, isNot(contains('private account payload')));
  });

  test('maps permission errors to safe authentication failures', () {
    final failure = FirebaseFailureMapper.fromException(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );

    expect(failure, isA<AuthFailure>());
    expect(failure.message, isNot(contains('permission-denied')));
  });
}
