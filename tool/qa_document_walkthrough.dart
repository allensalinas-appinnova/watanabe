import 'dart:convert';
import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  final log = await File(
    Platform.environment['QA_FLUTTER_LOG'] ?? '/tmp/lumio-document-iphone-run.log',
  ).readAsString();
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
    await driver.runUnsynchronized(() async {
      switch (args.first) {
        case 'back':
          final vmDriver = driver as VMServiceFlutterDriver;
          final isolates = (await vmDriver.serviceClient.getVM()).isolates!;
          final isolate = await vmDriver.serviceClient.getIsolate(isolates.first.id!);
          await vmDriver.serviceClient.evaluate(
            isolate.id!,
            isolate.rootLib!.id!,
            'appRouter.pop()',
          );
        case 'navigate-read':
          if (!RegExp(r'^/attachments/[a-zA-Z0-9_-]+$').hasMatch(args[1]) &&
              args[1] != '/settings/usage') {
            throw StateError('Read-only QA destination required');
          }
          final vmDriver = driver as VMServiceFlutterDriver;
          final isolates = (await vmDriver.serviceClient.getVM()).isolates!;
          final isolate = await vmDriver.serviceClient.getIsolate(isolates.first.id!);
          await vmDriver.serviceClient.evaluate(
            isolate.id!,
            isolate.rootLib!.id!,
            'appRouter.push<void>(${jsonEncode(args[1])})',
          );
          stdout.writeln('Opened read-only QA destination');
        case 'stage-file':
          final bytes = await File(args[1]).readAsBytes();
          final mime = args[1].toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
          stdout.writeln(
            await driver.requestData(
              'qa.stageDocument:${jsonEncode({'contentType': mime, 'data': base64Encode(bytes)})}',
            ),
          );
        case 'stage':
          final bytes = await File('/tmp/lumio-qa-receipt-25000.png').readAsBytes();
          stdout.writeln(await driver.requestData('qa.stageReceipt:${base64Encode(bytes)}'));
        case 'tree':
          await File(
            '/tmp/lumio-qa-document-tree.txt',
          ).writeAsString((await driver.getRenderTree()).tree ?? '');
          stdout.writeln('Tree saved privately');
        case 'tap-dialog-text':
          await driver.tap(
            find.descendant(
              of: find.byType('AlertDialog'),
              matching: find.descendant(
                of: find.byType('TextButton'),
                matching: find.text(args[1]),
              ),
            ),
          );
        case 'tap-dialog-primary':
          await driver.tap(
            find.descendant(of: find.byType('AlertDialog'), matching: find.byType('FilledButton')),
          );
        case 'show-key':
          await driver.scrollIntoView(find.byValueKey(args[1]));
        case 'wait-absent-key':
          await driver.waitForAbsent(find.byValueKey(args[1]));
        case 'set-text':
          await driver.setTextEntryEmulation(enabled: true);
          await driver.tap(find.byValueKey(args[1]));
          await driver.enterText(args[2]);

          await driver.setTextEntryEmulation(enabled: false);
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
    });
  } finally {
    await driver.close();
  }
}
