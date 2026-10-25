import '../../domain/services/coach_notification_service.dart';

/// Native boundary, injectable without invoking any platform channels in tests.
abstract interface class CoachNotificationBackend {
  bool get supported;
  Future<String?> initialize(void Function(String? payload) onOpen);
  Future<bool?> notificationsEnabled();
  Future<bool?> requestPermission();
  Future<void> openSettings();
  Future<void> cancelAll();
  Future<void> schedule(
    CoachNotification notification, {
    required String title,
    required String body,
    required String payload,
  });
}

abstract interface class CoachNotificationStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}
