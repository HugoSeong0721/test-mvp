/// CSV 내보내기·가져오기. 데이터는 사용자 것 — 언제든 꺼내고, 다른 앱(Fuelly 등)에서 꺼낸 파일도 머리글 이름으로 맞춰 읽는다.
library;

import 'dart:math' as math;

import 'calc.dart';
import 'model.dart';
import 'units.dart';

// ───────────────────────── 쓰기 ─────────────────────────

String _cell(String s) => s.contains(RegExp('[",\n\r]')) ? '"${s.replaceAll('"', '""')}"' : s;

String _n(double v, int decimals) {
  var s = v.toStringAsFixed(decimals);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s == '-0' ? '0' : s;
}

String _two(int v) => v.toString().padLeft(2, '0');
String csvDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

String exportFileName(DateTime now) => 'fuel-log-${now.year}-${_two(now.month)}-${_two(now.day)}.csv';

/// 모든 차량의 주유·정비·알림을 한 파일로. 단위는 머리글에 적는다 → 다시 가져올 때 그대로 읽힌다.
String exportCsv(LogData d) {
  final u = d.units;
  final dist = u.distance, vol = u.volume;
  final rows = <List<String>>[
    [
      'Vehicle',
      'Type',
      'Date',
      'Odometer (${dist.short})',
      'Fuel (${vol.short})',
      'Price (/${vol.short})',
      'Total cost',
      'Full tank',
      'Missed fill-up',
      'Service',
      'Every (${dist.short})',
      'Every (months)',
      'Notify',
      'Note',
    ],
  ];
  String yn(bool b) => b ? 'Yes' : 'No';
  for (final v in d.vehicles) {
    final fills = d.fills.where((f) => f.vehicleId == v.id).toList()..sort((a, b) => a.date.compareTo(b.date));
    for (final f in fills) {
      rows.add([
        v.name,
        'Fuel',
        csvDate(f.date),
        _n(dist.fromMiles(f.odometer), 1),
        _n(vol.fromGallons(f.volume), 3),
        _n(f.volume > 0 ? f.cost / vol.fromGallons(f.volume) : 0, 3),
        _n(f.cost, 2),
        yn(f.full),
        yn(f.missed),
        '',
        '',
        '',
        '',
        f.note,
      ]);
    }
    final services = d.services.where((s) => s.vehicleId == v.id).toList()..sort((a, b) => a.date.compareTo(b.date));
    for (final s in services) {
      rows.add([
        v.name,
        'Service',
        csvDate(s.date),
        s.odometer == null ? '' : _n(dist.fromMiles(s.odometer!), 1),
        '',
        '',
        _n(s.cost, 2),
        '',
        '',
        s.kind,
        '',
        '',
        '',
        s.note,
      ]);
    }
    for (final r in d.reminders.where((r) => r.vehicleId == v.id)) {
      rows.add([
        v.name,
        'Reminder',
        r.lastDate == null ? '' : csvDate(r.lastDate!),
        r.lastOdometer == null ? '' : _n(dist.fromMiles(r.lastOdometer!), 1),
        '',
        '',
        '',
        '',
        '',
        r.kind,
        r.everyMiles == null ? '' : _n(dist.fromMiles(r.everyMiles!), 0),
        r.everyMonths?.toString() ?? '',
        yn(r.notify),
        '',
      ]);
    }
  }
  return '${rows.map((r) => r.map(_cell).join(',')).join('\r\n')}\r\n';
}

// ───────────────────────── 읽기 ─────────────────────────

/// RFC 4180 CSV (따옴표 안 쉼표·줄바꿈·"" 이스케이프). [delimiter] 는 , ; 탭 중 하나.
List<List<String>> parseCsv(String text, {String? delimiter}) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final d = delimiter ?? _guessDelimiter(text);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == d) {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
}

String _guessDelimiter(String text) {
  final nl = text.indexOf(RegExp('[\r\n]'));
  final head = nl < 0 ? text : text.substring(0, nl);
  int count(String ch) => ch.allMatches(head).length;
  final best = [',', ';', '\t'].reduce((a, b) => count(b) > count(a) ? b : a);
  return count(best) == 0 ? ',' : best;
}

