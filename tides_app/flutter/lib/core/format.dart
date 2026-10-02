import 'zone.dart';

enum Units { feet, meters }

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _longDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String height(double feet, Units u, {bool unit = true}) {
  final v = u == Units.feet ? feet : feet * 0.3048;
  final s = v
      .toStringAsFixed(1)
      .replaceFirst('-0.0', '0.0')
      .replaceFirst('-', '−');
  if (!unit) return s;
  return '$s ${u == Units.feet ? 'ft' : 'm'}';
}

/// "2:58 PM" in the station's clock.
String clock(DateTime utc, StationZone z, {bool compact = false}) {
  final w = z.toWall(utc);
  final h12 = w.hour % 12 == 0 ? 12 : w.hour % 12;
  final mm = w.minute.toString().padLeft(2, '0');
  final ap = w.hour < 12 ? 'AM' : 'PM';
  return compact ? '$h12:$mm${ap[0].toLowerCase()}' : '$h12:$mm $ap';
}

/// "Fri, Oct 2"
String dayLabel(DateTime wallDay) =>
    '${_days[wallDay.weekday - 1]}, ${_months[wallDay.month - 1]} ${wallDay.day}';

String shortDay(DateTime wallDay) => _days[wallDay.weekday - 1];

String longDay(DateTime wallDay) => _longDays[wallDay.weekday - 1];

String monthDay(DateTime wallDay) =>
    '${_months[wallDay.month - 1]} ${wallDay.day}';

/// "in 2h 14m" / "in 35m"
String until(Duration d) {
  if (d.isNegative) return 'now';
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0) return 'in ${m}m';
  return 'in ${h}h ${m.toString().padLeft(2, '0')}m';
}

/// "Oct 2, 2:31 PM" in the device's own clock (for "Last updated").
String deviceStamp(DateTime utc) {
  final w = utc.toLocal();
  final h12 = w.hour % 12 == 0 ? 12 : w.hour % 12;
  return '${_months[w.month - 1]} ${w.day}, $h12:${w.minute.toString().padLeft(2, '0')} ${w.hour < 12 ? 'AM' : 'PM'}';
}

String miles(double mi) =>
    mi < 10 ? '${mi.toStringAsFixed(1)} mi' : '${mi.round()} mi';
