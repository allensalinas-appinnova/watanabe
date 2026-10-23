import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/coach/data/calendar/zoned_coach_calendar.dart';
import 'package:personal_finance/features/coach/domain/entities/coach_models.dart';
import 'package:personal_finance/features/coach/domain/usecases/coach_routine.dart';

class _Clock implements CoachClock {
  _Clock(String instant) : instant = DateTime.parse(instant);
  DateTime instant;
  @override
  DateTime now() => instant;
}

void main() {
  late ZonedCoachCalendar calendar;
  late _Clock clock;
  late CoachRoutine routine;
  const zone = 'America/New_York';
  setUp(() {
    calendar = ZonedCoachCalendar();
    clock = _Clock('2026-10-22T12:00:00Z');
    routine = CoachRoutine(calendar, clock);
  });

  for (final entry in {
    '2026-01-01T12:00:00Z': '2025-12-22',
    '2026-03-02T12:00:00Z': '2026-02-23',
    '2026-03-09T12:00:00Z': '2026-03-02',
    '2026-11-02T12:00:00Z': '2026-10-26',
    '2026-10-25T12:00:00Z': '2026-10-12',
  }.entries) {
    test('previous Mon–Sun week at ${entry.key}', () {
      clock.instant = DateTime.parse(entry.key);
      final monday = routine.previousWeek(zone);
      final sunday = routine.shift(monday, zone, 6);
      expect(coachDateKey(monday), entry.value);
      expect(monday.weekday, DateTime.monday);
      expect(sunday.weekday, DateTime.sunday);
      expect(sunday.hour, 0);
      final nextMonday = routine.shift(monday, zone, 7);
      expect(
        coachDateKey(nextMonday),
        coachDateKey(routine.shift(routine.today(zone), zone, 1 - routine.today(zone).weekday)),
      );
    });
  }

  test('DST weeks keep local midnight with 167/169 elapsed hours', () {
    final spring = calendar.at(zone, 2026, 3, 2);
    final autumn = calendar.at(zone, 2026, 10, 26);
    expect(routine.shift(spring, zone, 7).difference(spring).inHours, 167);
    expect(routine.shift(autumn, zone, 7).difference(autumn).inHours, 169);
    expect(calendar.local(DateTime.utc(2026, 1, 1, 2), zone).day, 31);
  });

  test('missing preferences default to disabled with local schedule defaults', () {
    final prefs = CoachPreferences.fromMap(null);
    expect(prefs.toMap(), {
      'dailyEnabled': false,
      'weeklyEnabled': false,
      'dailyHour': 20,
      'dailyMinute': 30,
      'dailyWeekdays': [1, 2, 3, 4, 5, 6, 7],
      'weeklyWeekday': 1,
      'weeklyHour': 9,
      'weeklyMinute': 0,
    });
    expect(routine.plan(preferences: prefs, completions: [], zone: zone), isEmpty);
    expect(routine.nextStep(prefs, [], zone), CoachNextStep.current);
  });

  test('enabled daily reminder spans exactly 28 local dates across DST', () {
    clock.instant = DateTime.utc(2026, 3, 1, 12);
    final plans = routine.plan(
      preferences: const CoachPreferences(dailyEnabled: true),
      completions: [],
      zone: zone,
    );
    expect(plans, hasLength(28));
    expect(plans.first.periodKey, '2026-03-01');
    expect(plans.last.periodKey, '2026-03-28');
    expect(plans.map((p) => p.periodKey).toSet(), hasLength(28));
    for (final plan in plans) {
      final local = calendar.local(plan.scheduledAt, zone);
      expect(local.hour, 20);
      expect(local.minute, 30);
      expect(coachDateKey(local), plan.periodKey);
      expect(plan.scheduledAt.isAfter(clock.now()), isTrue);
    }
    expect(plans[7].scheduledAt.difference(plans[6].scheduledAt).inHours, 23);
  });

  test('selected weekdays and future instants only; no expired delivery', () {
    clock.instant = DateTime.utc(2026, 10, 22, 22);
    final plans = routine.plan(
      preferences: const CoachPreferences(
        dailyEnabled: true,
        dailyWeekdays: {4},
        dailyHour: 18,
        dailyMinute: 0,
      ),
      completions: [],
      zone: zone,
    );
    expect(plans.map((p) => p.periodKey), ['2026-10-29', '2026-11-05', '2026-11-12']);
  });

  test('pending and confirmed completions suppress only their kind and period', () {
    clock.instant = DateTime.utc(2026, 10, 19, 10);
    const prefs = CoachPreferences(dailyEnabled: true, weeklyEnabled: true);
    final plans = routine.plan(
      preferences: prefs,
      zone: zone,
      completions: const [
        CoachCompletion(kind: CoachReviewKind.daily, periodKey: '2026-10-19', pending: true),
        CoachCompletion(kind: CoachReviewKind.weekly, periodKey: '2026-10-12'),
        CoachCompletion(kind: CoachReviewKind.weekly, periodKey: '2026-10-20'),
      ],
    );
    expect(plans.where((p) => p.periodKey == '2026-10-12'), isEmpty);
    expect(
      plans.where((p) => p.kind == CoachReviewKind.daily && p.periodKey == '2026-10-19'),
      isEmpty,
    );
    expect(
      plans.any((p) => p.kind == CoachReviewKind.daily && p.periodKey == '2026-10-20'),
      isTrue,
    );
    expect(
      plans.any((p) => p.kind == CoachReviewKind.weekly && p.periodKey == '2026-10-19'),
      isTrue,
    );
  });

  test('same delivery time is grouped with weekly priority', () {
    clock.instant = DateTime.utc(2026, 10, 19, 10);
    final plans = routine.plan(
      preferences: const CoachPreferences(
        dailyEnabled: true,
        weeklyEnabled: true,
        dailyHour: 9,
        dailyMinute: 0,
      ),
      completions: [],
      zone: zone,
    );
    expect(plans, hasLength(28));
    expect(plans.map((p) => p.scheduledAt).toSet(), hasLength(28));
    expect(plans.where((p) => p.kind == CoachReviewKind.weekly), hasLength(4));
    expect(plans.first.kind, CoachReviewKind.weekly);
    expect(plans.first.periodKey, '2026-10-12');
    expect(plans[1].kind, CoachReviewKind.daily);
    expect(plans[1].periodKey, '2026-10-20');
  });

  test('seven-day pause includes delivery at resume and never catches up', () {
    clock.instant = DateTime.utc(2026, 10, 19, 13);
    final resume = clock.now().add(const Duration(days: 7));
    const prefs = CoachPreferences(dailyEnabled: true, dailyHour: 9, dailyMinute: 0);
    final plans = routine.plan(
      preferences: prefs,
      completions: [],
      zone: zone,
      pausedUntil: resume,
    );
    expect(plans, hasLength(21));
    expect(plans.first.scheduledAt, resume);
    expect(plans.first.periodKey, '2026-10-26');
    clock.instant = resume;
    final resumed = routine.plan(preferences: prefs, completions: [], zone: zone);
    expect(resumed.first.periodKey, '2026-10-27');
    expect(resumed, hasLength(27));
  });

  test('completed weekly task leaves coincident daily delivery available', () {
    clock.instant = DateTime.utc(2026, 10, 19, 10);
    final plans = routine.plan(
      preferences: const CoachPreferences(
        dailyEnabled: true,
        weeklyEnabled: true,
        dailyHour: 9,
        dailyMinute: 0,
      ),
      completions: const [
        CoachCompletion(kind: CoachReviewKind.weekly, periodKey: '2026-10-12', pending: true),
      ],
      zone: zone,
    );
    expect(plans.first.scheduledAt, DateTime.utc(2026, 10, 19, 13));
    expect(plans.first.kind, CoachReviewKind.daily);
    expect(plans.first.periodKey, '2026-10-19');
    expect(plans, hasLength(28));
  });

  test('next step prioritizes due weekly then daily then current', () {
    clock.instant = DateTime.utc(2026, 10, 19, 23);
    const prefs = CoachPreferences(
      dailyEnabled: true,
      weeklyEnabled: true,
      dailyHour: 9,
      dailyMinute: 0,
    );
    const weekly = CoachCompletion(
      kind: CoachReviewKind.weekly,
      periodKey: '2026-10-12',
      pending: true,
    );
    const daily = CoachCompletion(kind: CoachReviewKind.daily, periodKey: '2026-10-19');
    expect(routine.nextStep(prefs, [], zone), CoachNextStep.weekly);
    expect(routine.nextStep(prefs, [weekly], zone), CoachNextStep.daily);
    expect(routine.nextStep(prefs, [weekly, daily], zone), CoachNextStep.current);
  });

  test('next step respects time, weekdays, disabled tasks and no backlogs', () {
    const prefs = CoachPreferences(dailyEnabled: true, weeklyEnabled: true);
    clock.instant = DateTime.utc(2026, 10, 19, 12, 59);
    expect(routine.nextStep(prefs, [], zone), CoachNextStep.current);
    clock.instant = DateTime.utc(2026, 10, 19, 13);
    expect(routine.nextStep(prefs, [], zone), CoachNextStep.weekly);
    clock.instant = DateTime.utc(2026, 10, 20, 1);
    expect(routine.nextStep(prefs.copyWith(weeklyEnabled: false), [], zone), CoachNextStep.daily);
    expect(
      routine.nextStep(prefs.copyWith(weeklyEnabled: false, dailyWeekdays: {2}), [], zone),
      CoachNextStep.current,
    );
    clock.instant = DateTime.utc(2026, 10, 26, 12);
    expect(routine.nextStep(prefs, [], zone), CoachNextStep.current);
    expect(routine.nextStep(const CoachPreferences(), [], zone), CoachNextStep.current);
  });

  test('weekly-only plans contain four previous-week keys across the year boundary', () {
    clock.instant = DateTime.utc(2025, 12, 29, 12);
    final plans = routine.plan(
      preferences: const CoachPreferences(weeklyEnabled: true),
      completions: [],
      zone: zone,
    );
    expect(plans.map((p) => p.periodKey), ['2025-12-22', '2025-12-29', '2026-01-05', '2026-01-12']);
    for (final plan in plans) {
      expect(plan.kind, CoachReviewKind.weekly);
      final local = calendar.local(plan.scheduledAt, zone);
      expect(local.weekday, DateTime.monday);
      expect(local.hour, 9);
      expect(local.minute, 0);
    }
  });

  test('daily task becomes due exactly at local time and never carries to next day', () {
    const prefs = CoachPreferences(dailyEnabled: true);
    clock.instant = DateTime.utc(2026, 10, 23, 0, 29, 59);
    expect(routine.nextStep(prefs, [], zone), CoachNextStep.current);
    clock.instant = DateTime.utc(2026, 10, 23, 0, 30);
    expect(routine.nextStep(prefs, [], zone), CoachNextStep.daily);
    expect(
      routine.nextStep(prefs, const [
        CoachCompletion(kind: CoachReviewKind.daily, periodKey: '2026-10-22', pending: true),
      ], zone),
      CoachNextStep.current,
    );
    clock.instant = DateTime.utc(2026, 10, 23, 4);
    expect(routine.nextStep(prefs, [], zone), CoachNextStep.current);
  });
}
