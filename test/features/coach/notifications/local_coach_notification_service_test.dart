import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/coach/data/services/coach_notification_backend.dart';
import 'package:personal_finance/features/coach/data/services/coach_notification_backend_stub.dart';
import 'package:personal_finance/features/coach/data/services/local_coach_notification_service.dart';
import 'package:personal_finance/features/coach/domain/services/coach_notification_service.dart';

void main() {
  final now = DateTime.utc(2026, 10, 22, 12);
  late MemoryStore store;
  late FakeBackend backend;
  late LocalCoachNotificationService service;
  late List<CoachNotificationTarget> opened;

  LocalCoachNotificationService create({String namespace = 'dev:true'}) =>
      LocalCoachNotificationService(
        envNamespace: namespace,
        backend: backend,
        store: store,
        now: () => now,
      );

  CoachNotification reminder(String token, {int id = 1, int days = 1}) => CoachNotification(
    id: id,
    scheduledAt: now.add(Duration(days: days)),
    type: CoachNotificationType.daily,
    periodKey: '2026-10-23',
    ownerToken: token,
  );

  Future<void> replace(String uid, List<CoachNotification> notifications) =>
      service.replaceSchedule(uid, notifications, title: 'Localized title', body: 'Localized body');

  Future<String> enable(String uid) async {
    await service.saveDeviceSettings(uid, const CoachDeviceSettings(enabled: true));
    return service.ownerTokenFor(uid);
  }

  setUp(() async {
    store = MemoryStore();
    backend = FakeBackend();
    opened = [];
    service = create();
    await service.initialize(onOpen: opened.add);
  });

  test('initializes once, without requesting permission', () async {
    await service.initialize(onOpen: opened.add);
    expect(backend.initializations, 1);
    expect(backend.requests, 0);
  });

  test('device settings and random stable tokens are isolated by user and environment', () async {
    final paused = now.add(const Duration(days: 3));
    await service.saveDeviceSettings(
      'user-a',
      CoachDeviceSettings(enabled: true, pausedUntil: paused),
    );
    final settings = await service.readDeviceSettings('user-a');
    expect(settings.enabled, isTrue);
    expect(settings.pausedUntil, paused);
    expect((await service.readDeviceSettings('user-b')).enabled, isFalse);
    expect((await create(namespace: 'prod:false').readDeviceSettings('user-a')).enabled, isFalse);
    final token = await service.ownerTokenFor('user-a');
    expect(token, isNot(contains('user-a')));
    expect(base64Url.decode(token), hasLength(32));
    expect(await create().ownerTokenFor('user-a'), token);
    expect(await service.ownerTokenFor('user-b'), isNot(token));
    expect(await create(namespace: 'prod:false').ownerTokenFor('user-a'), isNot(token));
  });

  test('permission request marker distinguishes first use and denial, refreshes grants', () async {
    backend.enabled = false;
    expect(await service.permission(), CoachPermission.notDetermined);
    backend.requestResult = false;
    expect(await service.requestPermission(), CoachPermission.denied);
    expect(await create().permission(), CoachPermission.denied);
    backend.enabled = true;
    expect(await service.permission(), CoachPermission.granted);
    await service.openSettings();
    expect(backend.settingsOpened, 1);
  });

  test('unsupported platform never initializes or invokes native methods', () async {
    backend = FakeBackend()..supported = false;
    service = create();
    await service.initialize(onOpen: opened.add);
    expect(service.supported, isFalse);
    expect(await service.permission(), CoachPermission.unsupported);
    expect(await service.requestPermission(), CoachPermission.unsupported);
    await service.openSettings();
    await replace('a', []);
    await service.cancelAll();
    expect(backend.initializations, 0);
    expect(backend.cancellations, 0);
  });

  test('web stub provides unsupported status without platform channels', () async {
    final stubService = LocalCoachNotificationService(
      envNamespace: 'dev:true',
      store: store,
      backend: UnsupportedCoachNotificationBackend(),
    );
    await stubService.initialize(onOpen: opened.add);
    expect(stubService.supported, isFalse);
    expect(await stubService.permission(), CoachPermission.unsupported);
    await stubService.cancelAll();
  });

  test('only future one-off entries within 28 days are scheduled', () async {
    final token = await enable('a');
    await replace('a', [
      reminder(token, id: 1, days: -1),
      reminder(token, id: 2, days: 0),
      reminder(token, id: 3, days: 1),
      reminder(token, id: 4, days: 28),
      reminder(token, id: 5, days: 29),
    ]);
    expect(backend.scheduled.map((n) => n.id), [3, 4]);
    expect(backend.title, 'Localized title');
    expect(backend.body, 'Localized body');
    expect(backend.payloads.first, isNot(contains('"uid"')));
  });

  test('disabled, paused entries and denied replace by an empty native schedule', () async {
    final token = await service.ownerTokenFor('a');
    await replace('a', [reminder(token)]);
    expect(backend.scheduled, isEmpty);
    await service.saveDeviceSettings(
      'a',
      CoachDeviceSettings(enabled: true, pausedUntil: now.add(const Duration(days: 2))),
    );
    await replace('a', [reminder(token)]);
    expect(backend.scheduled, isEmpty);
    await enable('a');
    backend.enabled = false;
    await replace('a', [reminder(token)]);
    expect(backend.scheduled, isEmpty);
    expect(backend.cancellations, 3);
    backend.enabled = true;
    await service.saveDeviceSettings('a', CoachDeviceSettings(enabled: true, pausedUntil: now));
    await replace('a', [reminder(token)]);
    expect(backend.scheduled, hasLength(1));
  });

  test('seven-day pause schedules automatic resumption within the same horizon', () async {
    final token = await enable('a');
    await service.saveDeviceSettings(
      'a',
      CoachDeviceSettings(enabled: true, pausedUntil: now.add(const Duration(days: 7))),
    );
    await replace('a', [
      reminder(token, id: 1, days: 6),
      reminder(token, id: 2, days: 7),
      reminder(token, id: 3, days: 8),
      reminder(token, id: 4, days: 28),
      reminder(token, id: 5, days: 29),
    ]);
    expect(backend.scheduled.map((notification) => notification.id), [2, 3, 4]);
    expect(backend.cancellations, 1);
  });

  test('dispatch validates active owner, namespace, type and payload format', () async {
    final token = await enable('a');
    await replace('a', [reminder(token)]);
    final payload = backend.payloads.single;
    backend.onOpen!(payload);
    expect(opened.single.ownerToken, token);
    expect(opened.single.type, CoachNotificationType.daily);
    for (final bad in [
      null,
      '',
      '[]',
      '{',
      '{}',
      payload.replaceFirst(token, 'other'),
      payload.replaceFirst('dev:true', 'prod:false'),
      payload.replaceFirst('daily', 'unexpected'),
    ]) {
      backend.onOpen!(bad);
    }
    expect(opened, hasLength(1));
    await replace('b', []);
    backend.onOpen!(payload);
    expect(opened, hasLength(1));
  });

  test('logout invalidates taps immediately before cancellation finishes', () async {
    final token = await enable('a');
    await replace('a', [reminder(token)]);
    final payload = backend.payloads.single;
    final gate = Completer<void>();
    backend.cancelGate = gate.future;
    final cancelling = service.cancelAll();
    backend.onOpen!(payload);
    expect(opened, isEmpty);
    gate.complete();
    await cancelling;
    backend.onOpen!(payload);
    expect(opened, isEmpty);
  });

  test('cold start target is held until binding and consumed only once', () async {
    final token = await enable('a');
    await replace('a', [reminder(token)]);
    backend.initialPayload = backend.payloads.single;
    service = create();
    await service.initialize(onOpen: opened.add);
    expect(service.takeInitialTarget(), isNull);
    await replace('a', []);
    expect(service.takeInitialTarget()?.ownerToken, token);
    expect(service.takeInitialTarget(), isNull);
    expect(opened, isEmpty);
  });

  test('wrong owner and logout discard a cold start target', () async {
    final token = await enable('a');
    await replace('a', [reminder(token)]);
    backend.initialPayload = backend.payloads.single;
    service = create();
    await service.initialize(onOpen: opened.add);
    await replace('b', []);
    expect(service.takeInitialTarget(), isNull);
    await replace('a', []);
    expect(service.takeInitialTarget(), isNull);
    service = create();
    await service.cancelAll();
    await replace('a', []);
    expect(service.takeInitialTarget(), isNull);
  });

  test('rejects wrong tokens and duplicate IDs before scheduling', () async {
    final token = await enable('a');
    await expectLater(replace('a', [reminder('wrong')]), throwsArgumentError);
    await expectLater(replace('a', [reminder(token), reminder(token)]), throwsArgumentError);
    expect(backend.scheduled, isEmpty);
    await replace('a', [reminder(token)]);
    expect(backend.scheduled, hasLength(1));
  });

  test('new session supersedes a replacement blocked in native cancellation', () async {
    final token = await enable('a');
    final gate = Completer<void>();
    final entered = Completer<void>();
    backend
      ..cancelGate = gate.future
      ..cancelEntered = entered;
    final first = replace('a', [reminder(token)]);
    await entered.future;
    final second = replace('b', []);
    gate.complete();
    await Future.wait([first, second]);
    expect(backend.scheduled, isEmpty);
    expect(backend.cancellations, 2);
  });

  test('partial scheduling failure clears schedule and invalidates owner', () async {
    final token = await enable('a');
    backend.failSchedule = true;
    await expectLater(replace('a', [reminder(token)]), throwsStateError);
    expect(backend.cancellations, 2);
    backend.onOpen!(backend.payloads.single);
    expect(opened, isEmpty);
    backend.failSchedule = false;
    await replace('a', [reminder(token)]);
    expect(backend.scheduled, hasLength(1));
  });

  test('corrupt local preferences fail closed', () async {
    await enable('a');
    final key = store.values.keys.singleWhere((key) => key.endsWith('.settings'));
    store.values[key] = '{';
    expect((await service.readDeviceSettings('a')).enabled, isFalse);
  });
}

