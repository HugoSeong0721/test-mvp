import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'calc.dart';
import 'csv.dart';
import 'format.dart';
import 'model.dart';
import 'notify.dart';
import 'persist.dart';
import 'units.dart';

/// 기록 목록 한 줄 — 주유 또는 정비.
class Entry {
  Entry.fill(FillUp this.fill) : service = null;
  Entry.service(Service this.service) : fill = null;
  final FillUp? fill;
  final Service? service;
  DateTime get date => fill?.date ?? service!.date;
  String get id => fill?.id ?? service!.id;
}

/// 앱 전체 상태. 바뀔 때마다 파일에 저장하고 알림 예약을 다시 한다.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore i = AppStore._();

  Persist persist = Persist.create();

  /// 지금 시각 — 테스트에서 고정한다.
  DateTime Function() now = clock.now;

  LogData data = LogData();

  /// 본 파일이 깨져 직전 사본으로 살렸을 때 한 번 보여 줄 말.
  String? loadNotice;

  final Map<String, VehicleLog> _logs = {};
  Future<void> _saving = Future.value();

  Future<void> load() async {
    // 켤 때마다 저장 줄을 새로 시작 (테스트에서 앞 판의 끝나지 않은 저장을 기다리다 멈췄다)
    _saving = Future.value();
    _logs.clear();
    loadNotice = null;
    String? raw;
    try {
      raw = await persist.read();
    } catch (e) {
      debugPrint('read failed: $e');
    }
    data = _parse(raw) ?? LogData();
    if (raw != null && _parse(raw) == null) {
      final bak = _parse(await persist.readBackup().catchError((_) => null));
      if (bak != null) {
        data = bak;
        loadNotice = 'Your log was restored from the last good copy.';
      }
    }
    notifyListeners();
    _syncNotices();
  }

  LogData? _parse(String? raw) {
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw);
      return j is Map ? LogData.fromJson(j) : null;
    } catch (_) {
      return null;
    }
  }

  // ───────── 읽기 ─────────

  Units get units => data.units;
  Fmt get fmt => Fmt(data.units);
  List<Vehicle> get vehicles => data.vehicles;
  bool get hasVehicle => data.vehicles.isNotEmpty;

  Vehicle? get vehicle {
    for (final v in data.vehicles) {
      if (v.id == data.currentVehicleId) return v;
    }
    return data.vehicles.isEmpty ? null : data.vehicles.first;
  }

  VehicleLog logFor(String vehicleId) => _logs.putIfAbsent(
    vehicleId,
    () => VehicleLog(
      data.fills.where((f) => f.vehicleId == vehicleId),
      data.services.where((s) => s.vehicleId == vehicleId),
    ),
  );

  VehicleLog get log => vehicle == null ? VehicleLog([], []) : logFor(vehicle!.id);

  /// 지금 차의 기록, 최근 것이 위.
  List<Entry> get entries {
    final v = vehicle;
    if (v == null) return [];
    final out = [
      for (final f in data.fills)
        if (f.vehicleId == v.id) Entry.fill(f),
      for (final s in data.services)
        if (s.vehicleId == v.id) Entry.service(s),
    ];
    out.sort((a, b) {
      final c = b.date.compareTo(a.date);
      if (c != 0) return c;
      // 같은 시각이면 주행거리 큰 쪽이 위
      final ao = a.fill?.odometer ?? a.service?.odometer ?? 0;
      final bo = b.fill?.odometer ?? b.service?.odometer ?? 0;
      return bo.compareTo(ao);
    });
    return out;
  }

  List<Reminder> remindersOf(String vehicleId) => data.reminders.where((r) => r.vehicleId == vehicleId).toList();

  List<ReminderState> reminderStates(String vehicleId) {
    final log = logFor(vehicleId);
    final t = now();
    final out = [for (final r in remindersOf(vehicleId)) ReminderState.of(r, log, t)];
    int rank(ReminderLevel l) => switch (l) {
      ReminderLevel.overdue => 0,
      ReminderLevel.soon => 1,
      ReminderLevel.ok => 2,
      ReminderLevel.unknown => 3,
    };
    out.sort((a, b) {
      final c = rank(a.level).compareTo(rank(b.level));
      return c != 0 ? c : b.progress.compareTo(a.progress);
    });
    return out;
  }

  /// 지금 차의 지났거나 곧인 알림.
  List<ReminderState> get dueReminders => vehicle == null
      ? []
      : reminderStates(vehicle!.id)
            .where((s) => s.level == ReminderLevel.overdue || s.level == ReminderLevel.soon)
            .toList();

  /// [vehicleId] 차의 다른 주유 중, [date] 에 이 [odometer] 와 앞뒤가 안 맞는 것.
  FillUp? odometerConflict(String vehicleId, DateTime date, double odometer, {String? exceptId}) {
    for (final f in data.fills) {
      if (f.vehicleId != vehicleId || f.id == exceptId) continue;
      if ((f.odometer - odometer).abs() < 0.05) return f;
      // 같은 날 여러 번은 주행거리 순으로 본다
      if (dayOf(f.date) == dayOf(date)) continue;
      if (f.date.isBefore(date) && f.odometer > odometer) return f;
      if (f.date.isAfter(date) && f.odometer < odometer) return f;
    }
    return null;
  }

  /// [date] 전의 마지막 주유 (같은 날이면 그 전 것까지).
  FillUp? previousFill(String vehicleId, DateTime date, {String? exceptId}) {
    FillUp? best;
    for (final f in data.fills) {
      if (f.vehicleId != vehicleId || f.id == exceptId || f.date.isAfter(date)) continue;
      if (best == null || f.odometer > best.odometer) best = f;
    }
    return best;
  }

  /// 마지막 주유 단가 (로드트립 계산 기본값).
  double? get lastPricePerGallon {
    final fs = log.fills.where((f) => f.volume > 0).toList()..sort((a, b) => a.date.compareTo(b.date));
    return fs.isEmpty ? null : fs.last.pricePerGallon;
  }

  // ───────── 쓰기 ─────────

  Vehicle addVehicle(String name, {bool select = true}) {
    final n = name.trim();
    final v = Vehicle(id: newId(), name: n.isEmpty ? _defaultName() : n);
    data.vehicles.add(v);
    if (select || data.currentVehicleId == null) data.currentVehicleId = v.id;
    _commit();
    return v;
  }

  String _defaultName() {
    if (!data.vehicles.any((v) => v.name == 'My Car')) return 'My Car';
    var k = 2;
    while (data.vehicles.any((v) => v.name == 'Car $k')) {
      k++;
    }
    return 'Car $k';
  }

  void renameVehicle(String id, String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    for (final v in data.vehicles) {
      if (v.id == id) v.name = n;
    }
    _commit();
  }

  /// 차와 그 기록을 지운다. 되돌리기용으로 지운 것을 돌려준다.
  LogData deleteVehicle(String id) {
    final gone = LogData(
      vehicles: data.vehicles.where((v) => v.id == id).toList(),
      fills: data.fills.where((f) => f.vehicleId == id).toList(),
      services: data.services.where((s) => s.vehicleId == id).toList(),
      reminders: data.reminders.where((r) => r.vehicleId == id).toList(),
      currentVehicleId: data.currentVehicleId,
    );
    data.vehicles.removeWhere((v) => v.id == id);
    data.fills.removeWhere((f) => f.vehicleId == id);
    data.services.removeWhere((s) => s.vehicleId == id);
    data.reminders.removeWhere((r) => r.vehicleId == id);
    if (data.currentVehicleId == id) {
      data.currentVehicleId = data.vehicles.isEmpty ? null : data.vehicles.first.id;
    }
    _commit();
    return gone;
  }

  /// [deleteVehicle] 되돌리기.
  void restoreVehicle(LogData gone) {
    data.vehicles.addAll(gone.vehicles);
    data.fills.addAll(gone.fills);
    data.services.addAll(gone.services);
    data.reminders.addAll(gone.reminders);
    data.currentVehicleId = gone.currentVehicleId;
    _commit();
  }

  void selectVehicle(String id) {
    if (data.currentVehicleId == id) return;
    data.currentVehicleId = id;
    _commit();
  }

  void saveFill(FillUp f) {
    data.fills
      ..removeWhere((e) => e.id == f.id)
      ..add(f);
    _commit();
  }

  FillUp? deleteFill(String id) {
    final f = data.fills.where((e) => e.id == id).firstOrNull;
    data.fills.removeWhere((e) => e.id == id);
    _commit();
    return f;
  }

  void saveService(Service s) {
    data.services
      ..removeWhere((e) => e.id == s.id)
      ..add(s);
    _commit();
  }

  Service? deleteService(String id) {
    final s = data.services.where((e) => e.id == id).firstOrNull;
    data.services.removeWhere((e) => e.id == id);
    _commit();
    return s;
  }

  void saveReminder(Reminder r) {
    final i = data.reminders.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      data.reminders[i] = r;
    } else {
      data.reminders.add(r);
    }
    _commit();
  }

  Reminder? deleteReminder(String id) {
    final r = data.reminders.where((e) => e.id == id).firstOrNull;
    data.reminders.removeWhere((e) => e.id == id);
    _commit();
    return r;
  }

  /// 통째로 바꾸기 (웹 미리보기 예시 기록).
  void replaceAll(LogData d) {
    data = d;
    _commit();
  }

  void setUnits(Units u) {
    data.units = u;
    _commit();
  }

  void applyImport(ImportPlan plan) {
    plan.apply(data);
    _commit();
  }

  /// 날짜가 바뀌었을 수 있을 때 (앱 복귀) — 다시 그리고 알림 예약도 다시.
  void refresh() {
    _logs.clear();
    notifyListeners();
    _syncNotices();
  }

  /// 마지막 저장이 끝날 때까지 (테스트·앱 종료 전).
  Future<void> flush() => _saving;

  void _commit() {
    _logs.clear();
    notifyListeners();
    final text = jsonEncode(data.toJson());
    _saving = _saving.then((_) => persist.write(text)).catchError((Object e) {
      debugPrint('save failed: $e');
    });
    _syncNotices();
  }

  // ───────── 알림 예약 ─────────

  /// 앞으로 울릴 정비 알림 (가까운 순).
  List<PlannedNotice> plannedNotices() {
    final t = now();
    final out = <(DateTime, String, String)>[];
    final f = fmt;
    for (final v in data.vehicles) {
      for (final s in reminderStates(v.id)) {
        if (!s.reminder.notify) continue;
        final at = s.notifyAt;
        if (at == null || !at.isAfter(t)) continue;
        final parts = [
          if (s.dueOdometer != null) 'at ${f.dist(s.dueOdometer!)}',
          if (s.dueDate != null) 'by ${fmtDate(s.dueDate!)}',
        ];
        final estimated = s.estimatedDate != null && (s.dueDate == null || s.estimatedDate!.isBefore(s.dueDate!));
        final body = estimated
            ? 'Due ${parts.join(' or ')}. Based on your driving, that\'s about now.'
            : 'Due ${parts.join(' or ')}.';
        out.add((at, '${s.reminder.kind} due · ${v.name}', body));
      }
    }
    out.sort((a, b) => a.$1.compareTo(b.$1));
    return [
      for (var k = 0; k < out.length && k < maxNotices; k++) PlannedNotice(k + 1, out[k].$1, out[k].$2, out[k].$3),
    ];
  }

  void _syncNotices() {
    // 플랫폼 응답을 기다리지 않는다 — 저장·화면이 먼저 (PLAYBOOK: 소음 앱 교훈)
    unawaited(Notifier.i.sync(plannedNotices()).catchError((Object e) => debugPrint('$e')));
  }
}
