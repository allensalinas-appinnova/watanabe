enum CoachPermission { granted, denied, notDetermined, unsupported }

enum CoachNotificationType { daily, weekly, debtBefore, debtDue }

class CoachDeviceSettings {
  const CoachDeviceSettings({this.enabled = false, this.pausedUntil});

  final bool enabled;
  final DateTime? pausedUntil;
}

class CoachNotificationTarget {
  const CoachNotificationTarget({
    required this.type,
    required this.periodKey,
    required this.ownerToken,
  });

  final CoachNotificationType type;
  final String periodKey;
  final String ownerToken;
}

class CoachNotification extends CoachNotificationTarget {
  const CoachNotification({
    required this.id,
    required this.scheduledAt,
    required super.type,
    required super.periodKey,
    required super.ownerToken,
  });

  final int id;
  final DateTime scheduledAt;
}

/// Device-local adapter. The caller plans completed periods, collisions and
/// timezone boundaries; each supplied instant is scheduled once, within 28 days.
/// Methods can throw platform/storage errors, which the lifecycle caller handles.
abstract interface class CoachNotificationService {
  bool get supported;

  Future<void> initialize({
    required void Function(CoachNotificationTarget target) onOpen,
  });
  Future<CoachPermission> permission();
  Future<CoachPermission> requestPermission();
  Future<void> openSettings();
  Future<CoachDeviceSettings> readDeviceSettings(String uid);
  Future<void> saveDeviceSettings(String uid, CoachDeviceSettings settings);

  /// Stable, random local token scoped to this environment and user.
  Future<String> ownerTokenFor(String uid);

  /// Binds the active owner even for an empty schedule. Call on every session
  /// change, and call cancelAll on logout to invalidate pending tap targets.
  Future<void> replaceSchedule(
    String uid,
    List<CoachNotification> notifications, {
    required String title,
    required String body,
  });
  Future<void> cancelAll();
  Future<void> clearUserData(String uid);

  /// Returns a cold-start target once, only after replaceSchedule binds its owner.
  CoachNotificationTarget? takeInitialTarget();
}
