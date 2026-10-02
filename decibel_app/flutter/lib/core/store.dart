import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history.dart';
import 'meter.dart';

/// 기기에 남는 설정·기록. 서버 없음 — 오프라인에서 그대로 동작한다.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore i = AppStore._();

  late SharedPreferences _p;
  List<NoiseRecord> _records = [];

  /// 테스트에서 시각을 고정할 수 있게 시계를 바꿔 끼운다.
  DateTime Function() clock = DateTime.now;

  /// 기록은 최근 이만큼만 둔다 (오래된 것부터 지운다).
  static const maxRecords = 100;

  /// 아이폰 내장 마이크를 measurement 모드로 받을 때 dBFS(RMS) → dB SPL 기본 보정.
  /// 공개 자료 추정치 +92~94 (기종별 표, 20 µPa 기준 계산). 실기기에서 NIOSH SLM 과 나란히 재서 확인할 것.
  static const defaultOffset = 94.0;

  /// 사용자가 더하거나 빼는 보정 (±).
  static const trimRange = 20.0;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    _records = decodeRecords(_p.getString('records'));
    _records.sort((a, b) => b.id.compareTo(a.id));
  }

  // ── 처음 실행 ──
  bool get seenIntro => _p.getBool('seenIntro') ?? false;
  Future<void> setSeenIntro() async {
    await _p.setBool('seenIntro', true);
    notifyListeners();
  }

  // ── 설정 ──
  /// 사용자 보정 (기본값에 더하는 값, dB).
  double get trim => _p.getDouble('trim') ?? 0;
  Future<void> setTrim(double v) async {
    final t = (v.clamp(-trimRange, trimRange) * 2).round() / 2;
    await _p.setDouble('trim', t);
    notifyListeners();
  }

  double get offset => defaultOffset + trim;

  Weighting get weighting =>
      Weighting.values.asNameMap()[_p.getString('weighting')] ?? Weighting.a;
  Future<void> setWeighting(Weighting w) async {
    await _p.setString('weighting', w.name);
    notifyListeners();
  }

  bool get keepAwake => _p.getBool('keepAwake') ?? true;
  Future<void> setKeepAwake(bool v) async {
    await _p.setBool('keepAwake', v);
    notifyListeners();
  }

  // ── 기록 ──
  List<NoiseRecord> get records => List.unmodifiable(_records);

  NoiseRecord? recordById(int id) {
    for (final r in _records) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// 같은 id 면 덮어쓴다 (측정 중 10초마다 갱신).
  Future<void> saveRecord(NoiseRecord r) async {
    final old = recordById(r.id);
    if (old != null && r.note.isEmpty) r.note = old.note;
    _records.removeWhere((x) => x.id == r.id);
    _records.insert(0, r);
    _records.sort((a, b) => b.id.compareTo(a.id));
    if (_records.length > maxRecords) {
      _records = _records.sublist(0, maxRecords);
    }
    await _flush();
  }

  Future<void> setNote(int id, String note) async {
    final r = recordById(id);
    if (r == null || r.note == note) return;
    r.note = note;
    await _flush();
  }

  Future<void> deleteRecord(int id) async {
    _records.removeWhere((x) => x.id == id);
    await _flush();
  }

  Future<void> _flush() async {
    await _p.setString('records', encodeRecords(_records));
    notifyListeners();
  }
}
