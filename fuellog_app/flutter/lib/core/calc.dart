/// 연비·비용·정비 알림 계산. 화면·저장과 떨어져 있어 엔진 테스트로 숫자를 고정한다.
library;

import 'dart:math' as math;

import 'model.dart';

/// 가득 → 가득 사이 한 탱크. 사이의 부분 주유량도 이 탱크에 더한다.
class Tank {
  Tank({
    required this.end,
    required this.startOdometer,
    required this.gallons,
    required this.cost,
    required this.fills,
  });

  /// 탱크를 닫은 가득 주유
  final FillUp end;
  final double startOdometer;
  final double gallons;
  final double cost;

  /// 이 탱크에 들어간 주유 횟수 (부분 포함)
  final int fills;

  double get miles => end.odometer - startOdometer;
  double get mpg => miles / gallons;
  double get costPerMile => miles > 0 ? cost / miles : 0;
  DateTime get date => end.date;
}

/// 주유 한 번이 연비 계산에서 어떤 자리인지.
enum FillRole {
  /// 탱크를 닫아 연비가 나온 가득 주유
  tank,

  /// 첫 가득 주유 — 기준점이라 연비가 아직 없다
  first,

  /// 부분 주유 — 다음 가득 주유의 탱크에 더해진다
  partial,

  /// 기록 안 한 주유가 끼어 있어 이 탱크는 건너뜀
  skipped,

  /// 첫 가득 주유 전의 부분 주유 — 연비에 쓸 수 없다
  beforeFirst,
}

class FillInfo {
  const FillInfo(this.role, [this.tank]);
  final FillRole role;
  final Tank? tank;
}

int _byOdometer(FillUp a, FillUp b) {
  final c = a.odometer.compareTo(b.odometer);
  return c != 0 ? c : a.date.compareTo(b.date);
}

/// 한 차량의 기록을 계산해 둔 것.
class VehicleLog {
  VehicleLog(Iterable<FillUp> fills, Iterable<Service> services)
    : fills = fills.toList()..sort(_byOdometer),
      services = services.toList()..sort((a, b) => a.date.compareTo(b.date)) {
    _build();
  }

  /// 주행거리 순
  final List<FillUp> fills;

  /// 날짜 순
  final List<Service> services;

  final tanks = <Tank>[];
  final info = <String, FillInfo>{};

  void _build() {
    double? startOdo;
    var gal = 0.0, cost = 0.0, n = 0;
    var broken = false;
    final pending = <FillUp>[];
    for (final f in fills) {
      if (startOdo == null) {
        if (f.full) {
          startOdo = f.odometer;
          info[f.id] = const FillInfo(FillRole.first);
        } else {
          info[f.id] = const FillInfo(FillRole.beforeFirst);
        }
        continue;
      }
      if (f.missed) broken = true;
      gal += f.volume;
      cost += f.cost;
      n++;
      if (!f.full) {
        pending.add(f);
        continue;
      }
      if (!broken && gal > 0 && f.odometer > startOdo) {
        final t = Tank(end: f, startOdometer: startOdo, gallons: gal, cost: cost, fills: n);
        tanks.add(t);
        info[f.id] = FillInfo(FillRole.tank, t);
        for (final p in pending) {
          info[p.id] = FillInfo(FillRole.partial, t);
        }
      } else {
        info[f.id] = const FillInfo(FillRole.skipped);
        for (final p in pending) {
          info[p.id] = const FillInfo(FillRole.skipped);
        }
      }
      startOdo = f.odometer;
      gal = 0;
      cost = 0;
      n = 0;
      broken = false;
      pending.clear();
    }
    // 아직 닫히지 않은 탱크의 부분 주유
    for (final p in pending) {
      info[p.id] = const FillInfo(FillRole.partial);
    }
  }

  bool get isEmpty => fills.isEmpty && services.isEmpty;

  /// 평균 연비 = 전체 거리 ÷ 전체 연료 (탱크마다 평균을 내서 다시 평균하면 짧은 탱크가 과대 반영된다).
  double? avgMpg({DateTime? since}) {
    var mi = 0.0, gal = 0.0;
    for (final t in tanks) {
      if (since != null && t.date.isBefore(since)) continue;
      mi += t.miles;
      gal += t.gallons;
    }
    return gal > 0 ? mi / gal : null;
  }

  Tank? get lastTank => tanks.isEmpty ? null : tanks.reduce((a, b) => b.date.isAfter(a.date) ? b : a);

  /// 연료비 ÷ 거리 (탱크로 잰 구간만).
  double? fuelCostPerMile({DateTime? since}) {
    var mi = 0.0, c = 0.0;
    for (final t in tanks) {
      if (since != null && t.date.isBefore(since)) continue;
      mi += t.miles;
      c += t.cost;
    }
    return mi > 0 ? c / mi : null;
  }

  double fuelSpent({DateTime? since, DateTime? until}) =>
      fills.where((f) => _inRange(f.date, since, until)).fold(0.0, (s, f) => s + f.cost);

