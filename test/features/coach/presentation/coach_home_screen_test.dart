import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/features/coach/domain/entities/coach_models.dart';
import 'package:personal_finance/features/coach/presentation/screens/coach_home_screen.dart';

import 'coach_test_support.dart';

void main() {
  setUp(registerCoachFallbacks);

  for (final language in ['es', 'en', 'pt']) {
    testWidgets('new routine invitation is opt-in in $language', (tester) async {
      final repository = repositoryFor();
      await pumpCoach(tester, const CoachHomeScreen(), repository, language: language);

      final daily = find.byKey(const ValueKey('coach_invite_daily'));
      final weekly = find.byKey(const ValueKey('coach_invite_weekly'));
      final start = find.byKey(const ValueKey('coach_routine_start'));
      await tester.ensureVisible(start);

      expect(find.text(strings(tester).coachRoutineInvite), findsWidgets);
      expect(tester.widget<SwitchListTile>(daily).value, isFalse);
      expect(tester.widget<SwitchListTile>(weekly).value, isFalse);
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      expect(find.byTooltip(strings(tester).settingsTitle), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final selection in [
    (daily: true, weekly: false),
    (daily: false, weekly: true),
    (daily: true, weekly: true),
  ]) {
    testWidgets(
      'activates only selected routines: daily=${selection.daily}, weekly=${selection.weekly}',
      (tester) async {
        final repository = repositoryFor();
        var stored = const CoachRoutinePreferences();
        when(() => repository.watchRoutinePreferences(any())).thenAnswer(
          (_) => Stream.value(stored),
        );
        when(() => repository.saveRoutinePreferences(coachUid, any())).thenAnswer((
          invocation,
        ) async {
          stored = invocation.positionalArguments[1] as CoachRoutinePreferences;
          return const Right(CoachWriteState.confirmed);
        });

        await pumpCoach(tester, const CoachHomeScreen(), repository, language: 'en');
        final daily = find.byKey(const ValueKey('coach_invite_daily'));
        final weekly = find.byKey(const ValueKey('coach_invite_weekly'));
        final start = find.byKey(const ValueKey('coach_routine_start'));

        if (selection.daily) await tapCoach(tester, daily);
        if (selection.weekly) await tapCoach(tester, weekly);
        expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
        await tapCoach(tester, start);

        expect(stored.configured, isTrue);
        expect(stored.dailyEnabled, selection.daily);
        expect(stored.weeklyEnabled, selection.weekly);
        expect(find.text(strings(tester).coachRoutineInvite), findsNothing);
        expect(find.text(strings(tester).coachRoutineOn), findsOneWidget);
        verify(() => repository.saveRoutinePreferences(coachUid, any())).called(1);
      },
    );
  }

  testWidgets('Not now dismisses the invitation but keeps manual reviews available', (
    tester,
  ) async {
    final repository = repositoryFor();
    var stored = const CoachRoutinePreferences();
    when(() => repository.watchRoutinePreferences(any())).thenAnswer((_) => Stream.value(stored));
    when(() => repository.saveRoutinePreferences(coachUid, any())).thenAnswer((invocation) async {
      stored = invocation.positionalArguments[1] as CoachRoutinePreferences;
      return const Right(CoachWriteState.confirmed);
    });

    await pumpCoach(tester, const CoachHomeScreen(), repository, language: 'en');
    final later = find.byKey(const ValueKey('coach_routine_later'));
    await tapCoach(tester, later);

    expect(stored.toMap(), const CoachRoutinePreferences(configured: true).toMap());
    expect(find.text(strings(tester).coachRoutineInvite), findsNothing);
    expect(find.text(strings(tester).coachRoutineOff), findsNWidgets(3));
    final dailyReview = find.widgetWithText(ListTile, strings(tester).coachDailyTitle);
    final weeklyReview = find.widgetWithText(ListTile, strings(tester).coachWeeklyTitle);
    expect(tester.widget<ListTile>(dailyReview).onTap, isNotNull);
    expect(tester.widget<ListTile>(weeklyReview).onTap, isNotNull);
    verify(() => repository.saveRoutinePreferences(coachUid, any())).called(1);
  });

  testWidgets('configured and legacy routines do not show the initial invitation', (tester) async {
    final repository = repositoryFor(
      preferences: const CoachPreferences(dailyEnabled: true),
    );
    await pumpCoach(tester, const CoachHomeScreen(), repository, language: 'en');

    expect(find.text(strings(tester).coachRoutineInvite), findsNothing);
    expect(find.text(strings(tester).coachRoutineOn), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
      isTrue,
    );
  });

  testWidgets('explicitly configured routines preserve their selected values', (tester) async {
    final repository = repositoryFor();
    when(() => repository.watchRoutinePreferences(any())).thenAnswer(
      (_) => Stream.value(
        const CoachRoutinePreferences(configured: true, weeklyEnabled: true),
      ),
    );
    await pumpCoach(tester, const CoachHomeScreen(), repository, language: 'en');

    expect(find.text(strings(tester).coachRoutineInvite), findsNothing);
    final switches = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
    expect(switches, hasLength(2));
    expect(switches[0].value, isFalse);
    expect(switches[1].value, isTrue);
    verifyNever(() => repository.saveRoutinePreferences(any(), any()));
  });

  testWidgets('coach hub exposes both routines, history and reminder settings', (tester) async {
    final repository = repositoryFor(
      completions: [
        const CoachCompletion(periodKey: '2026-10-21', kind: CoachReviewKind.daily),
      ],
    );
    await pumpCoach(tester, const CoachHomeScreen(), repository, language: 'en');

    expect(find.text('Your financial coach'), findsOneWidget);
    expect(find.text('Daily check-in'), findsWidgets);
    expect(find.text('Weekly review'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Recent reviews'), 300);
    expect(find.text('Recent reviews'), findsOneWidget);
    expect(find.text('2026-10-21'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Set reminders'), 300);
    expect(find.text('Set reminders'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coach hub remains readable on compact screen with enlarged Portuguese text', (
    tester,
  ) async {
    await pumpCoach(
      tester,
      const CoachHomeScreen(),
      repositoryFor(),
      language: 'pt',
      compact: true,
    );

    expect(find.text('Seu coach financeiro'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Revisão diária'), 300);
    expect(find.text('Revisão diária'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Revisão semanal'), 300);
    expect(find.text('Revisão semanal'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
