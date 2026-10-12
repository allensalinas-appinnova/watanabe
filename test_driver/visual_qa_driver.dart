import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory('build/visual-qa/iteration-7');
  await output.create(recursive: true);

  await integrationDriver(
    onScreenshot: (name, image, [args]) async {
      final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      await File('${output.path}/$safeName.png').writeAsBytes(image, flush: true);
      // The screenshot callback runs on the host. Returning true makes capture
      // part of the test result and fails the driver if a file cannot be saved.
      return true;
    },
  );
}