  double serviceSpent({DateTime? since, DateTime? until}) =>
      services.where((s) => _inRange(s.date, since, until)).fold(0.0, (s, e) => s + e.cost);

  double gallonsBought({DateTime? since}) =>
      fills.where((f) => _inRange(f.date, since, null)).fold(0.0, (s, f) => s + f.volume);

  /// 갤런당 평균 가격 (산 양으로 가중).
  double? avgPricePerGallon({DateTime? since}) {
    final g = gallonsBought(since: since);
    return g > 0 ? fuelSpent(since: since) / g : null;
  }

  /// 연비가 기록된 구간의 총 거리.
  double trackedMiles({DateTime? since}) =>
      tanks.where((t) => since == null || !t.date.isBefore(since)).fold(0.0, (s, t) => s + t.miles);

  /// 주행거리를 아는 모든 점 (주유 + 주행거리를 적은 정비), 날짜 순.
  List<(DateTime, double)> get odometerPoints {
    final pts = <(DateTime, double)>[
      for (final f in fills) (f.date, f.odometer),
      for (final s in services)
        if (s.odometer != null) (s.date, s.odometer!),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return pts;
  }

  /// 지금까지 아는 가장 큰 주행거리.
  double? get latestOdometer {
    double? m;
    for (final (_, o) in odometerPoints) {
      if (m == null || o > m) m = o;
    }
    return m;
  }

  DateTime? get latestOdometerDate {
    final pts = odometerPoints;
    if (pts.isEmpty) return null;
    final top = latestOdometer!;
    return pts.lastWhere((p) => p.$2 == top).$1;
  }

  /// 그 날짜 이전에 마지막으로 아는 주행거리.
  double? odometerAt(DateTime d) {
    double? best;
    for (final (t, o) in odometerPoints) {
      if (!t.isAfter(d) && (best == null || o > best)) best = o;
    }
    return best;
  }

  /// 하루 평균 주행거리 — 최근 180일 기록으로, 14일 이상 쌓여야 낸다 (거리 알림 날짜 추정용).
  double? milesPerDay() {
    final pts = odometerPoints;
    if (pts.length < 2) return null;
    double? rate(List<(DateTime, double)> p) {
      if (p.length < 2) return null;
      final days = p.last.$1.difference(p.first.$1).inHours / 24;
      final mi = p.map((e) => e.$2).reduce(math.max) - p.map((e) => e.$2).reduce(math.min);
      if (days < 14 || mi <= 0) return null;
      return mi / days;
    }

    final cut = pts.last.$1.subtract(const Duration(days: 180));
    return rate(pts.where((p) => !p.$1.isBefore(cut)).toList()) ?? rate(pts);
  }

  /// 달마다 연료비·정비비 (첫 기록 달부터 [now] 달까지, 빈 달 포함).
  List<MonthCost> monthly(DateTime now) {
    final dates = [for (final f in fills) f.date, for (final s in services) s.date];
    if (dates.isEmpty) return [];
    final first = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final last = dates.fold(now, (a, b) => b.isAfter(a) ? b : a);
    final out = <MonthCost>[];
    var y = first.year, m = first.month;
    while (y < last.year || (y == last.year && m <= last.month)) {
      final from = DateTime(y, m), to = DateTime(y, m + 1);
      out.add(
        MonthCost(
          year: y,
          month: m,
          fuel: fuelSpent(since: from, until: to),
          service: serviceSpent(since: from, until: to),
          gallons: fills.where((f) => _inRange(f.date, from, to)).fold(0.0, (s, f) => s + f.volume),
        ),
      );
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return out;
  }
}

bool _inRange(DateTime d, DateTime? since, DateTime? until) =>
    (since == null || !d.isBefore(since)) && (until == null || d.isBefore(until));

class MonthCost {
  const MonthCost({
    required this.year,
    required this.month,
    required this.fuel,
    required this.service,
    required this.gallons,
  });
  final int year, month;
  final double fuel, service, gallons;
  double get total => fuel + service;
}

DateTime addMonths(DateTime d, int n) {
  final y = d.year + ((d.month - 1 + n) ~/ 12);
  final m = (d.month - 1 + n) % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, math.min(d.day, last), d.hour, d.minute);
}

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// 달력 날짜 차이 (서머타임에 흔들리지 않게 UTC 로 센다).
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

enum ReminderLevel { ok, soon, overdue, unknown }

/// 알림 하나의 지금 상태.
class ReminderState {
  ReminderState._(this.reminder);

  final Reminder reminder;

  /// 마지막으로 한 때 (정비 기록 또는 알림 만들 때 적은 값)
  DateTime? baseDate;
  double? baseOdometer;

  /// 기준이 된 정비 기록 (없으면 알림에 적은 값)
  Service? lastService;

  double? dueOdometer;
  DateTime? dueDate;

  /// 남은 거리 (마일, 음수면 지남)
  double? milesLeft;

