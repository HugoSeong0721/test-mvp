/// 기록 데이터. 거리는 마일, 부피는 미국 갤런, 돈은 그냥 숫자(통화 기호는 화면에서).
/// 저장 파일 하나(JSON)에 전부 들어간다 — 서버·계정 없음.
library;

import 'units.dart';

var _seq = 0;

/// 기기 안에서만 겹치지 않으면 되는 ID.
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++ % 1296).toRadixString(36).padLeft(2, '0')}';

double? _num(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
String _str(Object? v) => v is String ? v : '';

String _iso(DateTime d) => d.toIso8601String();

class Vehicle {
  Vehicle({required this.id, required this.name});

  final String id;
  String name;

  Map<String, Object> toJson() => {'id': id, 'name': name};

  static Vehicle? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String) return null;
    final name = _str(j['name']).trim();
    return Vehicle(id: j['id'] as String, name: name.isEmpty ? 'My Car' : name);
  }
}

class FillUp {
  FillUp({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.volume,
    required this.cost,
    this.full = true,
    this.missed = false,
    this.note = '',
  });

  final String id;
  String vehicleId;
  DateTime date;

  /// 마일
  double odometer;

  /// 미국 갤런
  double volume;

  /// 총액
  double cost;

  /// 가득 채웠나 — 연비는 가득 → 가득 사이로 계산한다.
  bool full;

  /// 이 주유 전에 기록하지 않은 주유가 있었다 → 이 탱크의 연비는 건너뛴다.
  bool missed;
  String note;

  double get pricePerGallon => volume > 0 ? cost / volume : 0;

  Map<String, Object> toJson() => {
    'id': id,
    'vehicle': vehicleId,
    'date': _iso(date),
    'odo': odometer,
    'vol': volume,
    'cost': cost,
    'full': full,
    'missed': missed,
    if (note.isNotEmpty) 'note': note,
  };

  static FillUp? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], v = j['vehicle'];
    final date = _date(j['date']);
    final odo = _num(j['odo']), vol = _num(j['vol']), cost = _num(j['cost']);
    if (id is! String || v is! String || date == null) return null;
    if (odo == null || vol == null || cost == null) return null;
    if (odo < 0 || vol <= 0 || cost < 0) return null;
    return FillUp(
      id: id,
      vehicleId: v,
      date: date,
      odometer: odo,
      volume: vol,
      cost: cost,
      full: j['full'] != false,
      missed: j['missed'] == true,
      note: _str(j['note']),
    );
  }
}

/// 정비·기타 비용 (오일 교환, 타이어, 보험, 주차 …).
class Service {
  Service({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.kind,
    this.odometer,
    this.cost = 0,
    this.note = '',
  });

  final String id;
  String vehicleId;
  DateTime date;
  String kind;

  /// 마일. 모르면 비워 둘 수 있다 (보험·주차 등).
  double? odometer;
  double cost;
  String note;

  Map<String, Object> toJson() => {
    'id': id,
    'vehicle': vehicleId,
    'date': _iso(date),
    'kind': kind,
    'odo': ?odometer,
    'cost': cost,
    if (note.isNotEmpty) 'note': note,
  };

  static Service? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], v = j['vehicle'];
    final date = _date(j['date']);
    final kind = _str(j['kind']).trim();
    if (id is! String || v is! String || date == null || kind.isEmpty) {
      return null;
    }
    final odo = _num(j['odo']);
    return Service(
      id: id,
      vehicleId: v,
      date: date,
      kind: kind,
      odometer: odo != null && odo >= 0 ? odo : null,
      cost: (_num(j['cost']) ?? 0).clamp(0, double.infinity).toDouble(),
      note: _str(j['note']),
    );
  }
}

/// 정비 알림: 마지막으로 한 뒤 [everyMiles] 마일 또는 [everyMonths] 달 (먼저 오는 쪽).
/// "마지막으로 한 때"는 같은 종류의 정비 기록이 있으면 그것, 없으면 알림을 만들 때 적은 [lastOdometer]/[lastDate].
class Reminder {
  Reminder({
    required this.id,
    required this.vehicleId,
    required this.kind,
    this.everyMiles,
    this.everyMonths,
    this.lastOdometer,
    this.lastDate,
    this.notify = true,
  });

  final String id;
  String vehicleId;
  String kind;
  double? everyMiles;
  int? everyMonths;
  double? lastOdometer;
  DateTime? lastDate;
  bool notify;

  Map<String, Object> toJson() => {
    'id': id,
    'vehicle': vehicleId,
    'kind': kind,
    'everyMi': ?everyMiles,
    'everyMo': ?everyMonths,
    'lastOdo': ?lastOdometer,
    if (lastDate != null) 'lastDate': _iso(lastDate!),
    'notify': notify,
  };

