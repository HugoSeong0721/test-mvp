// 엔진 테스트 — 달 위치·월출월몰·남중·일출일몰·위상(PyEphem 기준), 공개 솔루나 표 대조,
// 솔루나 구간·점수·사냥 허용 시간, 시간대(서머타임), 장소 검색, 저장소.
// 기준값: tools/solunar/make_reference.py 가 PyEphem 으로 만든 test/fixtures/ephem_reference.json
//   월출·월몰 = USNO 정의(달 윗가장자리, 굴절 34′, 관측자 기준), 일출·일몰 = NOAA 정의(해 중심 −0°50′).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solunar/core/astro.dart';
import 'package:solunar/core/device_zone.dart';
import 'package:solunar/core/format.dart';
import 'package:solunar/core/places.dart';
import 'package:solunar/core/solunar.dart';
import 'package:solunar/core/store.dart';
import 'package:solunar/core/zone.dart';

final ref = jsonDecode(File('test/fixtures/ephem_reference.json').readAsStringSync()) as Map<String, dynamic>;

void expectNear(DateTime a, DateTime b, Duration tol, {String? reason}) {
  expect(a.difference(b).abs() <= tol, isTrue, reason: '${reason ?? ''} got $a, want $b ±$tol');
}

const austin = Place(name: 'Austin, TX', lat: 30.2672, lng: -97.7431, tz: 'America/Chicago');

