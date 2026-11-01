import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  final directory = Directory('artifacts/document-imports');
  await directory.create(recursive: true);
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      await File(p.join(directory.path, '$name.png')).writeAsBytes(bytes);
      return bytes.length > 8;
    },
    responseDataCallback: (data) async {
      final result = <String, dynamic>{...?data};
      final screenshots = result['screenshots'];
      if (screenshots is List) {
        result['screenshots'] = screenshots
            .whereType<Map<dynamic, dynamic>>()
            .map((shot) => {'screenshotName': shot['screenshotName']})
            .toList();
      }
      await File(p.join(directory.path, 'result.json')).writeAsString(jsonEncode(result));
    },
    writeResponseOnFailure: true,
  );
}
