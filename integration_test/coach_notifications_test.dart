import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_finance/features/coach/data/services/coach_notification_backend.dart';
import 'package:personal_finance/features/coach/data/services/coach_notification_backend_native.dart';
import 'package:personal_finance/features/coach/data/services/local_coach_notification_service.dart';
import 'package:personal_finance/features/coach/domain/services/coach_notification_service.dart';

/// Run on an Android or iOS test device with APP_ENV=dev and
/// USE_FIREBASE_EMULATORS=true. This runner never initializes Firebase.
/// Grant POST_NOTIFICATIONS with adb after the test APK is installed.
/// On iOS, approve the native permission prompt within 60 seconds.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native device receives a coach reminder, then logout invalidates its owner',
    (tester) async {
      expect(const String.fromEnvironment('APP_ENV'), 'dev');
      expect(const bool.fromEnvironment('USE_FIREBASE_EMULATORS'), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());

      final plugin = FlutterLocalNotificationsPlugin();
      final backend = _ObservedNativeBackend(NativeCoachNotificationBackend(plugin: plugin));
      final now = DateTime.now().toUtc();
      final service = LocalCoachNotificationService(
        envNamespace: 'dev:true:demo-clearbudget:coach-native-test',
        backend: backend,
        now: () => now,
      );
      final opened = <CoachNotificationTarget>[];
      await service.initialize(onOpen: opened.add);
      addTearDown(service.cancelAll);

      final platform = Platform.isIOS ? 'iOS' : 'Android';
      // Android permission may be granted by adb after APK installation. On iOS
      // the human approves the native OS prompt; no app or account UI is needed.
      final permissionDeadline = DateTime.now().add(const Duration(seconds: 60));
      if (Platform.isIOS) {
        debugPrint('COACH_NATIVE_PERMISSION_REQUEST platform=iOS approvalWindowSeconds=60');
        await service.requestPermission().timeout(const Duration(seconds: 60));
      }
      while (await service.permission() != CoachPermission.granted &&
          DateTime.now().isBefore(permissionDeadline)) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(
        await service.permission(),
        CoachPermission.granted,
        reason: Platform.isIOS
            ? 'Approve the iOS notification permission prompt within 60 seconds'
            : 'Grant android.permission.POST_NOTIFICATIONS to com.appinnova.lumiomoney via adb',
      );
      debugPrint('COACH_NATIVE_PERMISSION_GRANTED platform=$platform');

      const uid = 'demo-coach-notification-owner';
      await service.saveDeviceSettings(uid, const CoachDeviceSettings(enabled: true));
      final token = await service.ownerTokenFor(uid);
      final scheduledAt = DateTime.now().toUtc().add(const Duration(seconds: 30));
      const id = 20261022;
      await service.replaceSchedule(
        uid,
        [
          CoachNotification(
            id: id,
            scheduledAt: scheduledAt,
            type: CoachNotificationType.daily,
            periodKey: 'demo-native-delivery',
            ownerToken: token,
          ),
        ],
        title: 'Coach demo reminder',
        body: 'Native local notification delivery test',
      );
      final pending = await plugin.pendingNotificationRequests();
      expect(pending.map((notification) => notification.id), contains(id));
      expect(
        pending.singleWhere((notification) => notification.id == id).payload,
        isNot(contains(uid)),
      );
      debugPrint('COACH_NATIVE_PENDING platform=$platform id=$id scheduledAt=$scheduledAt');

      // Inexact alarms are allowed to be late. This bounded test verifies actual
      // delivery through the OS delivered-notification list on both platforms.
      final deadline = scheduledAt.add(const Duration(minutes: 3));
      var received = false;
      while (DateTime.now().toUtc().isBefore(deadline)) {
        final active = await plugin.getActiveNotifications();
        if (active.any((notification) => notification.id == id)) {
          received = true;
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      expect(
        received,
        isTrue,
        reason: '$platform did not deliver the notification within 3 minutes',
      );
      debugPrint(
        'COACH_NATIVE_RECEIVED platform=$platform id=$id observedAt=${DateTime.now().toUtc()}',
      );

      // Exercise owner dispatch with the exact payload sent to the OS. These
      // callbacks are injected; the delivery assertion above uses the real OS.
      final payload = backend.lastPayload!;
      backend.dispatch(payload);
      expect(opened.single.ownerToken, token);
      opened.clear();
      await service.cancelAll();
      expect(await plugin.pendingNotificationRequests(), isEmpty);
      expect((await plugin.getActiveNotifications()).where((n) => n.id == id), isEmpty);
      backend.dispatch(payload);
      expect(opened, isEmpty);
      await service.replaceSchedule('demo-other-owner', [], title: 'Coach demo', body: 'Demo');
      backend.dispatch(payload);
      expect(opened, isEmpty);
      debugPrint('COACH_NATIVE_LOGOUT_CLEARED platform=$platform staleOwnerIgnored=true');
    },
    skip: !Platform.isAndroid && !Platform.isIOS,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

class _ObservedNativeBackend implements CoachNotificationBackend {
  _ObservedNativeBackend(this.delegate);

  final CoachNotificationBackend delegate;
  void Function(String?)? _onOpen;
  String? lastPayload;

  void dispatch(String payload) => _onOpen?.call(payload);

  @override
  bool get supported => delegate.supported;
  @override
  Future<String?> initialize(void Function(String?) onOpen) {
    _onOpen = onOpen;
    return delegate.initialize(onOpen);
  }

  @override
  Future<bool?> notificationsEnabled() => delegate.notificationsEnabled();
  @override
  Future<bool?> requestPermission() => delegate.requestPermission();
  @override
  Future<void> openSettings() => delegate.openSettings();
  @override
  Future<void> cancelAll() => delegate.cancelAll();
  @override
  Future<void> schedule(
    CoachNotification notification, {
    required String title,
    required String body,
    required String payload,
  }) {
    lastPayload = payload;
    return delegate.schedule(notification, title: title, body: body, payload: payload);
  }
}
