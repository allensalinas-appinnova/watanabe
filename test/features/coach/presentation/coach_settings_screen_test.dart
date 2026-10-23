import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/coach/domain/entities/coach_models.dart';
import 'package:personal_finance/features/coach/presentation/screens/coach_settings_screen.dart';

import 'coach_test_support.dart';

void main() {
  setUpAll(registerCoachFallbacks);

  for (final oldFails in [false, true]) {
    testWidgets('old preference ${oldFails ? 'failure' : 'success'} cannot finish new user save', (
      tester,
    ) async {
      final repo = repositoryFor();
      final sessions = StreamController<AuthUser?>.broadcast();
      addTearDown(sessions.close);
      final oldResult = Completer<Either<Failure, CoachWriteState>>();
      final newResult = Completer<Either<Failure, CoachWriteState>>();
      when(() => repo.savePreferences(coachUid, any())).thenAnswer((_) => oldResult.future);
      when(() => repo.savePreferences('second-user', any())).thenAnswer((_) => newResult.future);
      await pumpCoach(
        tester,
        const CoachSettingsScreen(),
        repo,
        sessionStream: (() async* {
          yield const AuthUser(id: coachUid, isAnonymous: true);
          yield* sessions.stream;
        })(),
      );
      final daily = find.byKey(const ValueKey('coach_daily_enabled'));
      await tester.ensureVisible(daily);
      await tester.tap(daily);
      await tester.pump();
      sessions.add(const AuthUser(id: 'second-user', isAnonymous: true));
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump();
      }
      expect(tester.widget<SwitchListTile>(daily).onChanged, isNotNull);
      expect(tester.widget<SwitchListTile>(daily).value, isFalse);
      await tester.tap(daily);
      await tester.pump();
      oldResult.complete(
        oldFails
            ? const Left(NetworkFailure('old command failed'))
            : const Right(CoachWriteState.pending),
      );
      await tester.pump();
      expect(tester.widget<SwitchListTile>(daily).onChanged, isNull);
      expect(find.text(strings(tester).coachSaveFailed), findsNothing);
      expect(find.text(strings(tester).coachPreferencesPending), findsNothing);
      newResult.complete(const Right(CoachWriteState.confirmed));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(daily).onChanged, isNotNull);
      expect(tester.widget<SwitchListTile>(daily).value, isTrue);
      verify(() => repo.savePreferences('second-user', any())).called(1);
    });
  }

  testWidgets('late preference rejection clears pending notice, preserves draft and retries', (
    tester,
  ) async {
    final repo = repositoryFor();
    final failures = StreamController<CoachWriteFailure>.broadcast();
    final preferences = StreamController<CoachPreferences>.broadcast();
    addTearDown(failures.close);
    addTearDown(preferences.close);
    when(() => repo.watchWriteFailures(coachUid)).thenAnswer((_) => failures.stream);
    when(() => repo.watchPreferences(coachUid)).thenAnswer((_) async* {
      yield const CoachPreferences();
      yield* preferences.stream;
    });
    when(
      () => repo.savePreferences(coachUid, any()),
    ).thenAnswer((_) async => const Right(CoachWriteState.pending));
    await pumpCoach(tester, const CoachSettingsScreen(), repo);
    final toggle = find.byKey(const ValueKey('coach_daily_enabled'));
    await tapCoach(tester, toggle);
    final l10n = strings(tester);
    expect(find.text(l10n.coachPreferencesPending), findsOneWidget);
    for (final command in ['daily:2026-10-22', 'weekly:2026-10-12']) {
      failures.add(
        CoachWriteFailure(failure: const NetworkFailure('unrelated command'), commandKey: command),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.coachPreferencesPending), findsOneWidget);
      expect(find.text(l10n.coachSaveFailed), findsNothing);
    }
    failures.add(
      const CoachWriteFailure(
        failure: NetworkFailure('server rejected write'),
        commandKey: 'preferences',
      ),
    );
    await tester.pumpAndSettle();
    preferences.add(const CoachPreferences());
    await tester.pumpAndSettle();
    expect(find.text(l10n.coachPreferencesPending), findsNothing);
    expect(find.text(l10n.coachSaveFailed), findsOneWidget);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    when(
      () => repo.savePreferences(coachUid, any()),
    ).thenAnswer((_) async => const Right(CoachWriteState.confirmed));
    await tapCoach(tester, find.text(l10n.retry));
    expect(find.text(l10n.coachSaveFailed), findsNothing);
    final writes = verify(
      () => repo.savePreferences(coachUid, captureAny()),
    ).captured.cast<CoachPreferences>();
    expect(writes, hasLength(2));
    expect(writes.first.dailyEnabled, isTrue);
    expect(writes.last.toMap(), writes.first.toMap());
  });

  testWidgets('server acknowledgment clears pending preference notice', (tester) async {
    final repo = repositoryFor();
    final preferences = StreamController<CoachPreferences>.broadcast();
    addTearDown(preferences.close);
    when(() => repo.watchPreferences(coachUid)).thenAnswer((_) async* {
      yield const CoachPreferences();
      yield* preferences.stream;
    });
    when(
      () => repo.savePreferences(coachUid, any()),
    ).thenAnswer((_) async => const Right(CoachWriteState.pending));
    await pumpCoach(tester, const CoachSettingsScreen(), repo);
    await tapCoach(tester, find.byKey(const ValueKey('coach_daily_enabled')));
    final l10n = strings(tester);
    preferences.add(const CoachPreferences(dailyEnabled: true, hasPendingWrites: true));
    await tester.pumpAndSettle();
    expect(find.text(l10n.coachPreferencesPending), findsOneWidget);
    preferences.add(const CoachPreferences(dailyEnabled: true));
    await tester.pumpAndSettle();
    expect(find.text(l10n.coachPreferencesPending), findsNothing);
    expect(
      tester.widget<SwitchListTile>(find.byKey(const ValueKey('coach_daily_enabled'))).value,
      isTrue,
    );
  });

  testWidgets('last selected daily weekday cannot be removed or saved empty', (tester) async {
    final repo = repositoryFor(
      preferences: const CoachPreferences(dailyEnabled: true, dailyWeekdays: {4}),
    );
    await pumpCoach(tester, const CoachSettingsScreen(), repo);
    final thursday = find.byKey(const ValueKey('coach_daily_day_4'));
    await tapCoach(tester, thursday);
    expect(tester.widget<FilterChip>(thursday).selected, isTrue);
    verifyNever(() => repo.savePreferences(any(), any()));
    await tapCoach(tester, find.byKey(const ValueKey('coach_daily_day_5')));
    await tapCoach(tester, thursday);
    final writes = verify(
      () => repo.savePreferences(coachUid, captureAny()),
    ).captured.cast<CoachPreferences>();
    expect(writes.map((p) => p.dailyWeekdays), [
      {4, 5},
      {5},
    ]);
    expect(tester.widget<FilterChip>(thursday).selected, isFalse);
  });

  testWidgets('enabling reminders saves all defaults and preserves other toggle', (tester) async {
    final repo = repositoryFor();
    await pumpCoach(tester, const CoachSettingsScreen(), repo);
    await tapCoach(tester, find.byKey(const ValueKey('coach_daily_enabled')));
    await tapCoach(tester, find.byKey(const ValueKey('coach_weekly_enabled')));
    await tapCoach(tester, find.byKey(const ValueKey('coach_daily_enabled')));
    final writes = verify(
      () => repo.savePreferences(coachUid, captureAny()),
    ).captured.cast<CoachPreferences>();
    expect(writes, hasLength(3));
    expect(writes.first.toMap(), const CoachPreferences(dailyEnabled: true).toMap());
    expect(
      writes[1].toMap(),
      const CoachPreferences(dailyEnabled: true, weeklyEnabled: true).toMap(),
    );
    expect(writes.last.toMap(), const CoachPreferences(weeklyEnabled: true).toMap());
  });

  testWidgets('failed preference write preserves weekday draft and retries same values', (
    tester,
  ) async {
    final repo = repositoryFor(
      preferences: const CoachPreferences(
        dailyEnabled: true,
        dailyWeekdays: {1, 4},
        dailyHour: 7,
        dailyMinute: 15,
      ),
    );
    var attempts = 0;
    when(() => repo.savePreferences(coachUid, any())).thenAnswer(
      (_) async => ++attempts == 1
          ? const Left(NetworkFailure('offline'))
          : const Right(CoachWriteState.pending),
    );
    await pumpCoach(tester, const CoachSettingsScreen(), repo);
    await tapCoach(tester, find.byKey(const ValueKey('coach_daily_day_1')));
    final l10n = strings(tester);
    expect(find.text(l10n.coachSaveFailed), findsOneWidget);
    expect(
      tester.widget<FilterChip>(find.byKey(const ValueKey('coach_daily_day_1'))).selected,
      isFalse,
    );
    expect(
      tester.widget<FilterChip>(find.byKey(const ValueKey('coach_daily_day_4'))).selected,
      isTrue,
    );
    await tapCoach(tester, find.text(l10n.retry));
    expect(find.text(l10n.coachSaveFailed), findsNothing);
    expect(find.text(l10n.coachPreferencesPending), findsOneWidget);
    final writes = verify(
      () => repo.savePreferences(coachUid, captureAny()),
    ).captured.cast<CoachPreferences>();
    expect(writes, hasLength(2));
    expect(
      writes.first.toMap(),
      const CoachPreferences(
        dailyEnabled: true,
        dailyWeekdays: {4},
        dailyHour: 7,
        dailyMinute: 15,
      ).toMap(),
    );
    expect(writes.last.toMap(), writes.first.toMap());
  });

  for (final language in ['es', 'en', 'pt']) {
    testWidgets('settings fits compact enlarged text in $language', (tester) async {
      await pumpCoach(
        tester,
        const CoachSettingsScreen(),
        repositoryFor(),
        language: language,
        compact: true,
      );
      expect(find.text(strings(tester).coachSettingsIntro), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('coach_daily_day_7')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(strings(tester).coachWindowNotice),
        250,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
