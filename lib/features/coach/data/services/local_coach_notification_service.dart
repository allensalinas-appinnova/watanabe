import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/environment/app_environment.dart';
import '../../domain/services/coach_notification_service.dart';
import 'coach_notification_backend.dart';
import 'coach_notification_backend_stub.dart'
    if (dart.library.io) 'coach_notification_backend_native.dart'
    as platform;

/// Owns device preferences and validates every native tap before dispatch.
class LocalCoachNotificationService implements CoachNotificationService {
  LocalCoachNotificationService({
    String? envNamespace,
    CoachNotificationBackend? backend,
    CoachNotificationStore? store,
    DateTime Function()? now,
  }) : _namespace =
           envNamespace ??
           '${AppEnvironment.fromDartDefine().name}:'
               '${const bool.fromEnvironment('USE_FIREBASE_EMULATORS')}',
       _backend = backend ?? platform.createCoachNotificationBackend(),
       _store = store ?? SharedPreferencesCoachNotificationStore(),
       _now = now ?? DateTime.now;

  final String _namespace;
  final CoachNotificationBackend _backend;
  final CoachNotificationStore _store;
  final DateTime Function() _now;
  final Map<String, Future<String>> _tokens = {};
  Future<void> _queue = Future<void>.value();
  Future<void>? _initialization;
  void Function(CoachNotificationTarget)? _onOpen;
  String? _owner;
  CoachNotificationTarget? _initialTarget;
  int _generation = 0;

  @override
  bool get supported => _backend.supported;

  String _key(String uid, String item) =>
      'coach.notifications.v1.${Uri.encodeComponent(_namespace)}.'
      '${Uri.encodeComponent(uid)}.$item';

  @override
  Future<void> initialize({
    required void Function(CoachNotificationTarget target) onOpen,
  }) {
    _onOpen = onOpen;
    return _ensureInitialized();
  }

  Future<void> _ensureInitialized() =>
      _initialization ??= _initializeBackend().catchError((Object error, StackTrace stack) {
        _initialization = null;
        Error.throwWithStackTrace(error, stack);
      });

  Future<void> _initializeBackend() async {
    if (!supported) return;
    final payload = await _backend.initialize(_dispatch);
    _initialTarget = _decode(payload);
  }

  CoachNotificationTarget? _decode(String? payload) {
    if (payload == null) return null;
    try {
      final value = jsonDecode(payload);
      if (value is! Map<String, dynamic> || value['v'] != 1 || value['env'] != _namespace) {
        return null;
      }
      final token = value['owner'];
      final period = value['period'];
      final type = value['type'];
      if (token is! String || token.isEmpty || period is! String || period.isEmpty) {
        return null;
      }
      final parsedType = switch (type) {
        'daily' => CoachNotificationType.daily,
        'weekly' => CoachNotificationType.weekly,
        _ => null,
      };
      if (parsedType == null) return null;
      return CoachNotificationTarget(type: parsedType, periodKey: period, ownerToken: token);
    } on FormatException {
      return null;
    }
  }

  void _dispatch(String? payload) {
    final target = _decode(payload);
    if (target != null && _owner != null && target.ownerToken == _owner) {
      _onOpen?.call(target);
    }
  }

  @override
  CoachNotificationTarget? takeInitialTarget() {
    final target = _initialTarget;
    if (_owner == null) return null;
    _initialTarget = null;
    return target?.ownerToken == _owner ? target : null;
  }

  @override
  Future<CoachPermission> permission() async {
    if (!supported) return CoachPermission.unsupported;
    await _ensureInitialized();
    final enabled = await _backend.notificationsEnabled();
    if (enabled == true) return CoachPermission.granted;
    // The plugin exposes enabled state, not the OS authorization enum.
    final requested = await _store.read(_key('', 'permissionRequested'));
    return requested == 'true' ? CoachPermission.denied : CoachPermission.notDetermined;
  }

