import 'dart:convert';
import 'dart:math';

String newRequestId() {
  final random = Random.secure();
  return base64UrlEncode(List<int>.generate(18, (_) => random.nextInt(256)));
}
