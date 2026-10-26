import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Returns the next nominal payment date in the profile's time zone.
///
/// A due day that does not exist in a month is clamped to that month's last
/// calendar day. If the nominal date is today, today is returned.
DateTime nextNominalPaymentDate({
  required DateTime instant,
  required String timeZone,
  required int dueDay,
}) {
  if (dueDay < 1 || dueDay > 31) throw RangeError.range(dueDay, 1, 31, 'dueDay');
  tzdata.initializeTimeZones();
  final location = _location(timeZone);
  final today = tz.TZDateTime.from(instant.toUtc(), location);
  DateTime inMonth(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, dueDay.clamp(1, lastDay));
  }

  var candidate = inMonth(today.year, today.month);
  if (candidate.day < today.day) {
    final nextMonth = DateTime(today.year, today.month + 1);
    candidate = inMonth(nextMonth.year, nextMonth.month);
  }
  return candidate;
}

tz.Location _location(String name) {
  try {
    return tz.getLocation(name);
  } on tz.LocationNotFoundException {
    return tz.UTC;
  }
}
