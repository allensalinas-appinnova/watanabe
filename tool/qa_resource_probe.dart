import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Read-only host probe for the debug-only iPhone QA entry point.
/// The VM URL is read privately from Flutter's log and never printed.
Future<void> main(List<String> args) async {
  if (args.length != 2 || !['session', 'resource-access'].contains(args[1])) {
    stderr.writeln(
      'Usage: dart run tool/qa_resource_probe.dart <flutter-log> <session|resource-access>',
    );
    exitCode = 2;
    return;
  }
  final log = await File(args[0]).readAsString();
  final match = RegExp(r'A Dart VM Service[^\n]*available at: (http[^\s]+)').firstMatch(log);
  if (match == null) {
    stderr.writeln('The QA app has not exposed its VM service yet.');
    exitCode = 1;
    return;
  }
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: match.group(1),
    printCommunication: false,
  );
  try {
    final response = await driver.requestData(
      args[1] == 'session' ? 'qa.session' : 'qa.resourceAccess',
      timeout: const Duration(seconds: 60),
    );
    final result = jsonDecode(response);
    stdout.writeln(jsonEncode(result));
  } finally {
    await driver.close();
  }
}
