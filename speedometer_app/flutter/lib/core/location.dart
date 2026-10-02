import 'dart:async';
import 'dart:math' as math;

import 'engine.dart';
import 'units.dart';

/// 위치 권한 상태.
enum Access {
  /// 앱을 막 켜서 확인 중 (화면에 권한 안내를 깜빡 띄우지 않으려고 따로 둔다).
  checking,

  /// 아직 안 물어봤다 — "Allow Location" 버튼을 보여 준다.
  unknown,

  /// 한 번 거절 (다시 물어볼 수 있음, 안드로이드).
  denied,

  /// 막혀 있다 — 설정 앱에서 켜야 한다.
  blocked,

  /// 기기 위치 서비스 자체가 꺼져 있다.
  servicesOff,
  granted,
}

/// 위치를 주는 곳. 아이폰(geolocator)·웹(사파리 위치 API)·가짜(테스트·데모)를 갈아끼운다.
abstract class LocationSource {
  /// 묻지 않고 지금 상태만.
  Future<Access> check();

  /// 시스템 권한 창을 띄운다.
  Future<Access> request();

  /// 정확한 위치가 꺼져 있나 (iOS "Precise Location" 끔 → 속도를 못 잰다).
  Future<bool> preciseOff() async => false;

  Stream<Fix> watch(Mode mode);

  Future<void> openSettings();

  /// 설정 앱을 열 수 있나 (웹은 못 연다 → 안내 문구만).
  bool get canOpenSettings => true;

  /// 화면에 "DEMO" 를 띄워야 하는 가짜 주행인가.
  bool get isDemo => false;
}

/// 테스트용 — 측정값을 손으로 넣는다.
class FakeLocationSource extends LocationSource {
  FakeLocationSource({this.access = Access.granted, this.afterRequest});
  Access access;

  /// 권한 창에서 사용자가 고를 답. null 이면 granted.
  Access? afterRequest;
  bool precise = true;
  int requests = 0;
  int settingsOpened = 0;
  final List<Mode> watchedModes = [];
  StreamController<Fix>? _c;

  bool get listening => _c != null && _c!.hasListener;

  @override
  Future<Access> check() async => access;

  @override
  Future<Access> request() async {
    requests++;
    access = afterRequest ?? Access.granted;
    return access;
  }

  @override
  Future<bool> preciseOff() async => !precise;

  @override
  Stream<Fix> watch(Mode mode) {
    watchedModes.add(mode);
    _c?.close();
    final c = StreamController<Fix>();
    c.onCancel = () {
      if (identical(_c, c)) _c = null;
    };
    _c = c;
    return c.stream;
  }

  void emit(Fix f) => _c?.add(f);
  void fail(Object e) => _c?.addError(e);

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// 웹 미리보기 `?demo=1` — 책상에서도 화면을 볼 수 있게 가짜 주행을 돌린다.
/// 화면에 항상 "DEMO" 가 붙는다 (가짜 숫자를 진짜처럼 보이지 않게). 앱 빌드에는 쓰지 않는다.
class DemoDriveSource extends LocationSource {
  Timer? _t;

  @override
  bool get isDemo => true;

  @override
  bool get canOpenSettings => false;

  @override
  Future<Access> check() async => Access.granted;

  @override
  Future<Access> request() async => Access.granted;

  /// 차 기준 속도 곡선 (초 → mph). 출발 → 35 → 70 → 정지, 반복.
  static double carMph(double t) {
    final s = t % 90;
    if (s < 4) return 0;
    if (s < 14) return (s - 4) / 10 * 35;
    if (s < 30) return 35 + 2 * math.sin(s);
    if (s < 42) return 35 + (s - 30) / 12 * 35;
    if (s < 62) return 69 + 2 * math.sin(s / 2);
    if (s < 80) return 70 * (1 - (s - 62) / 18);
    return 0;
  }

  @override
  Stream<Fix> watch(Mode mode) {
    _t?.cancel();
    final scale = switch (mode) {
      Mode.car => 1.0,
      Mode.bike => 0.32,
      Mode.run => 0.12,
      Mode.boat => 0.45,
    };
    final c = StreamController<Fix>();
    var t = 0.0;
    var lat = 40.7128;
    c.onListen = () {
      _t = Timer.periodic(const Duration(seconds: 1), (_) {
        t += 1;
        final ms = SpeedUnit.mph.toMs(carMph(t) * scale);
        lat += ms / 111195.08;
        c.add(
          Fix(
            lat: lat,
            lon: -74.006,
            accuracy: 5,
            speed: ms,
            time: DateTime.now(),
          ),
        );
      });
    };
    c.onCancel = () => _t?.cancel();
    return c.stream;
  }

  @override
  Future<void> openSettings() async {}
}
