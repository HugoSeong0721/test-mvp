// 측정 엔진 시험 — 화면에 나올 숫자가 진짜인지(가짜·튄 값이 섞이지 않는지) 확인한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:speedometer/core/engine.dart';
import 'package:speedometer/core/units.dart';

const metersPerDegLat = 111195.08;

/// 북쪽으로 일정 속도로 달리는 가짜 주행. 1초에 한 번 측정.
class Drive {
  Drive({this.accuracy = 5});
  final double accuracy;
  final engine = SpeedEngine();
  final t0 = DateTime(2026, 10, 3, 8);
  double lat = 37.0;
  double secs = 0;

  DateTime get now => t0.add(Duration(milliseconds: (secs * 1000).round()));

  /// [ms] 속도로 [n] 초 달린다. [report] 가 false 면 GPS 가 속도를 안 준다(웹 사파리 일부).
  void run(double ms, int n, {bool report = true, double? acc, double? spike}) {
    for (var i = 0; i < n; i++) {
      secs += 1;
      lat += ms / metersPerDegLat;
      final f = Fix(
        lat: lat,
        lon: 127.0,
        accuracy: acc ?? accuracy,
        time: now,
        speed: report ? (spike ?? ms) : null,
      );
      engine.addFix(f, now);
      engine.tick(now);
    }
  }

  /// 측정 없이 [n] 초 (터널).
  void silence(int n) {
    for (var i = 0; i < n; i++) {
      secs += 1;
      engine.tick(now);
    }
  }
}

