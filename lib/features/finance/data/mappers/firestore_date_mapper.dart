import 'package:cloud_firestore/cloud_firestore.dart';

/// Converts date values written by the web and mobile clients into Dart dates.
///
/// The legacy web client stores transaction dates as ISO-8601 strings while the
/// Flutter client writes Firestore [Timestamp] values. Keeping this conversion
/// at the data boundary prevents either representation from leaking into the
/// domain layer.
abstract final class FirestoreDateMapper {
  static DateTime? toDateTime(Object? value) => switch (value) {
    final Timestamp timestamp => timestamp.toDate(),
    final DateTime dateTime => dateTime,
    final String value => DateTime.tryParse(value),
    _ => null,
  };
}
