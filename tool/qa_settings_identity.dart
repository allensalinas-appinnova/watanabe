import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Physical QA: read identity, open/cancel sign-out. Never confirms or mutates data.
Future<void> main(List<String> args) async {
  if (args.length < 2 || !['android', 'iphone'].contains(args[1])) {
    throw ArgumentError(
      'Usage: dart run tool/qa_settings_identity.dart <flutter-log> <android|iphone> [locale]',
    );
  }
  final locale = args.length > 2 ? args[2] : 'es';
  await initializeDateFormatting(locale);
  final log = await File(args[0]).readAsString();
  final url = RegExp(
    r'A Dart VM Service[^\n]*available at: (http[^\s]+)',
  ).allMatches(log).last.group(1);
  final driver = await FlutterDriver.connect(dartVmServiceUrl: url, printCommunication: false);
  try {
    final session = jsonDecode(await driver.requestData('qa.session')) as Map<String, dynamic>;
    if (session['project'] != 'lumiomoney' ||
        session['email'] != 'allensalinasjaramillo@gmail.com' ||
        session['anonymous'] != false ||
        session['createdAtLocal'] == null) {
      throw StateError('Registered QA identity and creation metadata required');
    }
    final created = DateTime.parse(session['createdAtLocal'] as String);
    final dateText = DateFormat.yMMMMd(locale).format(created);
    final output = Directory('artifacts/account-identity/${args[1]}');
    await output.create(recursive: true);
    await driver.runUnsynchronized(() async {
      try {
        await driver.waitFor(
          find.text({'es': 'Configuración', 'en': 'Settings', 'pt': 'Configurações'}[locale]!),
          timeout: const Duration(seconds: 1),
        );
      } on Object {
        await driver.tap(
          find.byValueKey('global_settings_action'),
          timeout: const Duration(seconds: 30),
        );
      }
      await driver.scrollUntilVisible(
        find.byType('ListView'),
        find.byValueKey('settings_account_since'),
        dyScroll: 250,
        timeout: const Duration(seconds: 30),
      );
      final tree = (await driver.getRenderTree()).tree ?? '';
      final since = await driver.getText(find.byValueKey('settings_account_since'));
      if (!tree.contains(session['email'] as String) || !since.contains(dateText)) {
        throw StateError('Account email/date mismatch');
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await File('${output.path}/settings.png').writeAsBytes(await driver.screenshot());
      await driver.scrollUntilVisible(
        find.byType('ListView'),
        find.byValueKey('more_sign_out'),
        dyScroll: -200,
        timeout: const Duration(seconds: 30),
      );
      await driver.tap(find.byValueKey('more_sign_out'));
      await driver.waitFor(find.byType('AlertDialog'));
      try {
        final message = await driver.getText(
          find.descendant(
            of: find.byType('AlertDialog'),
            matching: find.descendant(of: find.byType('Consumer'), matching: find.byType('Text')),
          ),
          timeout: const Duration(seconds: 15),
        );
        if (!message.contains(session['email'] as String)) {
          throw StateError('Dialog account identity missing');
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await File('${output.path}/sign-out.png').writeAsBytes(await driver.screenshot());
      } finally {
        await driver.tap(find.byValueKey('settings_sign_out_cancel'));
        await driver.waitForAbsent(find.byType('AlertDialog'));
      }
      final after = jsonDecode(await driver.requestData('qa.session')) as Map<String, dynamic>;
      if (after['email'] != session['email'] || after['createdAt'] != session['createdAt']) {
        throw StateError('QA session must remain unchanged');
      }
      await driver.tap(
        find.descendant(of: find.byType('FinanceRouteHeader'), matching: find.byType('IconButton')),
      );
      await File('${output.path}/result.json').writeAsString(
        jsonEncode({
          'project': 'lumiomoney',
          'physicalPlatform': args[1],
          'qaConfirmed': true,
          'emailVisible': true,
          'authDateMatches': true,
          'dialogOpened': true,
          'dialogCancelled': true,
          'sessionPreserved': true,
          'financialCommandsExecuted': false,
        }),
      );
      stdout.writeln('Physical Settings identity and cancelled sign-out verified.');
    });
  } finally {
    await driver.close();
  }
}