enum _Col {
  vehicle,
  type,
  date,
  time,
  odometer,
  trip,
  volume,
  price,
  total,
  full,
  partial,
  missed,
  service,
  everyDistance,
  everyMonths,
  notify,
  note,
}

String _key(String h) => h.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), ' ').trim();

/// 머리글 이름 → 열. 단위 표시(괄호)는 떼고 맞춘다.
_Col? _colFor(String header) {
  final k = _key(header.replaceAll(RegExp(r'\(.*?\)'), ''));
  final full = _key(header);
  if (full.startsWith('every') && (full.contains('month'))) return _Col.everyMonths;
  if (full.startsWith('every') || full == 'interval') return _Col.everyDistance;
  const map = {
    _Col.vehicle: ['vehicle', 'car', 'car name', 'vehicle name', 'name', 'car_name'],
    _Col.type: ['type', 'record type', 'entry type', 'record'],
    _Col.date: ['date', 'fuelup date', 'fill date', 'fillup date', 'date time', 'datetime', 'when', 'refuel date'],
    _Col.time: ['time', 'fuelup time', 'fill time'],
    _Col.odometer: ['odometer', 'odo', 'mileage', 'odometer reading', 'odometer mi', 'odometer km'],
    _Col.trip: ['miles', 'trip', 'distance', 'trip distance', 'trip miles', 'km', 'kilometers', 'trip km'],
    _Col.volume: [
      'fuel',
      'volume',
      'gallons',
      'liters',
      'litres',
      'quantity',
      'fuel amount',
      'amount of fuel',
      'gal',
      'l',
      'fuel volume',
    ],
    _Col.price: [
      'price',
      'price per unit',
      'unit price',
      'price per gallon',
      'price gal',
      'price per liter',
      'price per litre',
      'price l',
      'cost per gallon',
      'fuel price',
    ],
    _Col.total: ['total', 'total cost', 'cost', 'total price', 'amount', 'paid', 'total amount', 'total spent'],
    _Col.full: [
      'full',
      'full tank',
      'filled',
      'filled up',
      'fill',
      'fill type',
      'fill to full',
      'is full',
      'full fillup',
      'full fill up',
      'tank',
    ],
    _Col.partial: ['partial', 'partial fuelup', 'partial fill', 'partial fillup', 'partial fill up', 'is partial'],
    _Col.missed: ['missed', 'missed fuelup', 'missed fill up', 'missed fillup', 'missed fill', 'skipped'],
    _Col.service: ['service', 'services', 'service type', 'kind', 'category', 'maintenance', 'expense type'],
    _Col.notify: ['notify', 'notification', 'alert'],
    _Col.note: ['note', 'notes', 'comment', 'comments', 'memo', 'description'],
  };
  for (final e in map.entries) {
    if (e.value.contains(k)) return e.key;
  }
  return null;
}

DistanceUnit? _distUnitIn(String h) {
  final k = ' ${_key(h)} ';
  if (k.contains(' km ') || k.contains('kilomet')) return DistanceUnit.km;
  if (k.contains(' mi ') || k.contains('mile')) return DistanceUnit.mi;
  return null;
}

VolumeUnit? _volUnitIn(String h) {
  final k = ' ${_key(h)} ';
  if (k.contains(' l ') || k.contains('liter') || k.contains('litre')) return VolumeUnit.l;
  if (k.contains(' gal ') || k.contains('gallon')) return VolumeUnit.gal;
  return null;
}

/// "가득" 열: Fuelly 앱은 Full / Partial 로 적는다.
bool? _fullFlag(String s) {
  final k = s.trim().toLowerCase();
  if (k.contains('partial')) return false;
  if (k.contains('full')) return true;
  return _bool(s);
}

bool? _bool(String s) {
  final k = s.trim().toLowerCase();
  if (k.isEmpty) return null;
  if (['yes', 'y', 'true', '1', 'x', '✓', 'partial', 'missed'].contains(k)) return true;
  if (['no', 'n', 'false', '0', '-'].contains(k)) return false;
  return null;
}

