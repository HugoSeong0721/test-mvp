import 'zone.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _longDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// "2:58 PM" on the place's clock.
String clock(DateTime utc, PlaceZone z, {bool compact = false}) {
  final w = z.toWall(utc);
  final h12 = w.hour % 12 == 0 ? 12 : w.hour % 12;
  final mm = w.minute.toString().padLeft(2, '0');
  final ap = w.hour < 12 ? 'AM' : 'PM';
  return compact ? '$h12:$mm${ap[0].toLowerCase()}' : '$h12:$mm $ap';
}

/// "1:12 – 3:12 PM" (one AM/PM when both ends share it).
String span(DateTime a, DateTime b, PlaceZone z) {
  final x = clock(a, z), y = clock(b, z);
  if (x.substring(x.length - 2) == y.substring(y.length - 2)) {
    return '${x.substring(0, x.length - 3)} – $y';
  }
  return '$x – $y';
}

/// "Fri, Oct 2"
String dayLabel(DateTime wallDay) => '${_days[wallDay.weekday - 1]}, ${_months[wallDay.month - 1]} ${wallDay.day}';

String shortDay(DateTime wallDay) => _days[wallDay.weekday - 1];

String longDay(DateTime wallDay) => _longDays[wallDay.weekday - 1];

String monthDay(DateTime wallDay) => '${_months[wallDay.month - 1]} ${wallDay.day}';

String monthName(DateTime wallDay) => _months[wallDay.month - 1];

/// "2h 14m" / "35m" / "<1m"
String duration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0) return d.inMinutes == 0 ? '<1m' : '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

String miles(double mi) => mi < 10 ? '${mi.toStringAsFixed(1)} mi' : '${mi.round()} mi';

/// "Today", "Tomorrow", or "Fri, Oct 2".
String relativeDay(DateTime wallDay, DateTime todayWall) {
  final diff = DateTime.utc(
    wallDay.year,
    wallDay.month,
    wallDay.day,
  ).difference(DateTime.utc(todayWall.year, todayWall.month, todayWall.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return dayLabel(wallDay);
}

/// 20102 → "20,102"
String thousands(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