/// Wall clock "h:mm AM" on [day] at [p] → UTC.
DateTime at(Place p, int y, int m, int d, int h, int min) => PlaceZone(p.tz).fromWall(DateTime.utc(y, m, d, h, min));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(PlaceZone.load);

  group('moon vs PyEphem', () {
    test('geocentric position: 60 instants 2026–2030 within 30″ and 20 km', () {
      for (final p in ref['positions'] as List) {
        final m = moonPosition(DateTime.parse(p['time']));
        var dra = (m.ra - (p['ra'] as num)).abs();
        if (dra > 180) dra = 360 - dra;
        expect(dra * 3600, lessThan(30), reason: 'RA ${p['time']}');
        expect((m.dec - (p['dec'] as num)).abs() * 3600, lessThan(20), reason: 'Dec ${p['time']}');
        expect((m.distanceKm - (p['distanceKm'] as num)).abs(), lessThan(20), reason: 'distance ${p['time']}');
      }
    });

    test('rise, set, overhead, underfoot: 13 places × 35–76 days, none missing', () {
      var n = 0;
      for (final pl in ref['places'] as List) {
        for (final d in pl['days'] as List) {
          final got = moonEvents(DateTime.parse(d['start']), DateTime.parse(d['end']), pl['lat'], pl['lng']);
          final want = [for (final e in d['moon'] as List) (e['kind'] as String, DateTime.parse(e['time']))];
          final where = '${pl['name']} ${d['date']}';
          for (final (kind, t) in want) {
            final match = got.where((g) => g.kind.name == kind && g.time.difference(t).inMinutes.abs() < 15);
            expect(match, isNotEmpty, reason: 'missing $kind $t at $where; got $got');
            // Meridian passages to the second; rise/set within a minute (30 s worst case at 71°N).
            final tol = kind == 'rise' || kind == 'set' ? const Duration(seconds: 60) : const Duration(seconds: 10);
            expectNear(match.first.time, t, tol, reason: '$kind $where');
            n++;
          }
          for (final g in got) {
            final known = want.any((w) => w.$1 == g.kind.name && g.time.difference(w.$2).inMinutes.abs() < 15);
            // PyEphem gives up on this grazing moonrise at 71°N (it checks the previous transit, which was below
            // the horizon); its own altitudes put the upper limb through −34′ at 07:07 UTC, matching ours.
            final pyephemQuirk = where == 'Utqiagvik, AK 2030-08-11' && g.kind == MoonEventKind.rise;
            expect(known || pyephemQuirk, isTrue, reason: 'extra $g at $where; want $want');
          }
        }
      }
      expect(n, greaterThan(1800));
    });

    test('sunrise and sunset within 90 s (NOAA definition)', () {
      var n = 0;
      for (final pl in ref['places'] as List) {
        for (final d in pl['days'] as List) {
          final date = DateTime.parse(d['date']);
          final s = sunTimes(DateTime.utc(date.year, date.month, date.day), pl['lat'], pl['lng']);
          if (d['sun'] == null) {
            expect(s.sunrise, isNull, reason: '${pl['name']} ${d['date']} polar');
            continue;
          }
          expectNear(s.sunrise!, DateTime.parse(d['sun']['sunrise']), const Duration(seconds: 90), reason: '${pl['name']} ${d['date']}');
          expectNear(s.sunset!, DateTime.parse(d['sun']['sunset']), const Duration(seconds: 90), reason: '${pl['name']} ${d['date']}');
          n++;
        }
      }
      expect(n, greaterThan(400));
    });

    test('new, quarter and full moon times within 2 hours (248 phases 2026–2030)', () {
      for (final p in ref['phases'] as List) {
        final want = DateTime.parse(p['time']);
        final phase = switch (p['kind']) {
          'new' => MoonPhase.newMoon,
          'first' => MoonPhase.firstQuarter,
          'full' => MoonPhase.fullMoon,
          _ => MoonPhase.lastQuarter,
        };
        final got = nextPrincipalPhase(phase, want.subtract(const Duration(days: 2)));
        expectNear(got, want, const Duration(hours: 2), reason: '${p['kind']}');
      }
    });

    test('illumination and distance at local noon', () {
      for (final pl in ref['places'] as List) {
        for (final d in pl['days'] as List) {
          final day = SolunarDay(Place(name: pl['name'], lat: pl['lat'], lng: pl['lng'], tz: pl['tz']), DateTime.parse('${d['date']}T00:00:00Z'));
          expect(DateTime.parse(d['start']), day.start, reason: 'local midnight ${pl['name']} ${d['date']}');
          expect(DateTime.parse(d['end']), day.end);
          expect(moonIllumination(day.zone.fromWall(DateTime.utc(day.wallDay.year, day.wallDay.month, day.wallDay.day, 12))),
              closeTo((d['illumination'] as num).toDouble(), 0.02));
        }
      }
    });
  });

  group('published solunar tables', () {
    test('solunarforecast.com, Tool TX, Sep 3 2026 (CDT): majors and minors to 2 minutes', () {
      const tool = Place(name: 'Tool, TX', lat: 32.28, lng: -96.17, tz: 'America/Chicago');
      final d = SolunarDay(tool, DateTime.utc(2026, 9, 3));
      final z = d.zone;
      String s(Period p) => '${p.kind.label} ${span(p.start, p.end, z)}';
      // Published: majors 5:20–7:20 AM, 5:50–7:50 PM; minors 1:18–2:18 PM, 11:16 PM–12:16 AM.
      final want = {
        (PeriodKind.major, at(tool, 2026, 9, 3, 6, 20)),
        (PeriodKind.major, at(tool, 2026, 9, 3, 18, 50)),
        (PeriodKind.minor, at(tool, 2026, 9, 3, 13, 48)),
        (PeriodKind.minor, at(tool, 2026, 9, 3, 23, 46)),
      };
      expect(d.periods.length, 4, reason: d.periods.map(s).join(', '));
      for (final (kind, center) in want) {
        final p = d.periods.firstWhere((p) => p.kind == kind && p.center.difference(center).inMinutes.abs() < 10);
        expectNear(p.center, center, const Duration(minutes: 2));
      }
      expectNear(d.sun.sunrise!, at(tool, 2026, 9, 3, 7, 1), const Duration(minutes: 2));
      expectNear(d.sun.sunset!, at(tool, 2026, 9, 3, 19, 46), const Duration(minutes: 2));
    });

    test('timeanddate, New York 10004, Oct 10 2026 (EDT, new moon)', () {
      const ny = Place(name: 'New York', lat: 40.7033, lng: -74.0170, tz: 'America/New_York');
      final d = SolunarDay(ny, DateTime.utc(2026, 10, 10));
      expectNear(d.event(MoonEventKind.rise)!.time, at(ny, 2026, 10, 10, 7, 1), const Duration(minutes: 2));
      expectNear(d.event(MoonEventKind.set)!.time, at(ny, 2026, 10, 10, 18, 6), const Duration(minutes: 2));
      expectNear(d.event(MoonEventKind.overhead)!.time, at(ny, 2026, 10, 10, 12, 38), const Duration(minutes: 2));
      expect(d.phase.phase, MoonPhase.newMoon);
      expect(d.phase.illumination, lessThan(0.01));
    });

    test('timeanddate, San Jose CA, Oct 22 2026 (PDT)', () {
      const sj = Place(name: 'San Jose', lat: 37.3394, lng: -121.8950, tz: 'America/Los_Angeles');
      final d = SolunarDay(sj, DateTime.utc(2026, 10, 22));
      expectNear(d.sun.sunrise!, at(sj, 2026, 10, 22, 7, 21), const Duration(minutes: 2));
      expectNear(d.sun.sunset!, at(sj, 2026, 10, 22, 18, 22), const Duration(minutes: 2));
      expectNear(d.event(MoonEventKind.set)!.time, at(sj, 2026, 10, 22, 3, 35), const Duration(minutes: 2));
      expectNear(d.event(MoonEventKind.rise)!.time, at(sj, 2026, 10, 22, 16, 26), const Duration(minutes: 2));
      expectNear(d.event(MoonEventKind.overhead)!.time, at(sj, 2026, 10, 22, 22, 28), const Duration(minutes: 2));
      expect(d.phase.illumination, closeTo(0.89, 0.04));
    });
  });

  group('solunar day', () {
    test('Major = moon overhead/underfoot ± 1 h, Minor = moonrise/moonset ± 30 min', () {
      final d = SolunarDay(austin, DateTime.utc(2026, 10, 2));
      expect(d.periods, isNotEmpty);
      for (final p in d.periods) {
        final major = p.event.kind == MoonEventKind.overhead || p.event.kind == MoonEventKind.underfoot;
        expect(p.kind, major ? PeriodKind.major : PeriodKind.minor);
        expect(p.end.difference(p.start), major ? const Duration(hours: 2) : const Duration(hours: 1));
        expect(p.center, p.event.time);
        expect(d.contains(p.center), isTrue);
      }
      // Sorted by time.
      for (var i = 1; i < d.periods.length; i++) {
        expect(d.periods[i].center.isAfter(d.periods[i - 1].center), isTrue);
      }
    });

    test('a month has days with no moonrise or no moonset — shown as 3 periods, never invented', () {
      var three = 0;
      for (var i = 0; i < 30; i++) {
        final d = SolunarDay(austin, DateTime.utc(2026, 10, 1 + i));
        expect(d.periods.length, inInclusiveRange(3, 4));
        if (d.periods.length == 3) three++;
      }
      expect(three, inInclusiveRange(1, 6));
    });

    test('score = phase 60 + sunrise/sunset timing 25 + distance 15, labels by total', () {
      final newMoon = SolunarDay(austin, DateTime.utc(2026, 10, 10)); // new moon Oct 10
      final quarter = SolunarDay(austin, DateTime.utc(2026, 10, 3)); // last quarter Oct 3
      expect(newMoon.phase.phase, MoonPhase.newMoon);
      expect(quarter.phase.phase, MoonPhase.lastQuarter);
      expect(newMoon.score.phasePoints, greaterThanOrEqualTo(59));
      expect(quarter.score.phasePoints, lessThanOrEqualTo(1));
      expect(newMoon.score.total, greaterThan(quarter.score.total + 30));
      for (var i = 0; i < 60; i++) {
        final s = SolunarDay(austin, DateTime.utc(2026, 10, 1 + i)).score;
        expect(s.total, s.phasePoints + s.timingPoints + s.distancePoints);
        expect(s.phase, inInclusiveRange(0, 1));
        expect(s.timing, inInclusiveRange(0, 1));
        expect(s.distance, inInclusiveRange(0, 1));
      }
      expect(Rating.of(70), Rating.best);
      expect(Rating.of(69), Rating.good);
      expect(Rating.of(50), Rating.good);
      expect(Rating.of(49), Rating.fair);
      expect(Rating.of(30), Rating.fair);
      expect(Rating.of(29), Rating.slow);
    });

    test('a year of scores spreads over all four labels', () {
      final counts = <Rating, int>{};
      for (var i = 0; i < 365; i += 2) {
        final r = SolunarDay(austin, DateTime.utc(2026, 1, 1 + i)).score.rating;
        counts[r] = (counts[r] ?? 0) + 1;
      }
      for (final r in Rating.values) {
        expect(counts[r] ?? 0, greaterThan(10), reason: '$r: $counts');
      }
    });

    test('legal shooting light = sunrise − before … sunset + after', () {
      final d = SolunarDay(austin, DateTime.utc(2026, 10, 2));
      final l = d.legalLight(30, 30)!;
      expect(d.sun.sunrise!.difference(l.start), const Duration(minutes: 30));
      expect(l.end.difference(d.sun.sunset!), const Duration(minutes: 30));
      final duck = d.legalLight(30, 0)!;
      expect(duck.end, d.sun.sunset);
      // Utqiagvik in December: no sunrise → no shooting-light window, not a made-up one.
      const north = Place(name: 'Utqiagvik', lat: 71.29, lng: -156.79, tz: 'America/Anchorage');
      final dark = SolunarDay(north, DateTime.utc(2026, 12, 15));
      expect(dark.sun.alwaysDown, isTrue);
      expect(dark.legalLight(30, 30), isNull);
    });

    test('now: inside a period, else the next one (tomorrow if needed)', () {
      final days = SolunarDay.week(austin, DateTime.utc(2026, 10, 2, 17), count: 3);
      final p = days.first.periods.first;
      final inside = NowStatus.at(p.center, days);
      expect(inside.current, isNotNull);
      expect(inside.current!.contains(p.center), isTrue);
      final before = NowStatus.at(p.start.subtract(const Duration(minutes: 1)), days);
      expect(before.current == null || before.current!.event != p.event, isTrue);
      expect(before.next!.start.isAfter(p.start.subtract(const Duration(minutes: 1))), isTrue);
      final late = NowStatus.at(days.first.end.subtract(const Duration(minutes: 1)), days);
      expect(late.next, isNotNull);
      expect(late.next!.start.isAfter(days.first.end.subtract(const Duration(minutes: 1))), isTrue);
    });
  });

  group('time zones', () {
    test('US DST 2026 (Mar 8 → Nov 1): 23- and 25-hour days, CDT/CST, Arizona stays MST', () {
      final chicago = PlaceZone('America/Chicago');
      expect(SolunarDay(austin, DateTime.utc(2026, 3, 8)).end.difference(SolunarDay(austin, DateTime.utc(2026, 3, 8)).start).inHours, 23);
      final nov1 = SolunarDay(austin, DateTime.utc(2026, 11, 1));
      expect(nov1.end.difference(nov1.start).inHours, 25);
      expect(chicago.abbreviation(DateTime.utc(2026, 10, 2)), 'CDT');
      expect(chicago.abbreviation(DateTime.utc(2026, 12, 2)), 'CST');
      final phx = PlaceZone('America/Phoenix');
      expect(phx.abbreviation(DateTime.utc(2026, 7, 1)), 'MST');
      expect(phx.offsetAt(DateTime.utc(2026, 7, 1)).inHours, -7);
      expect(chicago.startOfDay(DateTime.utc(2026, 10, 2)), DateTime.utc(2026, 10, 2, 5));
      expect(chicago.fromWall(chicago.toWall(DateTime.utc(2026, 10, 2, 17, 3))), DateTime.utc(2026, 10, 2, 17, 3));
      expect(PlaceZone('Not/AZone').name, 'UTC');
      expect(PlaceZone.isKnown('America/Boise'), isTrue);
    });

    test('formatting', () {
      final z = PlaceZone('America/Chicago');
      expect(clock(DateTime.utc(2026, 10, 2, 17, 3), z), '12:03 PM');
      expect(span(DateTime.utc(2026, 10, 2, 18), DateTime.utc(2026, 10, 2, 20), z), '1:00 – 3:00 PM');
      expect(span(DateTime.utc(2026, 10, 2, 16), DateTime.utc(2026, 10, 2, 18), z), '11:00 AM – 1:00 PM');
      expect(duration(const Duration(hours: 2, minutes: 5)), '2h 05m');
      expect(duration(const Duration(minutes: 34)), '34m');
      expect(duration(const Duration(seconds: 20)), '<1m');
      expect(relativeDay(DateTime.utc(2026, 10, 3), DateTime.utc(2026, 10, 2)), 'Tomorrow');
    });
  });

  group('places', () {
    late PlaceDb db;
    setUpAll(() async => db = await PlaceDb.load());

    test('20k US and Canadian towns with real time zones', () {
      expect(db.towns.length, greaterThan(19000));
      for (final t in db.towns) {
        expect(PlaceZone.isKnown(t.tz), isTrue, reason: t.label);
      }
      expect(db.towns.where((t) => t.region == 'ON'), isNotEmpty);
      expect(db.towns.where((t) => t.region == 'PR'), isNotEmpty);
    });

    test('search: name, "town, ST", saint/st, accents, nothing', () {
      expect(db.search('austin').first.label, 'Austin, TX');
      expect(db.search('Austin, MN').first.label, 'Austin, MN');
      expect(db.search('austin mn').first.label, 'Austin, MN');
      expect(db.search('saint louis').first.label, 'St. Louis, MO');
      expect(db.search('st. louis').first.label, 'St. Louis, MO');
      expect(db.search('montreal').first.region, 'QC');
      expect(db.search('   '), isEmpty);
      expect(db.search('zzzxqv'), isEmpty);
      expect(db.search('springfield').length, greaterThan(5));
      expect(db.search('spring').first.label, 'Spring, TX', reason: 'exact name before longer names');
    });

    test('nearest town and its distance', () {
      final (t, mi) = db.nearest(30.27, -97.74).first;
      expect(t.label, 'Austin, TX');
      expect(mi, lessThan(1));
      expect(milesBetween(30.2672, -97.7431, 32.7767, -96.7970), closeTo(182, 3)); // Austin → Dallas
    });
  });

  group('store', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DeviceZone.i = FakeDeviceZone('America/Chicago');
    });

    test('GPS spot: phone time zone + "near" town; unknown zone falls back to the town', () async {
      final s = AppStore()..clock = () => DateTime.utc(2026, 10, 2, 17);
      await s.load();
      final p = await s.placeFromFix(30.30, -97.70);
      expect(p.isGps, isTrue);
      expect(p.tz, 'America/Chicago');
      expect(p.detail, 'near Austin, TX');
      DeviceZone.i = FakeDeviceZone('UTC');
      final q = await s.placeFromFix(33.45, -112.07);
      expect(q.tz, 'America/Phoenix');
      expect(q.detail, contains('Phoenix, AZ'));
    });

    test('favorites, offsets and the 24-hour calendar unlock survive a restart', () async {
      var now = DateTime.utc(2026, 10, 2, 17);
      final s = AppStore()..clock = () => now;
      await s.load();
      await s.selectPlace(austin);
      await s.addFavorite(austin);
      await s.addFavorite(austin); // no duplicates
      final gps = await s.placeFromFix(30.30, -97.70);
      await s.addFavorite(gps, name: '  Deer stand ');
      await s.setLegalOffsets(before: 45, after: 200);
      expect(s.afterSunset, 90, reason: 'clamped');
      expect(s.calendarOpen, isFalse);
      await s.unlockCalendar();
      expect(s.calendarOpen, isTrue);

      final again = AppStore()..clock = () => now;
      await again.load();
      expect(again.place!.name, 'Austin, TX');
      expect(again.favorites.map((f) => f.name), ['Deer stand', 'Austin, TX']);
      expect(again.favorites.first.isGps, isFalse, reason: 'a saved spot stays put');
      expect((again.beforeSunrise, again.afterSunset), (45, 90));
      expect(again.calendarOpen, isTrue);
      now = now.add(const Duration(hours: 24, minutes: 1));
      expect(again.calendarOpen, isFalse);
      now = DateTime.utc(2026, 9, 1); // clock set back a month
      expect(again.calendarOpen, isFalse);
      await again.removeFavorite(austin);
      expect(again.favorites.length, 1);
    });

    test('days are cached per place and day', () async {
      final s = AppStore()..clock = () => DateTime.utc(2026, 10, 2, 17);
      await s.load();
      await s.selectPlace(austin);
      final a = s.days();
      expect(identical(a, s.days()), isTrue);
      expect(a.first.wallDay, DateTime.utc(2026, 10, 2));
      expect(a.length, 8);
    });
  });
}
