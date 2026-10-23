import '../entities/coach_models.dart';

abstract interface class CoachClock {
  DateTime now();
}

class SystemCoachClock implements CoachClock {
  const SystemCoachClock();
  @override
  DateTime now() => DateTime.now().toUtc();
}

abstract interface class CoachCalendar {
  DateTime local(DateTime instant, String zone);
  DateTime at(String zone, int year, int month, int day, [int hour = 0, int minute = 0]);
}

String coachDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class CoachReminderPlan {
  const CoachReminderPlan({required this.kind, required this.periodKey, required this.scheduledAt});
  final CoachReviewKind kind;
  final String periodKey;
  final DateTime scheduledAt;
}

enum CoachNextStep { weekly, daily, current }

/// Calendar-day arithmetic intentionally avoids adding 24 hours across DST.
class CoachRoutine {
  const CoachRoutine(this.calendar, this.clock);
  final CoachCalendar calendar;
  final CoachClock clock;

  DateTime today(String zone) {
    final now = calendar.local(clock.now(), zone);
    return calendar.at(zone, now.year, now.month, now.day);
  }

  DateTime shift(DateTime date, String zone, int days) =>
      calendar.at(zone, date.year, date.month, date.day + days);

  DateTime previousWeek(String zone, [DateTime? date]) {
    final day = date ?? today(zone);
    return shift(day, zone, 1 - day.weekday - 7);
  }

  DateTime parseDay(String key, String zone) {
    final date = DateTime.tryParse(key);
    if (date == null || coachDateKey(date) != key) {
      throw const FormatException('invalid-coach-date');
    }
    return calendar.at(zone, date.year, date.month, date.day);
  }

  bool completed(Iterable<CoachCompletion> completions, CoachReviewKind kind, String key) =>
      completions.any((item) => item.kind == kind && item.periodKey == key);

  List<CoachReminderPlan> plan({
    required CoachPreferences preferences,
    required Iterable<CoachCompletion> completions,
    required String zone,
    DateTime? pausedUntil,
  }) {
    final result = <CoachReminderPlan>[];
    final now = clock.now();
    final start = today(zone);
    for (var offset = 0; offset < 28; offset++) {
      final date = shift(start, zone, offset);
      void add(CoachReviewKind kind, int hour, int minute, DateTime period) {
        final instant = calendar.at(zone, date.year, date.month, date.day, hour, minute).toUtc();
        final key = coachDateKey(period);
        if (!instant.isAfter(now) ||
            (pausedUntil != null && instant.isBefore(pausedUntil)) ||
            completed(completions, kind, key)) {
          return;
        }
        result.add(CoachReminderPlan(kind: kind, periodKey: key, scheduledAt: instant));
      }

      if (preferences.dailyEnabled && preferences.dailyWeekdays.contains(date.weekday)) {
        add(CoachReviewKind.daily, preferences.dailyHour, preferences.dailyMinute, date);
      }
      if (preferences.weeklyEnabled && date.weekday == preferences.weeklyWeekday) {
        add(
          CoachReviewKind.weekly,
          preferences.weeklyHour,
          preferences.weeklyMinute,
          previousWeek(zone, date),
        );
      }
    }
    // A shared delivery opens the weekly review; the daily task remains available in the app.
    final grouped = <DateTime, CoachReminderPlan>{};
    for (final reminder in result) {
      if (!grouped.containsKey(reminder.scheduledAt) || reminder.kind == CoachReviewKind.weekly) {
        grouped[reminder.scheduledAt] = reminder;
      }
    }
    return grouped.values.toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  CoachNextStep nextStep(
    CoachPreferences preferences,
    Iterable<CoachCompletion> completions,
    String zone,
  ) {
    final date = today(zone);
    final now = clock.now();
    final monday = shift(date, zone, 1 - date.weekday);
    final weeklyAt = calendar.at(
      zone,
      monday.year,
      monday.month,
      monday.day + preferences.weeklyWeekday - 1,
      preferences.weeklyHour,
      preferences.weeklyMinute,
    );
    if (preferences.weeklyEnabled &&
        !now.isBefore(weeklyAt) &&
        !completed(completions, CoachReviewKind.weekly, coachDateKey(previousWeek(zone)))) {
      return CoachNextStep.weekly;
    }
    final dailyAt = calendar.at(
      zone,
      date.year,
      date.month,
      date.day,
      preferences.dailyHour,
      preferences.dailyMinute,
    );
    if (preferences.dailyEnabled &&
        preferences.dailyWeekdays.contains(date.weekday) &&
        !now.isBefore(dailyAt) &&
        !completed(completions, CoachReviewKind.daily, coachDateKey(date))) {
      return CoachNextStep.daily;
    }
    return CoachNextStep.current;
  }
}
