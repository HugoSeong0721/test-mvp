import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'engine.dart';
import 'location.dart';
import 'units.dart';

LocationSource createPlatformSource() => WebLocationSource();

/// 웹 미리보기 — 브라우저 위치 API 를 직접 쓴다. (geolocator 웹판은 속도가 없을 때 0 을 넣어
/// "서 있음"과 "모름"을 구분할 수 없어서 쓰지 않는다.)
class WebLocationSource extends LocationSource {
  web.Geolocation get _geo => web.window.navigator.geolocation;

  @override
  bool get canOpenSettings => false;

  @override
  Future<Access> check() async {
    try {
      final desc = {'name': 'geolocation'}.jsify() as JSObject;
      final st = await web.window.navigator.permissions.query(desc).toDart;
      return switch (st.state) {
        'granted' => Access.granted,
        'denied' => Access.blocked,
        _ => Access.unknown,
      };
    } catch (_) {
      return Access.unknown;
    }
  }

  @override
  Future<Access> request() {
    final done = Completer<Access>();
    _geo.getCurrentPosition(
      ((web.GeolocationPosition _) {
        if (!done.isCompleted) done.complete(Access.granted);
      }).toJS,
      ((web.GeolocationPositionError e) {
        // 1 = 거절. 2·3(신호 없음·시간 초과)은 허락은 된 것 — 화면에서 "Searching" 으로 기다린다.
        if (!done.isCompleted) {
          done.complete(e.code == 1 ? Access.blocked : Access.granted);
        }
      }).toJS,
      web.PositionOptions(
        enableHighAccuracy: true,
        timeout: 15000,
        maximumAge: 0,
      ),
    );
    return done.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => Access.granted,
    );
  }

  @override
  Stream<Fix> watch(Mode mode) {
    int? id;
    late final StreamController<Fix> c;
    c = StreamController<Fix>(
      onListen: () {
        id = _geo.watchPosition(
          ((web.GeolocationPosition p) {
            final k = p.coords;
            c.add(
              Fix(
                lat: k.latitude,
                lon: k.longitude,
                accuracy: k.accuracy,
                speed: k.speed,
                time: DateTime.fromMillisecondsSinceEpoch(p.timestamp),
              ),
            );
          }).toJS,
          ((web.GeolocationPositionError e) {
            if (e.code == 1) c.addError(StateError('blocked'));
          }).toJS,
          web.PositionOptions(
            enableHighAccuracy: true,
            maximumAge: 0,
            timeout: 30000,
          ),
        );
      },
      onCancel: () {
        final i = id;
        if (i != null) _geo.clearWatch(i);
      },
    );
    return c.stream;
  }

  @override
  Future<void> openSettings() async {}
}
