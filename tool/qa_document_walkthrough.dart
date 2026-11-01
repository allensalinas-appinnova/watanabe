import 'dart:convert';
import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  final log = await File('/tmp/lumio-document-iphone-run.log').readAsString();
  final url = RegExp(
    r'A Dart VM Service[^\n]*available at: (http[^\s]+)',
  ).allMatches(log).last.group(1);
  final driver = await FlutterDriver.connect(dartVmServiceUrl: url, printCommunication: false);
  try {
    final session = jsonDecode(await driver.requestData('qa.session')) as Map<String, dynamic>;
    if (session['email'] != 'allensalinasjaramillo@gmail.com' ||
        session['project'] != 'lumiomoney') {
      throw StateError('QA identity required');
    }
    switch (args.first) {
      case 'stage':
        final bytes = await File('/tmp/lumio-qa-receipt-25000.png').readAsBytes();
        stdout.writeln(await driver.requestData('qa.stageReceipt:${base64Encode(bytes)}'));
      case 'tree':
        await File(
          '/tmp/lumio-qa-document-tree.txt',
        ).writeAsString((await driver.getRenderTree()).tree ?? '');
        stdout.writeln('Tree saved privately');
      case 'tap-key':
        await driver.tap(find.byValueKey(args[1]));
        stdout.writeln('Tapped requested control');
      case 'tap-text':
        await driver.tap(find.text(args[1]));
        stdout.writeln('Tapped requested label');
      case 'scroll':
        await driver.scroll(
          find.byType('Scrollable'),
          0,
          -400,
          const Duration(milliseconds: 400),
        );
      case 'capture':
        await File('/tmp/lumio-qa-document-phone.png').writeAsBytes(await driver.screenshot());
        stdout.writeln('Screenshot saved');
    }
  } finally {
    await driver.close();
  }
}
