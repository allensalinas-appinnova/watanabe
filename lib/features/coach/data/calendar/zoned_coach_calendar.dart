import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/usecases/coach_routine.dart';

class ZonedCoachCalendar implements CoachCalendar {
  ZonedCoachCalendar() {
    data.initializeTimeZones();
  }

  tz.Location _zone(String name) {
    try {
      return tz.getLocation(name);
    } on tz.LocationNotFoundException {
      return tz.UTC;
    }
  }

  @override
  DateTime local(DateTime instant, String zone) => tz.TZDateTime.from(instant, _zone(zone));

  @override
  DateTime at(String zone, int year, int month, int day, [int hour = 0, int minute = 0]) =>
      tz.TZDateTime(_zone(zone), year, month, day, hour, minute);
}
