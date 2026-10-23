import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_finance/config/environment/app_environment.dart';
import 'package:personal_finance/core/firebase/firebase_options.dart';
import 'package:personal_finance/features/coach/data/repositories/firestore_coach_repository.dart';
import 'package:personal_finance/features/coach/domain/entities/coach_models.dart';

const _wait = Duration(seconds: 20);
const _authPort = int.fromEnvironment('FIREBASE_AUTH_EMULATOR_PORT', defaultValue: 59199);
const _firestorePort = int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 59180);

Future<T> _next<T>(StreamIterator<T> events, bool Function(T) matches) async {
  return (() async {
    while (await events.moveNext()) {
      if (matches(events.current)) return events.current;
    }
    throw StateError('Coach stream ended before the expected persistence state');
  })().timeout(_wait);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseApp app;
  late FirebaseAuth auth;
  late FirebaseFirestore firestore;
  late FirestoreCoachRepository repository;
  late DocumentReference<Map<String, dynamic>> profile;

  setUpAll(() async {
    if (!const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      throw StateError('Coach persistence tests require USE_FIREBASE_EMULATORS=true');
    }
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '127.0.0.1');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      for (final port in [_authPort, _firestorePort]) {
        final response = await client
            .getUrl(Uri(scheme: 'http', host: host, port: port))
            .then((request) => request.close())
            .timeout(_wait);
        await response.drain<void>();
        expect(response.statusCode, HttpStatus.ok, reason: 'Emulator preflight on $port');
      }
    } finally {
      client.close(force: true);
    }
    // A separate synthetic app avoids the native default app and real data.
    app = await Firebase.initializeApp(
      name: 'coach-persistence-demo-clearbudget',
      options: AppFirebaseOptions.forEnvironment(AppEnvironment.dev, useEmulators: true),
    );
    expect(app.options.projectId, 'demo-clearbudget');
    auth = FirebaseAuth.instanceFor(app: app);
    firestore = FirebaseFirestore.instanceFor(app: app);
    await auth.useAuthEmulator(host, _authPort);
    firestore.useFirestoreEmulator(host, _firestorePort);
  });

  setUp(() async {
    await auth.signOut();
    final user = (await auth.signInAnonymously().timeout(_wait)).user!;
    profile = firestore.collection('users').doc(user.uid);
    await profile
        .set({
          'locale': 'es',
          'countryCode': 'CO',
          'timeZone': 'America/Bogota',
          'defaultCurrency': 'COP',
          'onboardingStatus': 'complete',
          'categoryCatalogVersion': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_wait);
    repository = FirestoreCoachRepository(firestore: firestore);
  });

  tearDown(() async {
    // Restore connectivity even when an offline assertion fails.
    await firestore.enableNetwork();
    await firestore.waitForPendingWrites().timeout(_wait);
    await repository.dispose();
    await auth.signOut();
  });

  tearDownAll(() async {
    await firestore.terminate();
    await app.delete();
  });

  testWidgets(
    'repository preferences persist online and queue offline without changing the profile',
    (
      tester,
    ) async {
      final preferences = StreamIterator(repository.watchPreferences(profile.id));
      addTearDown(preferences.cancel);
      final defaults = await _next(preferences, (_) => true);
      expect(defaults.toMap(), const CoachPreferences().toMap());

      const selected = CoachPreferences(
        dailyEnabled: true,
        weeklyEnabled: true,
        dailyHour: 23,
        dailyMinute: 59,
        dailyWeekdays: {7, 1, 3},
        weeklyWeekday: 7,
        weeklyHour: 0,
        weeklyMinute: 0,
      );
      final saved = await repository.savePreferences(profile.id, selected);
      saved.match((failure) => fail(failure.message), (state) {
        expect(state, CoachWriteState.confirmed);
      });
      final readBack = await _next(preferences, (value) => value.dailyEnabled);
      expect(readBack.toMap(), selected.toMap());
      final persisted = await profile.get(const GetOptions(source: Source.server));
      expect(persisted.data()!['coachPreferences'], selected.toMap());
      expect(persisted.data()!['locale'], 'es');
      expect(persisted.data()!['createdAt'], isA<Timestamp>());

      await firestore.disableNetwork();
      final offlinePreferences = selected.copyWith(dailyHour: 6, dailyMinute: 15);
      final queued = await repository.savePreferences(profile.id, offlinePreferences);
      queued.match((failure) => fail(failure.message), (state) {
        expect(state, CoachWriteState.pending);
      });
      final local = await _next(preferences, (value) => value.dailyHour == 6);
      expect(local.toMap(), offlinePreferences.toMap());
      expect(local.hasPendingWrites, isTrue);
      final cached = await profile.get(const GetOptions(source: Source.cache));
      expect(cached.metadata.isFromCache, isTrue);
      expect(cached.metadata.hasPendingWrites, isTrue);
      expect(cached.data()!['coachPreferences'], offlinePreferences.toMap());

      await firestore.enableNetwork();
      await firestore.waitForPendingWrites().timeout(_wait);
      final acknowledged = await _next(
        preferences,
        (value) => value.dailyHour == 6 && !value.hasPendingWrites,
      );
      expect(acknowledged.toMap(), offlinePreferences.toMap());
      final synced = await profile.get(const GetOptions(source: Source.server));
      expect(synced.metadata.hasPendingWrites, isFalse);
      expect(synced.data()!['coachPreferences'], offlinePreferences.toMap());
      expect(synced.data()!['locale'], persisted.data()!['locale']);
      expect(synced.data()!['createdAt'], persisted.data()!['createdAt']);
      // New subscription proves read-back does not depend on the original stream.
      expect(
        (await repository.watchPreferences(profile.id).first.timeout(_wait)).toMap(),
        offlinePreferences.toMap(),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'repository completions replay, filter periods and transition pending metadata on reconnect',
    (
      tester,
    ) async {
      final events = StreamIterator(
        repository.watchCompletions(profile.id, since: DateTime(2026, 10, 1)),
      );
      addTearDown(events.cancel);
      expect(await _next(events, (_) => true), isEmpty);

      Future<void> complete(String key, CoachReviewKind kind, {bool noMovements = false}) async {
        final result = await repository.complete(
          profile.id,
          periodKey: key,
          kind: kind,
          noMovements: noMovements,
        );
        result.match((failure) => fail(failure.message), (state) {
          expect(state, CoachWriteState.confirmed);
        });
      }

      await complete('2026-09-30', CoachReviewKind.daily);
      await complete('2026-10-19', CoachReviewKind.weekly);
      await complete('2026-10-22', CoachReviewKind.daily, noMovements: true);
      await complete('2026-10-22', CoachReviewKind.daily, noMovements: true);
      final online = await _next(
        events,
        (values) =>
            values.length == 2 &&
            values.every((value) => !value.pending && value.reviewedAt != null),
      );
      expect(online.map((value) => value.periodKey), ['2026-10-19', '2026-10-22']);
      expect(online.first.kind, CoachReviewKind.weekly);
      expect(online.first.noMovements, isFalse);
      expect(online.last.kind, CoachReviewKind.daily);
      expect(online.last.noMovements, isTrue);
      final daily = profile.collection('coachDailyCheckIns');
      expect((await daily.get(const GetOptions(source: Source.server))).docs, hasLength(2));
      final serverCompletion = await daily
          .doc('2026-10-22')
          .get(const GetOptions(source: Source.server));
      expect(
        serverCompletion.data()!.keys,
        unorderedEquals(['periodKey', 'kind', 'noMovements', 'reviewedAt']),
      );
      expect(serverCompletion.data()!['reviewedAt'], isA<Timestamp>());

      await firestore.disableNetwork();
      final queued = await repository.complete(
        profile.id,
        periodKey: '2026-10-23',
        kind: CoachReviewKind.daily,
        noMovements: true,
      );
      queued.match((failure) => fail(failure.message), (state) {
        expect(state, CoachWriteState.pending);
      });
      final offline = await _next(
        events,
        (values) => values.any((value) => value.periodKey == '2026-10-23' && value.pending),
      );
      final pending = offline.singleWhere((value) => value.periodKey == '2026-10-23');
      expect(pending.noMovements, isTrue);
      expect(pending.reviewedAt, isNull, reason: 'Server timestamp is unresolved offline');
      final cached = await daily.doc('2026-10-23').get(const GetOptions(source: Source.cache));
      expect(cached.metadata.isFromCache, isTrue);
      expect(cached.metadata.hasPendingWrites, isTrue);

      await firestore.enableNetwork();
      await firestore.waitForPendingWrites().timeout(_wait);
      final synced = await _next(
        events,
        (values) => values.any(
          (value) => value.periodKey == '2026-10-23' && !value.pending && value.reviewedAt != null,
        ),
      );
      expect(synced, hasLength(3));
      final acknowledged = await daily
          .doc('2026-10-23')
          .get(const GetOptions(source: Source.server));
      expect(acknowledged.metadata.hasPendingWrites, isFalse);
      expect(acknowledged.data()!['reviewedAt'], isA<Timestamp>());
      final readBack = await repository
          .watchCompletions(profile.id, since: DateTime(2026, 10, 1))
          .firstWhere((values) => values.length == 3 && values.every((value) => !value.pending))
          .timeout(_wait);
      expect(readBack.map((value) => value.periodKey), ['2026-10-19', '2026-10-22', '2026-10-23']);
      for (final name in [
        'operations',
        'accounts',
        'budgets',
        'ledgerEntries',
        'monthlySummaries',
      ]) {
        expect(
          (await profile.collection(name).get(const GetOptions(source: Source.server))).docs,
          isEmpty,
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