  @override
  Future<CoachPermission> requestPermission() async {
    if (!supported) return CoachPermission.unsupported;
    await _ensureInitialized();
    await _store.write(_key('', 'permissionRequested'), 'true');
    final granted = await _backend.requestPermission();
    return granted == true ? CoachPermission.granted : CoachPermission.denied;
  }

  @override
  Future<void> openSettings() async {
    if (!supported) return;
    await _ensureInitialized();
    await _backend.openSettings();
  }

  @override
  Future<CoachDeviceSettings> readDeviceSettings(String uid) async {
    final raw = await _store.read(_key(uid, 'settings'));
    if (raw == null) return const CoachDeviceSettings();
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic>) return const CoachDeviceSettings();
      final paused = value['pausedUntil'];
      return CoachDeviceSettings(
        enabled: value['enabled'] == true,
        pausedUntil: paused is String ? DateTime.tryParse(paused)?.toUtc() : null,
      );
    } on FormatException {
      return const CoachDeviceSettings();
    }
  }

  @override
  Future<void> saveDeviceSettings(String uid, CoachDeviceSettings settings) => _store.write(
    _key(uid, 'settings'),
    jsonEncode({
      'enabled': settings.enabled,
      'pausedUntil': settings.pausedUntil?.toUtc().toIso8601String(),
    }),
  );

  @override
  Future<String> ownerTokenFor(String uid) => _tokens.putIfAbsent(uid, () async {
    final key = _key(uid, 'owner');
    final existing = await _store.read(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final token = base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
    await _store.write(key, token);
    return token;
  });

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<void> replaceSchedule(
    String uid,
    List<CoachNotification> notifications, {
    required String title,
    required String body,
  }) {
    final generation = ++_generation;
    _owner = null;
    final snapshot = List<CoachNotification>.of(notifications);
    return _serialize(() async {
      if (!supported || generation != _generation) return;
      await _ensureInitialized();
      await _backend.cancelAll();
      final token = await ownerTokenFor(uid);
      if (generation != _generation) return;
      final now = _now().toUtc();
      final horizon = now.add(const Duration(days: 28));
      final ids = <int>{};
      for (final notification in snapshot) {
        if (notification.ownerToken != token ||
            notification.periodKey.isEmpty ||
            notification.id < 0 ||
            notification.id > 0x7fffffff ||
            !ids.add(notification.id)) {
          throw ArgumentError('Invalid notification owner, period or unique Android ID');
        }
      }
      if (_initialTarget?.ownerToken != token) _initialTarget = null;
      _owner = token;
      final settings = await readDeviceSettings(uid);
      if (!settings.enabled || await permission() != CoachPermission.granted) {
        return;
      }
      try {
        for (final notification in snapshot) {
          if (generation != _generation) return;
          final at = notification.scheduledAt.toUtc();
          if (!at.isAfter(now) || at.isAfter(horizon)) continue;
          final pausedUntil = settings.pausedUntil;
          if (pausedUntil != null && at.isBefore(pausedUntil)) continue;
          await _backend.schedule(
            notification,
            title: title,
            body: body,
            payload: jsonEncode({
              'v': 1,
              'env': _namespace,
              'owner': token,
              'type': notification.type.name,
              'period': notification.periodKey,
            }),
          );
        }
      } catch (_) {
        _owner = null;
        await _backend.cancelAll();
        rethrow;
      }
    });
  }

  @override
  Future<void> cancelAll() {
    ++_generation;
    _owner = null;
    _initialTarget = null;
    return _serialize(() async {
      if (!supported) return;
      await _ensureInitialized();
      _initialTarget = null;
      await _backend.cancelAll();
    });
  }

  @override
  Future<void> clearUserData(String uid) async {
    await cancelAll();
    await _tokens.remove(uid);
    await _store.remove(_key(uid, 'settings'));
    await _store.remove(_key(uid, 'owner'));
  }
}

class SharedPreferencesCoachNotificationStore implements CoachNotificationStore {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) => _preferences.setString(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}
