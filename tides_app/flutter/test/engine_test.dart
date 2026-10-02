// 엔진 테스트 — 시간대·NOAA 응답 해석·곡선·일출일몰·달·관측소 검색·캐시.
// 기준값: NOAA 실제 응답(test/fixtures), 일출·달은 PyEphem 으로 계산한 값
// (일출·일몰은 해 중심이 −0°50′ 에 닿는 순간 = NOAA 정의, use_center=True).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tides/core/astro.dart';
import 'package:tides/core/day.dart';
import 'package:tides/core/format.dart';
import 'package:tides/core/station.dart';
import 'package:tides/core/store.dart';
import 'package:tides/core/tides.dart';
import 'package:tides/core/zone.dart';

import 'support.dart';

void expectNear(DateTime a, DateTime b, Duration tol, {String? reason}) {
  expect(a.difference(b).abs() <= tol, isTrue, reason: '${reason ?? ''} got $a, want $b ±$tol');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StationDb db;
  setUpAll(() async => db = await StationDb.load());

  group('station clock', () {
    const pacific = StationZone(-8, observesDst: true);
    const hawaii = StationZone(-10, observesDst: false);
    test('US DST 2026: Mar 8 → Nov 1', () {
      expect(pacific.isDst(DateTime.utc(2026, 3, 8, 9, 59)), isFalse); // 1:59 PST
      expect(pacific.isDst(DateTime.utc(2026, 3, 8, 10, 0)), isTrue); // 2:00 PST → 3:00 PDT
      expect(pacific.isDst(DateTime.utc(2026, 11, 1, 8, 59)), isTrue); // 1:59 PDT
      expect(pacific.isDst(DateTime.utc(2026, 11, 1, 9, 0)), isFalse); // back to 1:00 PST
      expect(pacific.abbreviation(testNow), 'PDT');
      expect(pacific.abbreviation(DateTime.utc(2026, 1, 5)), 'PST');
      expect(hawaii.abbreviation(testNow), 'HST');
      expect(hawaii.offsetAt(DateTime.utc(2026, 7, 1)).inHours, -10);
    });
    test('wall clock round trip and day start', () {
      final w = pacific.toWall(testNow);
      expect((w.hour, w.day), (12, 2));
      expect(pacific.fromWall(w), testNow);
      expect(pacific.startOfDay(DateTime.utc(2026, 10, 2)), DateTime.utc(2026, 10, 2, 7));
      // DST change days are 23 / 25 hours long.
      final mar8 = DayInfo(db.byId('9414290')!, null, DateTime.utc(2026, 3, 8));
      expect(mar8.end.difference(mar8.start).inHours, 23);
      final nov1 = DayInfo(db.byId('9414290')!, null, DateTime.utc(2026, 11, 1));
      expect(nov1.end.difference(nov1.start).inHours, 25);
      const guam = StationZone(10, observesDst: false);
      expect(guam.toWall(testNow).hour, 5);
      expect(guam.toWall(testNow).day, 3);
    });
  });

  group('NOAA predictions', () {
    test('request uses GMT, MLLW, feet, our app name', () {
      final u = NoaaApi.predictionsUri('9414290', DateTime.utc(2026, 9, 30), DateTime.utc(2026, 10, 10), 'hilo');
      expect(u.host, 'api.tidesandcurrents.noaa.gov');
      expect(u.queryParameters['time_zone'], 'gmt');
      expect(u.queryParameters['datum'], 'MLLW');
      expect(u.queryParameters['units'], 'english');
      expect(u.queryParameters['begin_date'], '20260930');
      expect(u.queryParameters['application'], 'soulfulfill_tides');
    });

    test('San Francisco: same highs/lows as NOAA local-time table', () async {
      final noaa = FakeNoaa();
      final sf = db.byId('9414290')!;
      final d = await NoaaApi(noaa.client).fetch(sf, testNow);
      expect(noaa.calls, 2, reason: 'hilo + 6-minute');
      expect(d.hasOfficialCurve, isTrue);
      // NOAA lst_ldt for 2026-10-01: H 04:24 4.416, L 08:36 3.109, H 14:58 6.219, L 22:04 -0.188
      final oct1 = DayInfo(sf, d, DateTime.utc(2026, 10, 1));
      expect([for (final e in oct1.events) '${clock(e.time, sf.zone)} ${e.feet} ${e.isHigh ? 'H' : 'L'}'],
          ['4:24 AM 4.416 H', '8:36 AM 3.109 L', '2:58 PM 6.219 H', '10:04 PM -0.188 L']);
      // The 6-minute curve agrees with the high/low heights.
      for (final e in d.events.take(20)) {
        expect((d.heightAt(e.time)! - e.feet).abs(), lessThan(0.06), reason: '${e.time}');
      }
      final days = buildDays(sf, d, testNow);
      expect(days.length, 7);
      expect(days.every((x) => x.hasData), isTrue, reason: 'fixtures cover the week');
      expect(days.every((x) => x.events.length >= 3), isTrue);
    });

    test('subordinate station: NOAA has no 6-minute series → cosine between real highs/lows', () async {
      final noaa = FakeNoaa();
      final s = db.byId('9410068')!;
      expect(s.isReference, isFalse);
      final d = await NoaaApi(noaa.client).fetch(s, testNow);
      expect(noaa.calls, 1, reason: 'no 6-minute request for subordinate stations');
      expect(d.hasOfficialCurve, isFalse);
      for (final e in d.events) {
        expect(d.heightAt(e.time), closeTo(e.feet, 1e-9));
      }
      // Between a high and the next low the estimate only goes down, and stays inside them.
      final a = d.events[3], b = d.events[4];
      var prev = d.heightAt(a.time)!;
      for (var t = a.time; t.isBefore(b.time); t = t.add(const Duration(minutes: 6))) {
        final h = d.heightAt(t)!;
        expect(h, inInclusiveRange(a.feet < b.feet ? a.feet : b.feet, a.feet > b.feet ? a.feet : b.feet));
        if (a.isHigh) expect(h, lessThanOrEqualTo(prev + 1e-9));
        prev = h;
      }
      // Nothing is drawn before the first or after the last NOAA prediction.
      expect(d.heightAt(d.events.first.time.subtract(const Duration(minutes: 1))), isNull);
      expect(d.heightAt(d.events.last.time.add(const Duration(minutes: 1))), isNull);
    });

    test('NOAA error and network failure become readable messages', () async {
      final noaa = FakeNoaa()..offline = true;
      await expectLater(NoaaApi(noaa.client).fetch(db.byId('9414290')!, testNow), throwsA(isA<NoaaException>()));
    });

    test('cache round trip keeps everything', () async {
      final d = await NoaaApi(FakeNoaa().client).fetch(db.byId('9414290')!, testNow);
      final back = TideData.decode(d.encode())!;
      expect(back.events.length, d.events.length);
      expect(back.curve!.feet.length, d.curve!.feet.length);
      expect(back.heightAt(testNow), closeTo(d.heightAt(testNow)!, 0.001));
      expect(TideData.decode('garbage'), isNull);
    });
  });

  group('sun (vs PyEphem)', () {
    const tol = Duration(seconds: 90);
    test('San Francisco, New York, Honolulu on Oct 2 2026', () {
      var s = sunTimes(DateTime.utc(2026, 10, 2), 37.806305, -122.46589);
      expectNear(s.sunrise!, DateTime.utc(2026, 10, 2, 14, 6, 31), tol);
      expectNear(s.sunset!, DateTime.utc(2026, 10, 3, 1, 51, 3), tol);
      s = sunTimes(DateTime.utc(2026, 10, 2), 40.700554, -74.01417);
      expectNear(s.sunrise!, DateTime.utc(2026, 10, 2, 10, 53, 40), tol);
      expectNear(s.sunset!, DateTime.utc(2026, 10, 2, 22, 36, 20), tol);
      s = sunTimes(DateTime.utc(2026, 10, 2), 21.303333, -157.86453);
      expectNear(s.sunrise!, DateTime.utc(2026, 10, 2, 16, 23, 2), tol);
      expectNear(s.sunset!, DateTime.utc(2026, 10, 3, 4, 17, 58), tol);
    });
    test('Anchorage solstices', () {
      var s = sunTimes(DateTime.utc(2026, 12, 21), 61.238, -149.89);
      expectNear(s.sunrise!, DateTime.utc(2026, 12, 21, 19, 14, 33), const Duration(minutes: 2));
      expectNear(s.sunset!, DateTime.utc(2026, 12, 22, 0, 41, 6), const Duration(minutes: 2));
      s = sunTimes(DateTime.utc(2026, 6, 21), 61.238, -149.89);
      expectNear(s.sunrise!, DateTime.utc(2026, 6, 21, 12, 19, 58), const Duration(minutes: 2));
      expectNear(s.sunset!, DateTime.utc(2026, 6, 22, 7, 42, 55), const Duration(minutes: 2));
    });
    test('Arctic: polar day and polar night', () {
      expect(sunTimes(DateTime.utc(2026, 6, 21), 71.36, -156.7).alwaysUp, isTrue);
      expect(sunTimes(DateTime.utc(2026, 12, 21), 71.36, -156.7).alwaysDown, isTrue);
    });
  });

  group('moon (vs PyEphem)', () {
    const tol = Duration(hours: 3);
    test('October 2026 phases', () {
      final from = DateTime.utc(2026, 10, 1);
      expectNear(nextPrincipalPhase(MoonPhase.lastQuarter, from), DateTime.utc(2026, 10, 3, 13, 25), tol);
      expectNear(nextPrincipalPhase(MoonPhase.newMoon, from), DateTime.utc(2026, 10, 10, 15, 50), tol);
      expectNear(nextPrincipalPhase(MoonPhase.firstQuarter, from), DateTime.utc(2026, 10, 18, 16, 13), tol);
      expectNear(nextPrincipalPhase(MoonPhase.fullMoon, from), DateTime.utc(2026, 10, 26, 4, 12), tol);
      expectNear(nextPrincipalPhase(MoonPhase.newMoon, DateTime.utc(2026, 7, 1)), DateTime.utc(2026, 7, 14, 9, 44), tol);
      expectNear(nextPrincipalPhase(MoonPhase.fullMoon, DateTime.utc(2026, 1, 1)), DateTime.utc(2026, 1, 3, 10, 3), tol);
    });
    test('illumination and day names', () {
      expect(moonIllumination(DateTime.utc(2026, 10, 2, 19)), closeTo(0.5887, 0.02));
      expect(moonIllumination(DateTime.utc(2026, 10, 26, 12)), closeTo(0.997, 0.02));
      expect(moonIllumination(DateTime.utc(2026, 10, 10, 12)), lessThan(0.02));
      final sf = db.byId('9414290')!;
      String phase(int day) => DayInfo(sf, null, DateTime.utc(2026, 10, day)).moon.phase.label;
      expect(phase(2), 'Waning Gibbous');
      expect(phase(3), 'Last Quarter');
      expect(phase(5), 'Waning Crescent');
      expect(phase(10), 'New Moon');
      expect(phase(12), 'Waxing Crescent');
      expect(phase(25), 'Full Moon'); // 04:12 UTC Oct 26 = 9:12 PM PDT Oct 25
    });
  });

  group('stations', () {
    test('list is complete and sane', () {
      expect(db.all.length, 3499);
      expect(db.all.where((s) => s.isReference).length, 1256);
      for (final s in db.all) {
        expect(s.lat, inInclusiveRange(-90, 90));
        expect(s.lng, inInclusiveRange(-180, 180));
        expect(s.name.trim(), isNotEmpty);
      }
      expect(db.byId('1612340')!.zone.observesDst, isFalse); // Hawaii
      expect(db.byId('9414290')!.zone.observesDst, isTrue);
    });
    test('search by name, city, state, ID', () {
      expect(db.search('santa monica').first.id, '9410840');
      expect(db.search('9414290').first.id, '9414290');
      expect(db.search('golden gate').first.id, '9414290');
      expect(db.search('honolulu').first.id, '1612340');
      expect(db.search('key west').first.name, startsWith('Key West'));
      expect(db.search('myrtle').any((s) => s.id == '8661070'), isTrue);
      expect(db.search('monterey california').first.state, 'CA');
      expect(db.search('zzzz'), isEmpty);
      expect(db.search('   '), isEmpty);
    });
    test('nearest station', () {
      expect(db.nearest(34.0083, -118.5).first.$1.id, '9410840');
      expect(db.nearest(21.30, -157.86).first.$1.id, '1612340');
      final near = db.nearest(40.70, -74.01, count: 5);
      expect(near.first.$2, lessThan(1.0));
    });
    test('popular stations all exist', () {
      for (final id in popularStationIds) {
        expect(db.byId(id), isNotNull, reason: id);
      }
    });
  });

  group('store (cache, offline)', () {
    test('first fetch saves; next launch offline shows saved data with a notice', () async {
      SharedPreferences.setMockInitialValues({'station': '9414290'});
      final noaa = FakeNoaa();
      final a = AppStore()
        ..clock = (() => testNow)
        ..httpClient = noaa.client;
      await a.load();
      await a.refresh();
      expect(a.data, isNotNull);
      expect(a.offline, isFalse);
      // 13 hours later, no signal
      noaa.offline = true;
      final b = AppStore()
        ..clock = (() => testNow.add(const Duration(hours: 13)))
        ..httpClient = noaa.client;
      await b.load();
      expect(b.data, isNotNull, reason: 'cache loaded before any network');
      await b.refresh();
      expect(b.offline, isTrue);
      expect(b.error, contains("Couldn't reach NOAA"));
      expect(b.data!.fetchedAt, testNow);
    });
    test('fresh cache is not refetched', () async {
      SharedPreferences.setMockInitialValues({'station': '9414290'});
      final noaa = FakeNoaa();
      final a = AppStore()
        ..clock = (() => testNow)
        ..httpClient = noaa.client;
      await a.load();
      await a.refresh();
      final calls = noaa.calls;
      await a.refresh();
      expect(noaa.calls, calls);
      await a.refresh(force: true);
      expect(noaa.calls, greaterThan(calls));
    });
    test('no cache and no signal → error, no data (never fake)', () async {
      SharedPreferences.setMockInitialValues({'station': '9414290'});
      final noaa = FakeNoaa()..offline = true;
      final a = AppStore()
        ..clock = (() => testNow)
        ..httpClient = noaa.client;
      await a.load();
      await a.refresh();
      expect(a.data, isNull);
      expect(a.error, isNotNull);
    });
  });

  test('formatting', () {
    const z = StationZone(-8, observesDst: true);
    expect(clock(testNow, z), '12:00 PM');
    expect(clock(DateTime.utc(2026, 10, 2, 7, 5), z, compact: true), '12:05a');
    expect(height(6.219, Units.feet), '6.2 ft');
    expect(height(6.219, Units.meters), '1.9 m');
    expect(height(-0.188, Units.feet), '−0.2 ft');
    expect(height(-0.02, Units.feet), '0.0 ft');
    expect(until(const Duration(hours: 2, minutes: 4)), 'in 2h 04m');
    expect(until(const Duration(minutes: 35)), 'in 35m');
  });
}
