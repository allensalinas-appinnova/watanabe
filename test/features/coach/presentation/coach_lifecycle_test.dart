import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/coach/domain/entities/coach_models.dart';
import 'package:personal_finance/features/coach/domain/services/coach_notification_service.dart';
import 'package:personal_finance/features/coach/presentation/providers/coach_providers.dart';
import 'package:personal_finance/features/coach/presentation/widgets/coach_lifecycle.dart';
import 'package:personal_finance/features/commitments/domain/commitment_repository.dart';
import 'package:personal_finance/features/commitments/domain/debt_commitment.dart';
import 'package:personal_finance/features/finance/domain/entities/user_profile.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

import 'coach_test_support.dart';

class _Replacement {
  const _Replacement(this.uid, this.notifications, this.title, this.body);
  final String uid;
  final List<CoachNotification> notifications;
  final String title;
  final String body;
}

/// Records the platform boundary without opening any native notification API.
class _Notifications implements CoachNotificationService {
  final events = <String>[];
  final replacements = <_Replacement>[];
  final deviceReads = <String>[];
  final ownerRequests = <String>[];
  int initializations = 0;
  int permissionReads = 0;
  int cancellations = 0;
  bool failInitialization = false;
  bool failReplacement = false;
  String? boundUid;
  String? blockedUid;
  Completer<String>? ownerGate;
  Completer<void>? replacementGate;
  CoachNotificationTarget? initialTarget;
  late void Function(CoachNotificationTarget) onOpen;

  @override
  bool get supported => true;

  @override
  Future<void> initialize({required void Function(CoachNotificationTarget) onOpen}) async {
    initializations++;
    this.onOpen = onOpen;
    if (failInitialization) throw StateError('initialize-failed');
  }

  @override
  Future<CoachPermission> permission() async {
    permissionReads++;
    return CoachPermission.granted;
  }

  @override
  Future<CoachDeviceSettings> readDeviceSettings(String uid) async {
    deviceReads.add(uid);
    return const CoachDeviceSettings(enabled: true);
  }

  @override
  Future<String> ownerTokenFor(String uid) async {
    ownerRequests.add(uid);
    if (uid == blockedUid && ownerGate != null) return ownerGate!.future;
    return 'owner-$uid';
  }

  @override
  Future<void> replaceSchedule(
    String uid,
    List<CoachNotification> notifications, {
    required String title,
    required String body,
  }) async {
    replacements.add(_Replacement(uid, List.of(notifications), title, body));
    events.add('replace:$uid');
    if (replacementGate != null) await replacementGate!.future;
    if (failReplacement) throw StateError('replace-failed');
    boundUid = uid;
    events.add('bound:$uid');
  }

  @override
  Future<void> cancelAll() async {
    cancellations++;
    boundUid = null;
    initialTarget = null;
    events.add('cancel');
  }

  @override
  Future<void> clearUserData(String uid) async => cancelAll();

  @override
  CoachNotificationTarget? takeInitialTarget() {
    events.add('take-target');
    final target = initialTarget;
    initialTarget = null;
    return target;
  }

  @override
  Future<CoachPermission> requestPermission() async => CoachPermission.granted;
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> saveDeviceSettings(String uid, CoachDeviceSettings settings) async {}
}

class _Harness {
  final service = _Notifications();
  final clock = TestCoachClock();
  final sessions = StreamController<AuthUser?>.broadcast();
  final preferenceUpdates = StreamController<CoachPreferences>.broadcast();
  final completionUpdates = StreamController<List<CoachCompletion>>.broadcast();
  final profileUpdates = StreamController<UserProfile?>.broadcast();
  final locale = ValueNotifier(const Locale('en'));
  final opened = <String>[];
  AuthUser? session = const AuthUser(id: coachUid, isAnonymous: true);
  CoachPreferences preferences = const CoachPreferences(dailyEnabled: true, weeklyEnabled: true);
  List<CoachCompletion> completions = [];
  String zone = 'America/Bogota';
  late ProviderContainer container;

  UserProfile profile(String uid) => UserProfile(
    id: uid,
    locale: locale.value.languageCode,
    countryCode: 'CO',
    timeZone: zone,
    defaultCurrency: 'COP',
    onboardingStatus: 'complete',
    categoryCatalogVersion: 1,
  );

