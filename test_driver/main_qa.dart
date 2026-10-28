import 'package:flutter/foundation.dart';
import 'package:flutter_driver/driver_extension.dart';

import 'package:personal_finance/main.dart' as app;

/// QA-only entry point that enables Flutter Driver without exposing the
/// extension through the normal app entry point or release builds.
Future<void> main() async {
  if (!kDebugMode) {
    throw StateError('The QA entry point is available only in debug mode.');
  }

  enableFlutterDriverExtension();
  await app.main();
}