void main() {
  test('units: 60 mph = 96.56 km/h = 52.14 knots', () {
    final ms = SpeedUnit.mph.toMs(60);
    expect(ms, closeTo(26.8224, 1e-4));
    expect(formatSpeed(ms, SpeedUnit.kmh, 0), '97');
    expect(formatSpeed(ms, SpeedUnit.knots, 1), '52.1');
    expect(formatSpeed(null, SpeedUnit.mph, 0), '--');
  });

  test('pace: 7.5 mph = 8:00 /mi, standing = --:--', () {
    expect(formatPace(SpeedUnit.mph.toMs(7.5), SpeedUnit.mph), '8:00');
    expect(formatPace(SpeedUnit.kmh.toMs(12), SpeedUnit.kmh), '5:00');
    expect(formatPace(0, SpeedUnit.mph), '--:--');
    expect(formatPace(null, SpeedUnit.mph), '--:--');
  });

  test('format distance/duration', () {
    expect(formatDistance(1609.344 * 12.345, SpeedUnit.mph), '12.35');
    expect(formatDistance(1852 * 150, SpeedUnit.knots), '150.0');
    expect(formatDuration(const Duration(minutes: 24, seconds: 10)), '24:10');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  test('searching until first fix, then speed shows', () {
    final d = Drive();
    expect(d.engine.state, GpsState.searching);
    expect(d.engine.speed, isNull);
    d.run(20, 1);
    expect(d.engine.state, GpsState.strong);
    expect(d.engine.speed, 20);
  });

  test('distance, moving time, avg and max on a steady drive', () {
    final d = Drive();
    d.run(26.8224, 61); // 60 mph, 60초 구간
    final trip = d.engine.trip;
    expect(trip.distance, closeTo(26.8224 * 60, 1));
    expect(trip.moving.inSeconds, 60);
    expect(trip.avgMs, closeTo(26.8224, 0.01));
    expect(trip.maxMs, closeTo(26.8224, 0.01));
    expect(trip.elapsed.inSeconds, inInclusiveRange(58, 60));
  });

  test('standing still: jitter below ~1 mph shows 0 and adds no distance', () {
    final d = Drive();
    for (var i = 0; i < 30; i++) {
      d.secs += 1;
      final f = Fix(
        lat: 37 + (i.isEven ? 2 : -2) / metersPerDegLat,
        lon: 127,
        accuracy: 8,
        time: d.now,
        speed: i.isEven ? 0.3 : 0.1,
      );
      d.engine.addFix(f, d.now);
      d.engine.tick(d.now);
    }
    expect(d.engine.speed, 0);
    expect(d.engine.trip.distance, 0);
    expect(d.engine.trip.elapsed, Duration.zero, reason: '움직이기 전엔 시계가 안 돈다');
    expect(d.engine.trip.maxMs, 0);
  });

  test('a single spike does not become the max speed', () {
    final d = Drive();
    d.run(13.4, 10); // 30 mph
    d.run(13.4, 1, spike: 80); // 한 번 튄 값 (~180 mph)
    d.run(13.4, 10);
    expect(d.engine.trip.maxMs, closeTo(13.4, 0.01));
  });

  test('implausible speed (> 200 mph) is dropped', () {
    final d = Drive();
    d.run(13.4, 3);
    d.run(13.4, 1, spike: 150);
    expect(d.engine.speed, isNull);
  });

  test('weak accuracy: shown as weak, does not set max', () {
    final d = Drive();
    d.run(30, 10, acc: 60);
    expect(d.engine.state, GpsState.weak);
    expect(d.engine.speed, 30, reason: '숫자는 보여 주되 Weak 로 밝힌다');
    expect(d.engine.trip.maxMs, 0);
  });

  test('signal lost after 5 s shows -- (no fake number)', () {
    final d = Drive();
    d.run(20, 5);
    d.silence(6);
    expect(d.engine.state, GpsState.lost);
    expect(d.engine.speed, isNull);
  });

  test('tunnel: distance across a gap is counted once signal returns', () {
    final d = Drive();
    d.run(20, 5);
    final before = d.engine.trip.distance;
    // 30초 동안 측정 없이 20 m/s 로 이동
    for (var i = 0; i < 30; i++) {
      d.secs += 1;
      d.lat += 20 / metersPerDegLat;
      d.engine.tick(d.now);
    }
    d.run(20, 1);
    expect(d.engine.trip.distance - before, closeTo(20 * 31, 2));
  });

  test('no reported speed (web): speed is derived from positions', () {
    final d = Drive();
    d.run(15, 5, report: false);
    expect(d.engine.speedDerived, isTrue);
    expect(d.engine.speed, closeTo(15, 0.05));
    expect(d.engine.trip.distance, closeTo(15 * 4, 0.5));
  });

  test('stale cached fix at launch is ignored', () {
    final e = SpeedEngine();
    final now = DateTime(2026, 10, 3, 8);
    e.addFix(
      Fix(
        lat: 1,
        lon: 1,
        accuracy: 5,
        speed: 30,
        time: now.subtract(const Duration(minutes: 3)),
      ),
      now,
    );
    expect(e.state, GpsState.searching);
    expect(e.speed, isNull);
  });

  test('pause then resume does not count the gap as travel', () {
    final d = Drive();
    d.run(20, 5);
    final before = d.engine.trip.distance;
    d.engine.pause();
    d.lat += 5000 / metersPerDegLat; // 앱이 뒤에 있는 동안 5 km 이동
    d.secs += 300;
    d.run(20, 1);
    expect(d.engine.trip.distance, before);
  });

  test('trip json round trip and reset', () {
    final d = Drive();
    d.run(20, 10);
    final j = d.engine.trip.toJson();
    final back = Trip.fromJson(j);
    expect(back.distance, d.engine.trip.distance);
    expect(back.maxMs, d.engine.trip.maxMs);
    expect(back.moving, d.engine.trip.moving);
    d.engine.resetTrip();
    expect(d.engine.trip.distance, 0);
  });

  group('speed alert', () {
    SpeedAlert alert() => SpeedAlert()
      ..enabled = true
      ..limit = 65
      ..unit = SpeedUnit.mph;
    double mph(double v) => SpeedUnit.mph.toMs(v);

    test('needs two readings over the limit, then stays until 1 below', () {
      final a = alert();
      expect(a.update(mph(66)), isFalse);
      expect(a.over, isFalse, reason: '한 번 튄 값으로는 안 울린다');
      expect(a.update(mph(66)), isTrue);
      expect(a.over, isTrue);
      expect(a.update(mph(67)), isFalse, reason: '이미 넘은 상태 — 다시 울리지 않음');
      a.update(mph(65));
      expect(a.over, isTrue, reason: '경계값에선 유지 (깜빡임 방지)');
      a.update(mph(64));
      expect(a.over, isFalse);
    });

    test('exactly at the limit does not alert', () {
      final a = alert();
      a.update(mph(65.2));
      a.update(mph(65.4));
      expect(a.over, isFalse);
    });

    test('off or no GPS: never over', () {
      final a = alert()..enabled = false;
      a.update(mph(90));
      a.update(mph(90));
      expect(a.over, isFalse);
      final b = alert();
      b.update(mph(90));
      b.update(mph(90));
      expect(b.over, isTrue);
      b.update(null);
      expect(b.over, isFalse);
    });
  });
}