  Future<void> mount(
    WidgetTester tester, {
    List<DebtCommitment> commitments = const [],
    List<DebtCommitmentPaymentLink> commitmentPayments = const [],
  }) async {
    final repository = repositoryFor();
    when(() => repository.watchPreferences(any())).thenAnswer((_) async* {
      yield preferences;
      yield* preferenceUpdates.stream;
    });
    when(() => repository.watchRoutinePreferences(any())).thenAnswer((_) async* {
      CoachRoutinePreferences inferred() =>
          CoachRoutinePreferences.fromProfile(null, legacy: preferences);
      yield inferred();
      await for (final _ in preferenceUpdates.stream) {
        yield inferred();
      }
    });
    when(() => repository.watchCompletions(any(), since: any(named: 'since'))).thenAnswer((
      _,
    ) async* {
      yield completions;
      yield* completionUpdates.stream;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith((ref) async* {
            yield session;
            yield* sessions.stream;
          }),
          coachRepositoryProvider.overrideWithValue(repository),
          coachNotificationServiceProvider.overrideWithValue(service),
          coachClockProvider.overrideWithValue(clock),
          coachTickProvider.overrideWith((ref) => Stream.value(clock.now())),
          canonicalUserProfileProvider.overrideWith((ref, uid) async* {
            yield profile(uid);
            yield* profileUpdates.stream;
          }),
          debtCommitmentsProvider.overrideWith((ref, uid) => Stream.value(commitments)),
          debtCommitmentPaymentsProvider.overrideWith(
            (ref, uid) => Stream.value(commitmentPayments),
          ),
        ],
        child: ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, value, child) => MaterialApp(
            locale: value,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CoachLifecycle(
              onOpen: (location) {
                service.events.add('open:${service.boundUid}');
                opened.add(location);
              },
              child: const Scaffold(body: Text('Lifecycle host')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.byType(CoachLifecycle)));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await sessions.close();
      await preferenceUpdates.close();
      await completionUpdates.close();
      await profileUpdates.close();
      locale.dispose();
    });
  }

  Future<void> signInAs(WidgetTester tester, String? uid) async {
    session = uid == null ? null : AuthUser(id: uid, isAnonymous: true);
    sessions.add(session);
    await tester.pumpAndSettle();
  }

  Future<void> setCompletions(WidgetTester tester, List<CoachCompletion> value) async {
    completions = value;
    completionUpdates.add(value);
    await tester.pumpAndSettle();
  }

  Future<void> resume(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(registerCoachFallbacks);

  testWidgets('startup binds owner and schedules the 28-day horizon once', (tester) async {
    final h = _Harness();
    await h.mount(tester);
    expect(h.service.initializations, 1);
    expect(h.service.replacements, hasLength(1));
    final replacement = h.service.replacements.single;
    expect(replacement.uid, coachUid);
    expect(replacement.notifications, hasLength(32));
    expect(replacement.notifications.map((n) => n.id).toSet(), hasLength(32));
    expect(replacement.notifications.first.periodKey, '2026-10-22');
    expect(replacement.notifications.last.periodKey, '2026-11-18');
    expect(replacement.notifications.every((n) => n.ownerToken == 'owner-$coachUid'), isTrue);
    expect(replacement.notifications.every((n) => n.scheduledAt.isAfter(h.clock.now())), isTrue);
    expect(replacement.title, isNotEmpty);
    expect(replacement.body, isNotEmpty);
    expect(h.service.boundUid, coachUid);
    await tester.pump(const Duration(minutes: 2));
    expect(h.service.replacements, hasLength(1));
    expect(h.container.read(coachSchedulingIssueProvider), isFalse);
  });

  testWidgets('debt reminders join the shared schedule and skip fully paid installments', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(
      tester,
      commitments: const [
        DebtCommitment(
          id: 'vehicle-loan',
          debtAccountId: 'loan',
          currency: 'COP',
          amountMinor: 2400000,
          firstDueMonth: '2026-10',
          dueDay: 24,
          remindersEnabled: true,
        ),
        DebtCommitment(
          id: 'paid-loan',
          debtAccountId: 'loan-2',
          currency: 'COP',
          amountMinor: 100000,
          firstDueMonth: '2026-10',
          dueDay: 25,
          remindersEnabled: true,
        ),
      ],
      commitmentPayments: const [
        DebtCommitmentPaymentLink(
          paymentId: 'paid-installment',
          commitmentId: 'paid-loan',
          monthKey: '2026-10',
          amountMinor: 100000,
        ),
      ],
    );

    final notifications = h.service.replacements.single.notifications;
    final debtNotifications = notifications
        .where(
          (item) =>
              item.type == CoachNotificationType.debtBefore ||
              item.type == CoachNotificationType.debtDue,
        )
        .toList();
    expect(debtNotifications, hasLength(2));
    expect(
      debtNotifications.map((item) => item.type),
      containsAll([
        CoachNotificationType.debtBefore,
        CoachNotificationType.debtDue,
      ]),
    );
    expect(debtNotifications.every((item) => item.periodKey == '2026-10'), isTrue);
    expect(debtNotifications.every((item) => item.id >= 19000), isTrue);
    expect(
      notifications.where(
        (item) => item.periodKey == '2026-10' && item.type.name.startsWith('debt'),
      ),
      hasLength(2),
    );
  });

  testWidgets('pending daily and confirmed weekly completions suppress their reminders', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await h.setCompletions(tester, const [
      CoachCompletion(kind: CoachReviewKind.daily, periodKey: '2026-10-22', pending: true),
      CoachCompletion(kind: CoachReviewKind.weekly, periodKey: '2026-10-19'),
    ]);
    expect(h.service.replacements, hasLength(2));
    final notifications = h.service.replacements.last.notifications;
    expect(notifications, hasLength(30));
    expect(
      notifications.where(
        (n) => n.type == CoachNotificationType.daily && n.periodKey == '2026-10-22',
      ),
      isEmpty,
    );
    expect(
      notifications.where(
        (n) => n.type == CoachNotificationType.weekly && n.periodKey == '2026-10-19',
      ),
      isEmpty,
    );
    expect(
      notifications.any(
        (n) => n.type == CoachNotificationType.daily && n.periodKey == '2026-10-23',
      ),
      isTrue,
    );
  });

  testWidgets('logout cancels active owner and ignores notification callbacks', (tester) async {
    final h = _Harness();
    await h.mount(tester);
    await h.signInAs(tester, null);
    expect(h.service.cancellations, 1);
    expect(h.service.boundUid, isNull);
    h.service.onOpen(
      const CoachNotificationTarget(
        type: CoachNotificationType.daily,
        periodKey: '2026-10-22',
        ownerToken: 'owner-$coachUid',
      ),
    );
    await tester.pumpAndSettle();
    expect(h.opened, isEmpty);
    expect(h.service.replacements, hasLength(1));
  });

  testWidgets('uid change cancels previous owner before binding new schedule', (tester) async {
    final h = _Harness();
    await h.mount(tester);
    h.service.events.clear();
    await h.signInAs(tester, 'second-user');
    expect(h.service.cancellations, 1);
    expect(h.service.boundUid, 'second-user');
    expect(
      h.service.events.indexOf('cancel'),
      lessThan(h.service.events.indexOf('bound:second-user')),
    );
    expect(h.service.replacements.last.uid, 'second-user');
    expect(
      h.service.replacements.last.notifications.every((n) => n.ownerToken == 'owner-second-user'),
      isTrue,
    );
  });

  testWidgets('stale owner lookup cannot schedule after uid changes', (tester) async {
    final h = _Harness();
    final gate = Completer<String>();
    h.service
      ..blockedUid = coachUid
      ..ownerGate = gate;
    await h.mount(tester);
    expect(h.service.ownerRequests, [coachUid]);
    expect(h.service.replacements, isEmpty);
    await h.signInAs(tester, 'second-user');
    gate.complete('owner-$coachUid');
    await tester.pumpAndSettle();
    expect(h.service.replacements.map((r) => r.uid), ['second-user']);
    expect(h.service.boundUid, 'second-user');
  });

  testWidgets('logout during owner lookup prevents a stale replacement', (tester) async {
    final h = _Harness();
    final gate = Completer<String>();
    h.service
      ..blockedUid = coachUid
      ..ownerGate = gate;
    await h.mount(tester);
    await h.signInAs(tester, null);
    gate.complete('owner-$coachUid');
    await tester.pumpAndSettle();
    expect(h.service.replacements, isEmpty);
    expect(h.service.boundUid, isNull);
    expect(h.service.cancellations, 1);
  });

  testWidgets('locale, timezone, preferences and resume renew the schedule', (tester) async {
    final h = _Harness();
    await h.mount(tester);
    final englishTitle = h.service.replacements.last.title;
    h.locale.value = const Locale('es');
    await tester.pumpAndSettle();
    expect(h.service.replacements, hasLength(2));
    expect(h.service.replacements.last.title, isNot(englishTitle));
    final bogotaTime = h.service.replacements.last.notifications.first.scheduledAt;
    h.zone = 'UTC';
    h.profileUpdates.add(h.profile(coachUid));
    await tester.pumpAndSettle();
    expect(h.service.replacements, hasLength(3));
    expect(
      h.service.replacements.last.notifications.first.scheduledAt,
      bogotaTime.subtract(const Duration(hours: 5)),
    );
    h.preferences = const CoachPreferences(dailyEnabled: true, dailyHour: 21, dailyMinute: 15);
    h.preferenceUpdates.add(h.preferences);
    await tester.pumpAndSettle();
    expect(h.service.replacements, hasLength(4));
    expect(h.service.replacements.last.notifications, hasLength(28));
    expect(
      h.service.replacements.last.notifications.first.scheduledAt,
      DateTime.utc(2026, 10, 22, 21, 15),
    );
    h.clock.instant = DateTime.utc(2026, 10, 23, 18);
    final reads = h.service.permissionReads;
    await h.resume(tester);
    expect(h.service.replacements, hasLength(5));
    expect(h.service.replacements.last.notifications.first.periodKey, '2026-10-23');
    expect(h.service.replacements.last.notifications.last.periodKey, '2026-11-19');
    expect(h.service.permissionReads, greaterThan(reads));
    expect(h.service.deviceReads, hasLength(2));
  });

  testWidgets('scheduler failure stays idle until explicit retry or app resume', (tester) async {
    final h = _Harness();
    h.service.failReplacement = true;
    await h.mount(tester);
    expect(h.service.replacements, hasLength(1));
    expect(h.container.read(coachSchedulingIssueProvider), isTrue);
    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(h.service.replacements, hasLength(1));
    h.container.read(coachRescheduleProvider.notifier).retry();
    await tester.pumpAndSettle();
    expect(h.service.replacements, hasLength(2));
    expect(h.container.read(coachSchedulingIssueProvider), isTrue);
    h.service.failReplacement = false;
    await h.resume(tester);
    expect(h.service.replacements, hasLength(3));
    expect(h.container.read(coachSchedulingIssueProvider), isFalse);
    await tester.pumpAndSettle();
    expect(h.service.replacements, hasLength(3));
  });

  testWidgets('initialization failure retries explicitly without a rebuild loop', (tester) async {
    final h = _Harness();
    h.service.failInitialization = true;
    await h.mount(tester);
    expect(h.service.initializations, 1);
    expect(h.container.read(coachSchedulingIssueProvider), isTrue);
    await tester.pump(const Duration(minutes: 2));
    expect(h.service.initializations, 1);
    h.service.failInitialization = false;
    h.container.read(coachRescheduleProvider.notifier).retry();
    await tester.pumpAndSettle();
    expect(h.service.initializations, 2);
    expect(h.service.replacements, hasLength(1));
    expect(h.container.read(coachSchedulingIssueProvider), isFalse);
  });

  testWidgets('cold target dispatch waits for successful owner binding and is consumed once', (
    tester,
  ) async {
    final h = _Harness();
    final gate = Completer<void>();
    h.service
      ..replacementGate = gate
      ..initialTarget = const CoachNotificationTarget(
        type: CoachNotificationType.weekly,
        periodKey: '2026-10-12',
        ownerToken: 'owner-$coachUid',
      );
    await h.mount(tester);
    expect(h.opened, isEmpty);
    expect(h.service.events, ['replace:$coachUid']);
    gate.complete();
    await tester.pumpAndSettle();
    expect(h.opened, ['/coach/weekly?date=2026-10-12']);
    expect(h.service.events, [
      'replace:$coachUid',
      'bound:$coachUid',
      'take-target',
      'open:$coachUid',
    ]);
    await h.resume(tester);
    expect(h.opened, hasLength(1));
  });

  testWidgets('unmount during owner lookup prevents delayed scheduling', (tester) async {
    final h = _Harness();
    final gate = Completer<String>();
    h.service
      ..blockedUid = coachUid
      ..ownerGate = gate;
    await h.mount(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    gate.complete('owner-$coachUid');
    await tester.pumpAndSettle();
    expect(h.service.replacements, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion during replacement queues newest schedule and defers cold target', (
    tester,
  ) async {
    final h = _Harness();
    final gate = Completer<void>();
    h.service
      ..replacementGate = gate
      ..initialTarget = const CoachNotificationTarget(
        type: CoachNotificationType.daily,
        periodKey: '2026-10-22',
        ownerToken: 'owner-$coachUid',
      );
    await h.mount(tester);
    await h.setCompletions(tester, const [
      CoachCompletion(kind: CoachReviewKind.daily, periodKey: '2026-10-22', pending: true),
    ]);
    // The second replacement must wait until the older service call settles.
    expect(h.service.replacements, hasLength(1));
    expect(h.opened, isEmpty);
    gate.complete();
    await tester.pumpAndSettle();
    expect(h.service.replacements, hasLength(2));
    expect(h.service.replacements.last.notifications, hasLength(31));
    expect(
      h.service.replacements.last.notifications.where(
        (n) => n.type == CoachNotificationType.daily && n.periodKey == '2026-10-22',
      ),
      isEmpty,
    );
    expect(h.service.events, [
      'replace:$coachUid',
      'bound:$coachUid',
      'replace:$coachUid',
      'bound:$coachUid',
      'take-target',
      'open:$coachUid',
    ]);
    expect(h.opened, ['/coach/daily?date=2026-10-22']);
  });
}