class MemoryStore implements CoachNotificationStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class FakeBackend implements CoachNotificationBackend {
  @override
  bool supported = true;
  bool enabled = true;
  bool requestResult = true;
  bool failSchedule = false;
  int initializations = 0;
  int requests = 0;
  int cancellations = 0;
  int settingsOpened = 0;
  String? initialPayload;
  String? title;
  String? body;
  Future<void>? cancelGate;
  Completer<void>? cancelEntered;
  void Function(String?)? onOpen;
  final List<CoachNotification> scheduled = [];
  final List<String> payloads = [];
  @override
  Future<String?> initialize(void Function(String?) onOpen) async {
    initializations++;
    this.onOpen = onOpen;
    return initialPayload;
  }

  @override
  Future<bool?> notificationsEnabled() async => enabled;
  @override
  Future<bool?> requestPermission() async {
    requests++;
    return requestResult;
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }

  @override
  Future<void> cancelAll() async {
    cancellations++;
    if (!(cancelEntered?.isCompleted ?? true)) cancelEntered!.complete();
    await cancelGate;
    scheduled.clear();
  }

  @override
  Future<void> schedule(
    CoachNotification notification, {
    required String title,
    required String body,
    required String payload,
  }) async {
    this.title = title;
    this.body = body;
    scheduled.add(notification);
    payloads.add(payload);
    if (failSchedule) throw StateError('native schedule failure');
  }
}