double? _numOf(String s, {bool decimalComma = false}) {
  var t = s.trim().replaceAll(RegExp(r'[^0-9.,\-]'), '');
  if (t.isEmpty) return null;
  if (decimalComma) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else {
    t = t.replaceAll(',', '');
  }
  final v = double.tryParse(t);
  return v != null && v.isFinite ? v : null;
}

/// 2026-10-02 · 2026-10-02 09:15 · 2026-10-02T09:15:00 · 10/02/2026 · 10/2/26 9:15 PM · 2026/10/02 · 02.10.2026
DateTime? parseCsvDate(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  var m = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp][Mm])?)?')
      .firstMatch(t);
  int? y, mo, d;
  if (m != null) {
    y = int.parse(m[1]!);
    mo = int.parse(m[2]!);
    d = int.parse(m[3]!);
  } else {
    m = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})(?:[ T,]+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp][Mm])?)?')
        .firstMatch(t);
    if (m == null) return null;
    var a = int.parse(m[1]!), b = int.parse(m[2]!);
    y = int.parse(m[3]!);
    if (y < 100) y += 2000;
    // 미국식(월/일)이 기본. 앞 숫자가 12보다 크거나 점(.)으로 쓰면 일/월.
    final dayFirst = a > 12 || t.contains('.');
    if (dayFirst) (a, b) = (b, a);
    mo = a;
    d = b;
  }
  var h = m[4] == null ? 12 : int.parse(m[4]!);
  final min = m[5] == null ? 0 : int.parse(m[5]!);
  final ap = m[7]?.toLowerCase();
  if (ap == 'pm' && h < 12) h += 12;
  if (ap == 'am' && h == 12) h = 0;
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || y < 1900 || y > 2200 || h > 23) return null;
  final out = DateTime(y, mo, d, h, min);
  return out.month == mo ? out : null; // 2/30 같은 날짜 거르기
}

class ImportProblem {
  const ImportProblem(this.line, this.reason);
  final int line;
  final String reason;
}

/// 가져오기 전에 보여 줄 계획. [apply] 하기 전엔 데이터를 건드리지 않는다.
class ImportPlan {
  final newVehicles = <Vehicle>[];
  final fills = <FillUp>[];
  final services = <Service>[];
  final reminders = <Reminder>[];
  final problems = <ImportProblem>[];
  int duplicates = 0;
  DistanceUnit distanceUnit = DistanceUnit.mi;
  VolumeUnit volumeUnit = VolumeUnit.gal;
  bool unitsGuessed = false;

  int get total => fills.length + services.length + reminders.length;
  bool get isEmpty => total == 0;

  void apply(LogData d) {
    d.vehicles.addAll(newVehicles);
    d.fills.addAll(fills);
    d.services.addAll(services);
    d.reminders.addAll(reminders);
    d.currentVehicleId ??= d.vehicles.isEmpty ? null : d.vehicles.first.id;
  }
}

