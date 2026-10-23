import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/coach/data/services/coach_notification_backend_native.dart';
import 'package:personal_finance/features/coach/domain/services/coach_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  bool? initializationResult = true;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
    calls.clear();
    initializationResult = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        calls.add(call);
        return switch (call.method) {
          'initialize' => initializationResult,
          'getNotificationAppLaunchDetails' => {'notificationLaunchedApp': false},
          _ => null,
        };
      },
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });

  test('22.3.2 native calls use UTC, inexact idle mode, and no recurrence', () async {
    final backend = NativeCoachNotificationBackend();
    expect(await backend.initialize((_) {}), isNull);
    final at = DateTime.now().toUtc().add(const Duration(days: 1));
    await backend.schedule(
      CoachNotification(
        id: 42,
        scheduledAt: at,
        type: CoachNotificationType.weekly,
        periodKey: '2026-W43',
        ownerToken: 'opaque',
      ),
      title: 'Localized title',
      body: 'Localized body',
      payload: 'opaque payload',
    );
    final initialization = calls.first;
    final initArgs = initialization.arguments as Map<Object?, Object?>;
    expect(initArgs['defaultIcon'], 'ic_coach_notification');
    final schedule = calls.singleWhere((call) => call.method == 'zonedSchedule');
    final arguments = schedule.arguments as Map<Object?, Object?>;
    final specifics = arguments['platformSpecifics']! as Map<Object?, Object?>;
    expect(specifics['scheduleMode'], AndroidScheduleMode.inexactAllowWhileIdle.name);
    expect(specifics['icon'], 'ic_coach_notification');
    expect(arguments['timeZoneName'], 'Etc/UTC');
    expect(arguments.containsKey('matchDateTimeComponents'), isFalse);
    expect(arguments['title'], 'Localized title');
    expect(arguments['body'], 'Localized body');
    expect(arguments['payload'], 'opaque payload');
    expect(calls.any((call) => call.method.contains('Exact')), isFalse);
  });

  test('iOS initialization never prompts and forwards launch payload', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    FlutterLocalNotificationsPlatform.instance = IOSFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        calls.add(call);
        return switch (call.method) {
          'initialize' => true,
          'getNotificationAppLaunchDetails' => {
            'notificationLaunchedApp': true,
            'notificationResponse': {'notificationResponseType': 0, 'payload': 'cold-start'},
          },
          _ => null,
        };
      },
    );
    expect(await NativeCoachNotificationBackend().initialize((_) {}), 'cold-start');
    final arguments = calls.first.arguments as Map<Object?, Object?>;
    expect(arguments['requestAlertPermission'], isFalse);
    expect(arguments['requestSoundPermission'], isFalse);
    expect(arguments['requestBadgePermission'], isFalse);
  });

  test('iOS false initialization is valid when permission requests are disabled', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    FlutterLocalNotificationsPlatform.instance = IOSFlutterLocalNotificationsPlugin();
    initializationResult = false;

    expect(await NativeCoachNotificationBackend().initialize((_) {}), isNull);
    expect(calls.map((call) => call.method), ['initialize', 'getNotificationAppLaunchDetails']);
    final arguments = calls.first.arguments as Map<Object?, Object?>;
    expect(arguments['requestAlertPermission'], isFalse);
    expect(arguments['requestSoundPermission'], isFalse);
    expect(arguments['requestBadgePermission'], isFalse);
  });

  test('iOS null initialization remains an error', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    FlutterLocalNotificationsPlatform.instance = IOSFlutterLocalNotificationsPlugin();
    initializationResult = null;

    await expectLater(NativeCoachNotificationBackend().initialize((_) {}), throwsStateError);
    expect(calls.map((call) => call.method), ['initialize']);
  });
}