  static Reminder? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], v = j['vehicle'];
    final kind = _str(j['kind']).trim();
    if (id is! String || v is! String || kind.isEmpty) return null;
    final mi = _num(j['everyMi']);
    final mo = j['everyMo'];
    final r = Reminder(
      id: id,
      vehicleId: v,
      kind: kind,
      everyMiles: mi != null && mi > 0 ? mi : null,
      everyMonths: mo is int && mo > 0 ? mo : null,
      lastOdometer: _num(j['lastOdo']),
      lastDate: _date(j['lastDate']),
      notify: j['notify'] != false,
    );
    return r.everyMiles == null && r.everyMonths == null ? null : r;
  }
}

/// 저장 파일 전체.
class LogData {
  LogData({
    List<Vehicle>? vehicles,
    List<FillUp>? fills,
    List<Service>? services,
    List<Reminder>? reminders,
    this.units = Units.us,
    this.currentVehicleId,
  }) : vehicles = vehicles ?? [],
       fills = fills ?? [],
       services = services ?? [],
       reminders = reminders ?? [];

  final List<Vehicle> vehicles;
  final List<FillUp> fills;
  final List<Service> services;
  final List<Reminder> reminders;
  Units units;
  String? currentVehicleId;

  static const version = 1;

  Map<String, Object?> toJson() => {
    'v': version,
    'units': units.toJson(),
    'current': currentVehicleId,
    'vehicles': [for (final v in vehicles) v.toJson()],
    'fills': [for (final f in fills) f.toJson()],
    'services': [for (final s in services) s.toJson()],
    'reminders': [for (final r in reminders) r.toJson()],
  };

  /// 깨진 항목은 버리고 나머지는 살린다. 차량이 없는 기록도 버린다.
  static LogData fromJson(Object? j) {
    if (j is! Map) return LogData();
    List<T> list<T>(String k, T? Function(Object?) f) => [
      if (j[k] is List)
        for (final e in j[k] as List)
          if (f(e) case final T x) x,
    ];
    final vehicles = list('vehicles', Vehicle.fromJson);
    final ids = {for (final v in vehicles) v.id};
    final cur = j['current'];
    return LogData(
      vehicles: vehicles,
      fills: list('fills', FillUp.fromJson).where((e) => ids.contains(e.vehicleId)).toList(),
      services: list('services', Service.fromJson).where((e) => ids.contains(e.vehicleId)).toList(),
      reminders: list('reminders', Reminder.fromJson).where((e) => ids.contains(e.vehicleId)).toList(),
      units: Units.fromJson(j['units']),
      currentVehicleId: cur is String && ids.contains(cur) ? cur : (vehicles.isEmpty ? null : vehicles.first.id),
    );
  }
}

/// 정비 종류 — 고르기 쉽게 자주 쓰는 것. 알림 기본 주기는 흔한 권장값일 뿐이라 화면에 "설명서 확인" 을 같이 띄운다.
class ServiceKind {
  const ServiceKind(this.name, this.icon, {this.miles, this.km, this.months});
  final String name;

  /// Material 아이콘 코드 이름 (화면에서 매핑)
  final String icon;
  final double? miles, km;
  final int? months;

  bool get remindable => miles != null || months != null;
}

const serviceKinds = [
  ServiceKind('Oil change', 'oil', miles: 5000, km: 8000, months: 6),
  ServiceKind('Tire rotation', 'tire', miles: 6000, km: 10000, months: 6),
  ServiceKind('Tires', 'tire'),
  ServiceKind('Brakes', 'brake', miles: 12000, km: 20000, months: 12),
  ServiceKind('Air filter', 'filter', miles: 15000, km: 25000, months: 12),
  ServiceKind('Cabin filter', 'filter', miles: 15000, km: 25000, months: 12),
  ServiceKind('Battery', 'battery', months: 12),
  ServiceKind('Wipers', 'wiper', months: 12),
  ServiceKind('Coolant', 'coolant', miles: 30000, km: 50000, months: 24),
  ServiceKind('Inspection', 'check', months: 12),
  ServiceKind('Registration', 'doc', months: 12),
  ServiceKind('Insurance', 'shield'),
  ServiceKind('Car wash', 'wash'),
  ServiceKind('Parking', 'parking'),
  ServiceKind('Tolls', 'toll'),
  ServiceKind('Repair', 'repair'),
];

ServiceKind? presetKind(String name) {
  final n = name.trim().toLowerCase();
  for (final k in serviceKinds) {
    if (k.name.toLowerCase() == n) return k;
  }
  return null;
}

bool sameKind(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();
