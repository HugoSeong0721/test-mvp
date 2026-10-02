import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'engine.dart';
import 'units.dart';

enum Display { digital, gauge }

/// 기기에 남는 설정·이동 기록. 서버 없음, 위치 기록은 저장하지 않는다(합계 숫자만).
class Prefs {
  Prefs(this._p);
  final SharedPreferences _p;

  static Future<Prefs> load() async =>
      Prefs(await SharedPreferences.getInstance());

  bool get seenSafety => _p.getBool('seenSafety') ?? false;
  set seenSafety(bool v) => _p.setBool('seenSafety', v);

  Mode get mode => Mode.values.asNameMap()[_p.getString('mode')] ?? Mode.car;
  set mode(Mode m) => _p.setString('mode', m.name);

  SpeedUnit unitFor(Mode m) {
    final u = SpeedUnit.values.asNameMap()[_p.getString('unit_${m.name}')];
    return u != null && m.units.contains(u) ? u : m.units.first;
  }

  void setUnit(Mode m, SpeedUnit u) => _p.setString('unit_${m.name}', u.name);

  Display get display =>
      Display.values.asNameMap()[_p.getString('display')] ?? Display.digital;
  set display(Display d) => _p.setString('display', d.name);

  bool alertOn(Mode m) => _p.getBool('alertOn_${m.name}') ?? false;
  void setAlertOn(Mode m, bool v) => _p.setBool('alertOn_${m.name}', v);

  /// 경고 속도 (m/s 로 저장 — 단위를 바꿔도 같은 속도를 가리킨다).
  double alertMs(Mode m) =>
      _p.getDouble('alertMs_${m.name}') ?? m.defaultAlertMs;
  void setAlertMs(Mode m, double v) => _p.setDouble('alertMs_${m.name}', v);

  bool get sound => _p.getBool('sound') ?? true;
  set sound(bool v) => _p.setBool('sound', v);

  bool get hudMirror => _p.getBool('hudMirror') ?? true;
  set hudMirror(bool v) => _p.setBool('hudMirror', v);

  Trip get trip {
    final raw = _p.getString('trip');
    if (raw == null) return Trip();
    try {
      return Trip.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return Trip();
    }
  }

  set trip(Trip t) => _p.setString('trip', jsonEncode(t.toJson()));
}
