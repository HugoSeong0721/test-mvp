import 'astro.dart';
import 'station.dart';
import 'tides.dart';

/// One station-local calendar day: its tides, sun and moon.
class DayInfo {
  DayInfo(this.station, this.data, this.wallDay)
    : start = station.zone.startOfDay(wallDay),
      end = station.zone.startOfDay(
        DateTime.utc(wallDay.year, wallDay.month, wallDay.day + 1),
      ) {
    events = data?.eventsBetween(start, end) ?? const [];
    sun = sunTimes(wallDay, station.lat, station.lng);
    moon = moonForDay(start, end);
  }

  final Station station;
  final TideData? data;
  final DateTime wallDay; // station-local date in UTC fields
  final DateTime start; // UTC
  final DateTime end; // UTC
  late final List<TideEvent> events;
  late final SunTimes sun;
  late final ({MoonPhase phase, double illumination, bool waxing}) moon;

  bool contains(DateTime utc) => !utc.isBefore(start) && utc.isBefore(end);

  /// Heights every 6 minutes across the day (null where NOAA data doesn't reach).
  List<(DateTime, double?)> curve({int stepMinutes = 6}) {
    final out = <(DateTime, double?)>[];
    for (
      var t = start;
      !t.isAfter(end);
      t = t.add(Duration(minutes: stepMinutes))
    ) {
      out.add((t, data?.heightAt(t)));
    }
    return out;
  }

  /// True when NOAA predictions cover the whole day.
  bool get hasData {
    final d = data;
    if (d == null || d.events.isEmpty) return false;
    return !d.events.first.time.isAfter(start) &&
        !d.events.last.time.isBefore(end);
  }
}

List<DayInfo> buildDays(
  Station s,
  TideData? d,
  DateTime nowUtc, {
  int count = 7,
}) {
  final today = s.zone.dayOf(nowUtc);
  return [
    for (var i = 0; i < count; i++)
      DayInfo(s, d, DateTime.utc(today.year, today.month, today.day + i)),
  ];
}