  /// 남은 날 (음수면 지남)
  int? daysLeft;

  /// 거리 기준 예상 날짜 (하루 평균 주행거리로). 지난 날짜가 되면 오늘로 둔다.
  DateTime? estimatedDate;

  /// 예상으로는 이미 그 거리를 넘었을 것 (기록만 아직 없음) → "아마 지금쯤"
  bool estimatePassed = false;

  ReminderLevel level = ReminderLevel.unknown;

  /// 주기 중 얼마나 왔나 (1 이상이면 지남)
  double progress = 0;

  /// 기준 시각 (상태를 계산한 때)
  late final DateTime _now;

  /// 알림을 띄울 때 — 날짜와 예상 날짜 중 빠른 쪽, 아침 9시.
  /// 그 아침이 이미 지났으면(예상이 지나 버림 등) 다음 날 아침 — 앱을 안 열면 다음 날 알려 준다.
  DateTime? get notifyAt {
    final c = [?dueDate, ?estimatedDate];
    if (c.isEmpty) return null;
    final d = c.reduce((a, b) => a.isBefore(b) ? a : b);
    var at = DateTime(d.year, d.month, d.day, 9);
    if (!at.isAfter(_now) && (estimatePassed || level == ReminderLevel.overdue)) {
      at = DateTime(_now.year, _now.month, _now.day + 1, 9);
    }
    return at;
  }

  static ReminderState of(Reminder r, VehicleLog log, DateTime now) {
    final s = ReminderState._(r).._now = now;
    // 같은 종류의 가장 최근 정비
    Service? last;
    for (final e in log.services) {
      if (sameKind(e.kind, r.kind) && (last == null || !e.date.isBefore(last.date))) {
        last = e;
      }
    }
    final manualNewer = r.lastDate != null && (last == null || r.lastDate!.isAfter(last.date));
    if (last != null && !manualNewer) {
      s.lastService = last;
      s.baseDate = last.date;
      s.baseOdometer = last.odometer ?? log.odometerAt(last.date);
    } else {
      s.baseDate = r.lastDate;
      s.baseOdometer = r.lastOdometer;
    }

    final cur = log.latestOdometer;
    final today = dayOf(now);
    var used = 0.0;
    if (r.everyMiles != null && s.baseOdometer != null) {
      s.dueOdometer = s.baseOdometer! + r.everyMiles!;
      final at = math.max(cur ?? s.baseOdometer!, s.baseOdometer!);
      s.milesLeft = s.dueOdometer! - at;
      used = math.max(used, (at - s.baseOdometer!) / r.everyMiles!);
      final rate = log.milesPerDay();
      final from = log.latestOdometerDate ?? s.baseDate;
      if (rate != null && rate > 0 && from != null && s.milesLeft! > 0) {
        final est = dayOf(from).add(Duration(days: (s.milesLeft! / rate).ceil()));
        s.estimatePassed = !est.isAfter(today);
        s.estimatedDate = s.estimatePassed ? today : est;
      }
    }
    if (r.everyMonths != null && s.baseDate != null) {
      s.dueDate = dayOf(addMonths(s.baseDate!, r.everyMonths!));
      s.daysLeft = daysBetween(today, s.dueDate!);
      final total = daysBetween(dayOf(s.baseDate!), s.dueDate!);
      if (total > 0) {
        used = math.max(used, daysBetween(dayOf(s.baseDate!), today) / total);
      }
    }
    s.progress = used.clamp(0, 1.5).toDouble();
    if (s.dueOdometer == null && s.dueDate == null) {
      s.level = ReminderLevel.unknown;
    } else if ((s.milesLeft != null && s.milesLeft! <= 0) || (s.daysLeft != null && s.daysLeft! < 0)) {
      s.level = ReminderLevel.overdue;
    } else if ((s.milesLeft != null && s.milesLeft! <= math.min(500, r.everyMiles! * 0.1)) ||
        (s.daysLeft != null && s.daysLeft! <= 14)) {
      s.level = ReminderLevel.soon;
    } else {
      s.level = ReminderLevel.ok;
    }
    // 기록은 아직 안 넘었지만 운전 습관으로 보면 넘었을 때 → 최소 '곧'
    if (s.estimatePassed && s.level == ReminderLevel.ok) s.level = ReminderLevel.soon;
    return s;
  }
}

/// 로드트립 기름값 나누기.
class TripCost {
  const TripCost({
    required this.miles,
    required this.mpg,
    required this.pricePerGallon,
    required this.people,
    this.roundTrip = false,
  });
  final double miles, mpg, pricePerGallon;
  final int people;
  final bool roundTrip;

  double get totalMiles => miles * (roundTrip ? 2 : 1);
  double get gallons => mpg > 0 ? totalMiles / mpg : 0;
  double get total => gallons * pricePerGallon;
  double get perPerson => people > 0 ? total / people : total;
  bool get valid => miles > 0 && mpg > 0 && pricePerGallon > 0 && people > 0;
}
