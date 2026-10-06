import 'package:flutter_riverpod/flutter_riverpod.dart';

extension AsyncValueNullable<T> on AsyncValue<T> {
  T? get valueOrNull => asData?.value;
}