/// [into] 는 지금 데이터 (차량 이름 맞추기·중복 거르기용, 바뀌지 않는다).
/// 차량 열이 없는 파일은 [defaultVehicleId] 차량으로 넣는다.
/// [distanceUnit]/[volumeUnit] 를 주면 머리글보다 그걸 따른다 (단위가 안 적힌 파일에서 사용자가 고른 값).
ImportPlan planImport(
  String text,
  LogData into, {
  String? defaultVehicleId,
  DistanceUnit? distanceUnit,
  VolumeUnit? volumeUnit,
}) {
  final plan = ImportPlan();
  final delim = _guessDelimiter(text.startsWith('﻿') ? text.substring(1) : text);
  final rows = parseCsv(text, delimiter: delim);
  if (rows.isEmpty) {
    plan.problems.add(const ImportProblem(1, 'The file is empty.'));
    return plan;
  }
  final header = rows.first;
  final cols = <_Col, int>{};
  DistanceUnit? dist;
  VolumeUnit? vol;
  for (var i = 0; i < header.length; i++) {
    final c = _colFor(header[i]);
    if (c == null || cols.containsKey(c)) continue;
    cols[c] = i;
    if (c == _Col.odometer || c == _Col.trip || c == _Col.everyDistance) {
      dist ??= _distUnitIn(header[i]);
    }
    if (c == _Col.volume || c == _Col.price) vol ??= _volUnitIn(header[i]);
  }
  if (!cols.containsKey(_Col.date) ||
      !(cols.containsKey(_Col.odometer) || cols.containsKey(_Col.trip) || cols.containsKey(_Col.service))) {
    plan.problems.add(
      const ImportProblem(1, "Couldn't find Date and Odometer columns. The first row must be column names."),
    );
    return plan;
  }
  plan.unitsGuessed = dist == null || vol == null;
  plan.distanceUnit = distanceUnit ?? dist ?? into.units.distance;
  plan.volumeUnit = volumeUnit ?? vol ?? into.units.volume;
  final decimalComma = delim == ';';

  String at(List<String> r, _Col c) {
    final i = cols[c];
    return i == null || i >= r.length ? '' : r[i].trim();
  }

  double? num(List<String> r, _Col c) => _numOf(at(r, c), decimalComma: decimalComma);

  // 차량 이름 → id (있는 차 + 새로 만들 차)
  final byName = {for (final v in into.vehicles) v.name.trim().toLowerCase(): v.id};
  String vehicleFor(String name) {
    final n = name.trim();
    if (n.isEmpty) {
      if (defaultVehicleId != null) return defaultVehicleId;
      if (into.vehicles.isNotEmpty) return into.vehicles.first.id;
      return vehicleFor('My Car');
    }
    return byName.putIfAbsent(n.toLowerCase(), () {
      final v = Vehicle(id: newId(), name: n);
      plan.newVehicles.add(v);
      return v.id;
    });
  }

  // 주행거리 없이 구간 거리만 있는 파일: 차량마다 날짜 순으로 쌓는다
  final tripRows = <String, List<(int, List<String>, DateTime)>>{};
  final existingFills = [...into.fills];
  final existingServices = [...into.services];

  for (var li = 1; li < rows.length; li++) {
    final r = rows[li];
    final line = li + 1;
    final time = at(r, _Col.time);
    final date = parseCsvDate(
      time.isEmpty ? at(r, _Col.date) : '${at(r, _Col.date).split(RegExp('[ T]')).first} $time',
    );
    final typeText = at(r, _Col.type).toLowerCase();
    final vol0 = num(r, _Col.volume);
    final kindText = at(r, _Col.service);
    final type = typeText.startsWith('rem')
        ? 'reminder'
        : (typeText.startsWith('serv') ||
              typeText.startsWith('maint') ||
              typeText.startsWith('exp') ||
              typeText.startsWith('repair'))
        ? 'service'
        : (typeText.startsWith('fuel') ||
              typeText.startsWith('fill') ||
              typeText.startsWith('gas') ||
              typeText.startsWith('refuel'))
        ? 'fuel'
        : (vol0 != null && vol0 > 0)
        ? 'fuel'
        : kindText.isNotEmpty
        ? 'service'
        : 'fuel';
    final vid = vehicleFor(at(r, _Col.vehicle));
    final odoRaw = num(r, _Col.odometer);
    final odo = odoRaw == null ? null : plan.distanceUnit.toMiles(odoRaw);
    final note = at(r, _Col.note);

    if (type == 'reminder') {
      final everyD = num(r, _Col.everyDistance);
      final everyM = num(r, _Col.everyMonths)?.round();
      if (kindText.isEmpty || ((everyD == null || everyD <= 0) && (everyM == null || everyM <= 0))) {
        plan.problems.add(ImportProblem(line, 'Reminder needs a service name and an interval.'));
        continue;
      }
      final dup = [...into.reminders, ...plan.reminders].any((e) => e.vehicleId == vid && sameKind(e.kind, kindText));
      if (dup) {
        plan.duplicates++;
        continue;
      }
      plan.reminders.add(
        Reminder(
          id: newId(),
          vehicleId: vid,
          kind: kindText,
          everyMiles: everyD != null && everyD > 0 ? plan.distanceUnit.toMiles(everyD) : null,
          everyMonths: everyM != null && everyM > 0 ? everyM : null,
          lastDate: date,
          lastOdometer: odo,
          notify: _bool(at(r, _Col.notify)) ?? true,
        ),
      );
      continue;
    }

    if (date == null) {
      plan.problems.add(ImportProblem(line, 'Unreadable date "${at(r, _Col.date)}".'));
      continue;
    }

    if (type == 'service') {
      final kind = kindText.isEmpty ? 'Other' : kindText;
      final cost = math.max(0.0, num(r, _Col.total) ?? 0);
      final dup = [...existingServices, ...plan.services].any(
        (e) =>
            e.vehicleId == vid &&
            dayOf(e.date) == dayOf(date) &&
            sameKind(e.kind, kind) &&
            (e.cost - cost).abs() < 0.005,
      );
      if (dup) {
        plan.duplicates++;
        continue;
      }
      plan.services.add(
        Service(
          id: newId(),
          vehicleId: vid,
          date: date,
          kind: kind,
          odometer: odo != null && odo >= 0 ? odo : null,
          cost: cost,
          note: note,
        ),
      );
      continue;
    }

    // 주유: 양·단가·총액 중 둘이면 나머지를 채운다
    var volume = vol0;
    final price = num(r, _Col.price);
    var total = num(r, _Col.total);
    if ((volume == null || volume <= 0) && price != null && price > 0 && total != null) {
      volume = total / price;
    }
    if (total == null && volume != null && price != null) total = volume * price;
    if (volume == null || volume <= 0) {
      plan.problems.add(ImportProblem(line, 'Missing fuel amount.'));
      continue;
    }
    final partial = _bool(at(r, _Col.partial));
    final fullCol = _fullFlag(at(r, _Col.full));
    final full = partial != null ? !partial : (fullCol ?? true);
    final missed = _bool(at(r, _Col.missed)) ?? false;
    final f = FillUp(
      id: newId(),
      vehicleId: vid,
      date: date,
      odometer: odo ?? -1,
      volume: plan.volumeUnit.toGallons(volume),
      cost: math.max(0, total ?? 0),
      full: full,
      missed: missed,
      note: note,
    );
    if (odo == null) {
      final trip = num(r, _Col.trip);
      if (trip == null || trip < 0) {
        plan.problems.add(ImportProblem(line, 'Missing odometer.'));
        continue;
      }
      f.odometer = plan.distanceUnit.toMiles(trip); // 아래에서 누적으로 바꾼다
      tripRows.putIfAbsent(vid, () => []).add((line, r, date));
      plan.fills.add(f);
      continue;
    }
    if (_isDupFill(f, [...existingFills, ...plan.fills])) {
      plan.duplicates++;
      continue;
    }
    plan.fills.add(f);
  }

  // 구간 거리 → 누적 주행거리 (그 차의 기존 마지막 주행거리부터, 없으면 0 부터)
  if (tripRows.isNotEmpty) {
    for (final vid in tripRows.keys) {
      final mine = plan.fills.where((f) => f.vehicleId == vid).toList()..sort((a, b) => a.date.compareTo(b.date));
      final hasOdo = cols.containsKey(_Col.odometer);
      final existing = into.fills.where((f) => f.vehicleId == vid).map((f) => f.odometer);
      var odo = existing.isEmpty ? 0.0 : existing.reduce(math.max);
      for (final f in mine) {
        final isTrip = tripRows[vid]!.any((t) => t.$3 == f.date) && (!hasOdo || f.odometer >= 0);
        if (!isTrip) {
          odo = math.max(odo, f.odometer);
          continue;
        }
        odo += f.odometer;
        f.odometer = odo;
      }
    }
    final keep = <FillUp>[];
    for (final f in plan.fills) {
      if (_isDupFill(f, [...existingFills, ...keep])) {
        plan.duplicates++;
      } else {
        keep.add(f);
      }
    }
    plan.fills
      ..clear()
      ..addAll(keep);
  }
  return plan;
}

bool _isDupFill(FillUp f, List<FillUp> others) => others.any(
  (e) =>
      e.vehicleId == f.vehicleId &&
      dayOf(e.date) == dayOf(f.date) &&
      (e.odometer - f.odometer).abs() < 0.5 &&
      (e.volume - f.volume).abs() < 0.01,
);
