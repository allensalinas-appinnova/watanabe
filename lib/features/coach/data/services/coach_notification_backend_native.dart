import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/services/coach_notification_service.dart';
import 'coach_notification_backend.dart';
import 'coach_notification_backend_stub.dart';

CoachNotificationBackend createCoachNotificationBackend() => Platform.isAndroid || Platform.isIOS
    ? NativeCoachNotificationBackend()
    : UnsupportedCoachNotificationBackend();

class NativeCoachNotificationBackend implements CoachNotificationBackend {
  NativeCoachNotificationBackend({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  bool get supported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<String?> initialize(void Function(String?) onOpen) async {
    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_coach_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onOpen(response.payload),
    );
    // iOS returns false when all initialization permission requests are disabled.
    // Authorization is requested separately; a null result still is not success.
    if (initialized == null || (!initialized && _ios == null)) {
      throw StateError('Notification initialization failed');
    }
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true ? launch?.notificationResponse?.payload : null;
  }

  @override
  Future<bool?> notificationsEnabled() async {
    if (Platform.isAndroid) return _android?.areNotificationsEnabled();
    final options = await _ios?.checkPermissions();
    return options == null ? null : options.isEnabled || options.isProvisionalEnabled;
  }

  @override
  Future<bool?> requestPermission() async => Platform.isAndroid
      ? _android?.requestNotificationsPermission()
      : _ios?.requestPermissions(alert: true, badge: false, sound: true);

  @override
  Future<void> openSettings() async {
    final opened = Platform.isAndroid
        ? await _android?.openAppNotificationSettings()
        : await _ios?.openAppNotificationSettings();
    if (opened != true) throw StateError('Notification settings could not be opened');
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> schedule(
    CoachNotification notification, {
    required String title,
    required String body,
    required String payload,
  }) => _plugin.zonedSchedule(
    id: notification.id,
    title: title,
    body: body,
    scheduledDate: tz.TZDateTime.from(notification.scheduledAt.toUtc(), tz.UTC),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'coach_reminders_v1',
        title,
        icon: 'ic_coach_notification',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(presentBadge: false),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    payload: payload,
  );
}
