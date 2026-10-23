import '../../domain/services/coach_notification_service.dart';
import 'coach_notification_backend.dart';

CoachNotificationBackend createCoachNotificationBackend() => UnsupportedCoachNotificationBackend();

class UnsupportedCoachNotificationBackend implements CoachNotificationBackend {
  @override
  bool get supported => false;
  @override
  Future<String?> initialize(void Function(String?) onOpen) async => null;
  @override
  Future<bool?> notificationsEnabled() async => null;
  @override
  Future<bool?> requestPermission() async => null;
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> cancelAll() async {}
  @override
  Future<void> schedule(
    CoachNotification notification, {
    required String title,
    required String body,
    required String payload,
  }) async {}
}
