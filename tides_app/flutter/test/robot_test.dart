// 테스트 로봇 — 모든 화면의 모든 버튼을 실제로 눌러 본다.
// 막힌 길(버튼이 안 먹음)·뒤로가기 불가·깨진 레이아웃(overflow 는 Flutter 가 예외로 던져 테스트 실패)을 잡는다.
// NOAA 응답은 Actions 로 받아 둔 실제 응답(test/fixtures)을 쓴다.
// 실행: flutter test test/robot_test.dart  → 누른 버튼 목록이 로그로 찍힌다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tides/core/ads.dart';
import 'package:tides/core/format.dart';
import 'package:tides/core/location.dart';
import 'package:tides/core/store.dart';
import 'package:tides/main.dart';
import 'package:tides/screens/about_sheet.dart';

import 'support.dart';

final pressed = <String>[];
final opened = <Uri>[];

/// 실제 기기 크기 (논리 픽셀 × 배율)
const devices = {
  'iPhone 13 (1170x2532)': (Size(390, 844), 3.0),
  'iPhone SE (750x1334)': (Size(375, 667), 2.0),
  'iPhone 15 Pro Max (1290x2796)': (Size(430, 932), 3.0),
};

const sfHere = LocationResult.found(
  37.8063,
  -122.4659,
); // at the Golden Gate gauge

late FakeNoaa noaa;
late FakeLocation loc;
late DateTime clockNow;

Future<void> boot(
  WidgetTester t, {
  Size size = const Size(390, 844),
  double ratio = 3,
  Map<String, Object>? prefs,
  LocationResult location = sfHere,
  bool granted = false,
  DateTime? now,
  bool offline = false,
  bool keepPrefs = false,
  FakeAds? ads,
}) async {
  t.view.physicalSize = size * ratio;
  t.view.devicePixelRatio = ratio;
  addTearDown(t.view.reset);
  if (!keepPrefs) SharedPreferences.setMockInitialValues(prefs ?? {});
  clockNow = now ?? testNow;
  noaa = FakeNoaa()..offline = offline;
  loc = FakeLocation(location, granted: granted);
  LocationService.i = loc;
  Ads.i = ads ?? FakeAds();
  openLink = (u) async {
    opened.add(u);
    return true;
  };
  AppStore.i = AppStore()
    ..clock = (() => clockNow)
    ..httpClient = noaa.client;
  await t.runAsync(() => AppStore.i.load());
  await t.pumpWidget(
    const SizedBox(),
  ); // a fresh launch, not a rebuild of the old tree
  await t.pumpWidget(const TidesApp());
  await settle(t);
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<void> press(WidgetTester t, Finder f, String label) async {
  // ignore: avoid_print
  if (const bool.fromEnvironment('TRACE')) print('▶ $label');
  expect(f, findsOneWidget, reason: 'button not found: $label');
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  pressed.add(label);
  await settle(t);
}

String textOf(WidgetTester t, Key key) {
  // ignore: avoid_print
  if (const bool.fromEnvironment('TRACE')) print('· text $key');
  final w = t.widget<Text>(find.byKey(key));
  return w.data ?? w.textSpan!.toPlainText();
}

/// The footer sits under the week list; scroll down to it like a person would.
Future<String> footer(WidgetTester t) async {
  // ignore: avoid_print
  if (const bool.fromEnvironment('TRACE')) print('▶ footer');
  await t.scrollUntilVisible(
    find.byKey(const Key('footer')),
    150,
    scrollable: find.descendant(
      of: find.byKey(const Key('week-list')),
      matching: find.byType(Scrollable),
    ),
  );
  await t.pump();
  return textOf(t, const Key('footer'));
}

/// Day rows live in a scrolling list: scroll to the top, then down to row [i], then tap it.
Future<void> pressDay(WidgetTester t, int i, String label) async {
  final list = find.descendant(
    of: find.byKey(const Key('week-list')),
    matching: find.byType(Scrollable),
  );
  await t.drag(list, const Offset(0, 2000));
  await t.pump();
  await t.scrollUntilVisible(find.byKey(Key('day-$i')), 60, scrollable: list);
  await press(t, find.byKey(Key('day-$i')), label);
}

/// Scroll the station list until [f] shows (sections below the fold are built lazily).
Future<void> seeStation(WidgetTester t, Finder f) async {
  final list = find.descendant(
    of: find.byKey(const Key('station-list')),
    matching: find.byType(Scrollable),
  );
  await t.scrollUntilVisible(f, 120, scrollable: list);
  await t.pump();
  expect(f, findsOneWidget);
}

/// The 30-day card sits under the week list.
Future<void> toMonthCard(WidgetTester t) async {
  await t.scrollUntilVisible(find.byKey(const Key('month-button')), 150,
      scrollable: find.descendant(of: find.byKey(const Key('week-list')), matching: find.byType(Scrollable)));
  await t.pump();
}

void keyboard(WidgetTester t, bool up) {
  t.view.viewInsets = up
      ? FakeViewPadding(bottom: 336 * t.view.devicePixelRatio)
      : FakeViewPadding.zero;
}

void main() {
  tearDownAll(() {
    // ignore: avoid_print
    print('\n누른 버튼 (${pressed.length}개):\n  ${pressed.toSet().join('\n  ')}');
  });

  testWidgets('첫 실행: 내 위치 → 가장 가까운 관측소 → 물때 화면의 모든 버튼', (t) async {
    await boot(t);
    expect(find.text('Tides near you'), findsOneWidget);
    expect(find.textContaining('3499 coastal stations'), findsOneWidget);
    await press(
      t,
      find.byKey(const Key('welcome-near-me')),
      'Welcome · Use My Location',
    );
    expect(loc.asked, 1);
    expect(find.text('San Francisco (Golden Gate)'), findsOneWidget);
    expect(
      find.byIcon(Icons.near_me),
      findsOneWidget,
      reason: 'near-me marker',
    );

    // 지금 상태: NOAA 다음 만조/간조와 일치해야 한다
    final d = AppStore.i.data!;
    final next = d.nextEvent(testNow)!;
    expect(textOf(t, const Key('trend')), next.isHigh ? 'Rising' : 'Falling');
    expect(
      textOf(t, const Key('next-event')),
      startsWith(
        '${next.isHigh ? 'High' : 'Low'} ${height(next.feet, Units.feet)} at ${clock(next.time, AppStore.i.station!.zone)}',
      ),
    );
    expect(textOf(t, const Key('height-now')), endsWith('ft now'));
    expect(textOf(t, const Key('chart-title')), 'Today · Fri, Oct 2');
    expect((await footer(t)), contains('PDT'));
    expect((await footer(t)), contains('NOAA 6-minute'));
    expect((await footer(t)), contains('Not for navigation'));
    expect(textOf(t, const Key('sun-times')), '7:06 AM – 6:51 PM');
    expect(textOf(t, const Key('moon-phase')), startsWith('Waning Gibbous'));
    expect(find.byKey(const Key('ad-banner')), findsOneWidget);

    // 그래프: 탭·끌기로 시각 읽기
    await press(t, find.byKey(const Key('tide-chart')), 'Chart · tap');
    expect(textOf(t, const Key('chart-readout')), contains(' ft'));
    final before = textOf(t, const Key('chart-readout'));
    final c = t.getRect(find.byKey(const Key('tide-chart')));
    await t.dragFrom(c.centerLeft + const Offset(30, 0), const Offset(200, 0));
    pressed.add('Chart · drag');
    await settle(t);
    expect(textOf(t, const Key('chart-readout')), isNot(before));

    // 7일 표: 하루씩 눌러 그래프 바꾸기
    const names = [
      'Saturday · Oct 3',
      'Sunday · Oct 4',
      'Monday · Oct 5',
      'Tuesday · Oct 6',
      'Wednesday · Oct 7',
      'Thursday · Oct 8',
    ];
    for (var i = 1; i < 7; i++) {
      await pressDay(t, i, 'Week · day $i');
      expect(textOf(t, const Key('chart-title')), names[i - 1]);
      expect(
        find.byKey(const Key('chart-readout')),
        findsNothing,
        reason: 'readout resets per day',
      );
    }
    expect(
      find.textContaining('New Moon'),
      findsNothing,
    ); // Oct 10 is outside the week
    await pressDay(t, 0, 'Week · Today');
    expect(textOf(t, const Key('chart-title')), 'Today · Fri, Oct 2');

    // 즐겨찾기
    await press(t, find.byKey(const Key('favorite-button')), 'Favorite ☆');
    expect(AppStore.i.favorites, ['9414290']);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);

    // 설정: 단위 바꾸기, 개인정보처리방침, 닫기
    await press(t, find.byKey(const Key('settings-button')), 'Settings');
    expect(
      find.text(
        'Not for navigation. Always check official sources and local conditions before going out on the water.',
      ),
      findsOneWidget,
    );
    await press(t, find.text('Meters'), 'Settings · Meters');
    await press(
      t,
      find.byKey(const Key('privacy-link')),
      'Settings · Privacy Policy',
    );
    expect(
      opened.last.toString(),
      'https://soulfulfillable.github.io/test-mvp/tides-privacy.html',
    );
    await press(t, find.byKey(const Key('close-settings')), 'Settings · Done');
    expect(find.byKey(const Key('close-settings')), findsNothing);
    expect(textOf(t, const Key('height-now')), endsWith(' m now'));
    expect(textOf(t, const Key('chart-title')), 'Today · Fri, Oct 2');
    await press(
      t,
      find.byKey(const Key('settings-button')),
      'Settings (again)',
    );
    await press(t, find.text('Feet'), 'Settings · Feet');
    await t.tapAt(const Offset(200, 40)); // tap outside the sheet closes it
    pressed.add('Settings · tap outside');
    await settle(t);
    expect(find.byKey(const Key('close-settings')), findsNothing);
    expect(textOf(t, const Key('height-now')), endsWith(' ft now'));

    // 관측소 바꾸기: 즐겨찾기·근처·인기·검색
    await press(
      t,
      find.byKey(const Key('station-button')),
      'Header · Change station',
    );
    expect(find.text('FAVORITES'), findsOneWidget);
    expect(find.text('NEARBY'), findsOneWidget);
    await seeStation(t, find.text('POPULAR'));
    await t.tap(find.byKey(const Key('search-field')));
    keyboard(t, true);
    await t.enterText(find.byKey(const Key('search-field')), 'honolulu');
    pressed.add('Stations · type "honolulu"');
    await settle(t);
    expect(find.byKey(const Key('station-res-1612340')), findsOneWidget);
    await press(t, find.byKey(const Key('clear-search')), 'Stations · clear ✕');
    expect(find.text('FAVORITES'), findsOneWidget);
    await t.enterText(find.byKey(const Key('search-field')), 'honolulu');
    await settle(t);
    await press(
      t,
      find.byKey(const Key('fav-res-1612340')),
      'Stations · ☆ on result',
    );
    expect(AppStore.i.favorites, contains('1612340'));
    await press(
      t,
      find.byKey(const Key('station-res-1612340')),
      'Stations · pick Honolulu',
    );
    keyboard(t, false);
    await settle(t);
    expect(find.text('Honolulu'), findsOneWidget);
    expect(find.byIcon(Icons.near_me), findsNothing, reason: 'picked by hand');
    expect((await footer(t)), contains('HST'));
    expect(textOf(t, const Key('chart-title')), 'Today · Fri, Oct 2');

    // 뒤로 가기
    await press(
      t,
      find.byKey(const Key('station-button')),
      'Header · Change station (again)',
    );
    await press(t, find.byTooltip('Back'), 'Stations · Back');
    expect(find.text('Honolulu'), findsOneWidget);

    // 즐겨찾기에서 고르기
    await press(
      t,
      find.byKey(const Key('station-button')),
      'Header · Change station (3)',
    );
    await press(
      t,
      find.byKey(const Key('station-fav-9414290')),
      'Stations · pick favorite SF',
    );
    expect(find.text('San Francisco (Golden Gate)'), findsOneWidget);
    // 인기 목록에서 고르기
    await press(
      t,
      find.byKey(const Key('station-button')),
      'Header · Change station (4)',
    );
    await seeStation(t, find.byKey(const Key('station-pop-8443970')));
    await press(
      t,
      find.byKey(const Key('station-pop-8443970')),
      'Stations · pick popular Boston',
    );
    expect(find.text('Boston'), findsOneWidget);
    expect((await footer(t)), contains('EDT'));
    // 즐겨찾기 해제 (관측소 화면의 별)
    await press(
      t,
      find.byKey(const Key('station-button')),
      'Header · Change station (5)',
    );
    await press(
      t,
      find.byKey(const Key('fav-fav-9414290')),
      'Stations · ★ off',
    );
    expect(AppStore.i.favorites, ['1612340']);
    // 관측소 화면에서 내 위치 (목록 맨 위)
    await t.drag(find.byKey(const Key('station-list')), const Offset(0, 2000));
    await settle(t);
    await press(
      t,
      find.byKey(const Key('near-me')),
      'Stations · Nearest station to me',
    );
    expect(find.text('San Francisco (Golden Gate)'), findsOneWidget);
  });

  testWidgets('위치 거부 → 안내 → 검색으로 관측소 고르기 (보조 관측소 곡선은 "추정" 표기)', (t) async {
    await boot(
      t,
      location: const LocationResult.failed(LocationProblem.denied),
    );
    await press(
      t,
      find.byKey(const Key('welcome-near-me')),
      'Welcome · Use My Location (denied)',
    );
    expect(find.byKey(const Key('welcome-error')), findsOneWidget);
    expect(find.textContaining('search for a station'), findsOneWidget);
    expect(AppStore.i.station, isNull);
    await press(
      t,
      find.byKey(const Key('welcome-search')),
      'Welcome · Search Stations',
    );
    // 처음 화면으로 돌아가기
    await press(t, find.byTooltip('Back'), 'Stations · Back to welcome');
    expect(find.text('Tides near you'), findsOneWidget);
    await press(
      t,
      find.byKey(const Key('welcome-search')),
      'Welcome · Search Stations (again)',
    );
    await press(
      t,
      find.byKey(const Key('near-me')),
      'Stations · near me (denied)',
    );
    expect(find.byKey(const Key('location-error')), findsOneWidget);
    keyboard(t, true);
    await t.enterText(find.byKey(const Key('search-field')), 'zzzzqq');
    await settle(t);
    expect(find.byKey(const Key('no-results')), findsOneWidget);
    await t.enterText(find.byKey(const Key('search-field')), 'san nicolas');
    pressed.add('Stations · type "san nicolas"');
    await settle(t);
    await press(
      t,
      find.byKey(const Key('station-res-9410068')),
      'Stations · pick San Nicolas Island',
    );
    keyboard(t, false);
    await settle(t);
    expect(find.text('San Nicolas Island'), findsOneWidget);
    expect((await footer(t)), contains('estimated'));
    expect(find.byKey(const Key('now-card')), findsOneWidget);
    // Only highs/lows were requested for a subordinate station
    expect(
      noaa.requests.every((u) => u.queryParameters['interval'] == 'hilo'),
      isTrue,
    );
  });

  testWidgets('위치 서비스 꺼짐·영구 거부 문구', (t) async {
    await boot(
      t,
      location: const LocationResult.failed(LocationProblem.serviceOff),
    );
    await press(
      t,
      find.byKey(const Key('welcome-near-me')),
      'Welcome · near me (service off)',
    );
    expect(find.textContaining('Location Services are off'), findsOneWidget);
    loc.result = const LocationResult.failed(LocationProblem.deniedForever);
    await press(
      t,
      find.byKey(const Key('welcome-near-me')),
      'Welcome · near me (denied forever)',
    );
    expect(find.textContaining('Allow it in Settings'), findsOneWidget);
    loc.result = sfHere;
    await press(
      t,
      find.byKey(const Key('welcome-near-me')),
      'Welcome · near me (now allowed)',
    );
    expect(find.text('San Francisco (Golden Gate)'), findsOneWidget);
  });

  testWidgets('바다 근처 신호 없음: 저장된 예보 + Offline 안내 / 저장 없음: No data + 다시 시도', (
    t,
  ) async {
    await boot(t, prefs: {'station': '9414290'});
    expect(find.byKey(const Key('now-card')), findsOneWidget);
    expect(find.byKey(const Key('offline-notice')), findsNothing);
    // 13시간 뒤 다시 켬, 신호 없음 (같은 기기 저장소)
    await boot(
      t,
      keepPrefs: true,
      now: testNow.add(const Duration(hours: 13)),
      offline: true,
    );
    expect(find.byKey(const Key('offline-notice')), findsOneWidget);
    expect(find.byKey(const Key('now-card')), findsOneWidget);
    expect(find.byKey(const Key('tide-chart')), findsOneWidget);

    // 처음부터 신호 없음
    await boot(t, prefs: {'station': '8518750'}, offline: true);
    expect(find.byKey(const Key('no-data')), findsOneWidget);
    expect(find.textContaining("Couldn't reach NOAA"), findsOneWidget);
    expect(
      find.byKey(const Key('tide-chart')),
      findsNothing,
      reason: 'never a fake curve',
    );
    await press(
      t,
      find.byKey(const Key('retry-button')),
      'No data · Try again (still offline)',
    );
    expect(find.byKey(const Key('no-data')), findsOneWidget);
    noaa.offline = false;
    await press(
      t,
      find.byKey(const Key('retry-button')),
      'No data · Try again (back online)',
    );
    expect(find.byKey(const Key('now-card')), findsOneWidget);
    expect(find.text('New York (The Battery)'), findsOneWidget);
    // 다른 관측소 고르기 버튼
    noaa.offline = true;
    await boot(t, prefs: {'station': '8443970'}, offline: true);
    await press(
      t,
      find.text('Choose another station'),
      'No data · Choose another station',
    );
    expect(find.text('Choose a station'), findsOneWidget);
  });

  testWidgets('"내 위치 따라가기" 는 다음 실행 때 가장 가까운 관측소로 바뀐다 (손으로 고른 건 유지)', (t) async {
    await boot(
      t,
      prefs: {'station': '1612340', 'followLocation': true},
      granted: true,
    );
    expect(find.text('San Francisco (Golden Gate)'), findsOneWidget);
    await boot(
      t,
      prefs: {'station': '1612340', 'followLocation': false},
      granted: true,
    );
    expect(find.text('Honolulu'), findsOneWidget);
    expect(loc.asked, 0);
    // 권한이 없으면 묻지 않고 그대로
    await boot(
      t,
      prefs: {'station': '1612340', 'followLocation': true},
      granted: false,
    );
    expect(find.text('Honolulu'), findsOneWidget);
    expect(loc.asked, 0);
  });

  testWidgets('켜 둔 채 자정이 지나면 "Today" 가 다음 날로', (t) async {
    await boot(
      t,
      prefs: {'station': '9414290'},
      now: DateTime.utc(2026, 10, 3, 6, 59),
    ); // 11:59 PM PDT Oct 2
    expect(textOf(t, const Key('chart-title')), 'Today · Fri, Oct 2');
    clockNow = DateTime.utc(2026, 10, 3, 7, 1);
    await t.pump(const Duration(seconds: 31));
    await settle(t);
    expect(textOf(t, const Key('chart-title')), 'Today · Sat, Oct 3');
  });

  for (final MapEntry(key: name, value: (size, ratio)) in devices.entries) {
    testWidgets('화면 크기 $name: 처음 화면·물때·관측소(키보드)·설정', (t) async {
      await boot(t, size: size, ratio: ratio);
      expect(find.byKey(const Key('welcome-near-me')), findsOneWidget);
      await press(
        t,
        find.byKey(const Key('welcome-near-me')),
        '$name · near me',
      );
      expect(find.byKey(const Key('now-card')), findsOneWidget);
      expect(find.byKey(const Key('tide-chart')), findsOneWidget);
      expect(find.byKey(const Key('ad-banner')), findsOneWidget);
      // the week list must show at least two days without scrolling
      final list = t.getRect(find.byKey(const Key('week-list')));
      expect(
        list.height,
        greaterThan(120),
        reason: 'week list squeezed on $name',
      );
      await press(
        t,
        find.byKey(const Key('settings-button')),
        '$name · settings',
      );
      await press(
        t,
        find.byKey(const Key('close-settings')),
        '$name · settings done',
      );
      await press(
        t,
        find.byKey(const Key('station-button')),
        '$name · stations',
      );
      await t.tap(find.byKey(const Key('search-field')));
      keyboard(t, true);
      await t.enterText(find.byKey(const Key('search-field')), 'key');
      await settle(t);
      expect(find.byKey(const Key('search-field')), findsOneWidget);
      expect(
        t.getRect(find.byKey(const Key('search-field'))).top,
        greaterThanOrEqualTo(0),
      );
      keyboard(t, false);
      await settle(t);
    });
  }

  testWidgets('모든 경우: 긴 이름·전 시간대·북극(백야/극야)·보조 관측소 — 화면이 안 깨진다', (t) async {
    await boot(
      t,
      size: const Size(375, 667),
      ratio: 2,
      prefs: {'station': '9414290'},
    );
    final db = AppStore.i.db;
    final ids = <String>{
      // longest names
      ...([...db.all]..sort((a, b) => b.name.length.compareTo(a.name.length)))
          .take(6)
          .map((s) => s.id),
      // one station per standard offset
      for (final off in {for (final s in db.all) s.zone.stdOffsetHours})
        db.all.firstWhere((s) => s.zone.stdOffsetHours == off).id,
      '9494935', // Barrow Offshore, 71°N
      '9455920', // Anchorage
    };
    noaa.subordinate.addAll([
      for (final id in ids)
        if (!db.byId(id)!.isReference) id,
    ]);
    for (final id in ids) {
      final s = db.byId(id)!;
      await t.runAsync(() => AppStore.i.selectStation(s));
      await settle(t);
      expect(find.byKey(const Key('now-card')), findsOneWidget, reason: s.name);
      expect(
        (await footer(t)),
        contains(s.zone.abbreviation(testNow)),
        reason: s.name,
      );
      expect(textOf(t, const Key('sun-times')), isNotEmpty);
      pressed.add('Layout · ${s.name} (${s.zone.abbreviation(testNow)})');
    }
  });

  testWidgets('30일 표: 영상 끝까지 보면 24시간 열림 → 30일 실제 NOAA 표, 다시 누르면 광고 없이', (t) async {
    final ads = FakeAds();
    await boot(t, prefs: {'station': '9414290'}, ads: ads);
    await toMonthCard(t);
    expect(textOf(t, const Key('month-card-text')), contains('watch a short video'));
    await press(t, find.byKey(const Key('month-button')), '30-day · Watch');
    expect(ads.shown, 1);
    expect(find.text('30-day tides'), findsOneWidget);
    expect(find.byKey(const Key('month-day-0')), findsOneWidget);
    expect(textOf(t, const Key('month-footer')), contains('Open until'));
    // every one of the 30 days has real NOAA highs/lows (no "No data" rows)
    final list = find.descendant(of: find.byKey(const Key('month-list')), matching: find.byType(Scrollable));
    await t.scrollUntilVisible(find.byKey(const Key('month-day-29')), 300, scrollable: list);
    expect(find.byKey(const Key('month-day-29')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('month-list')), matching: find.text('No data')), findsNothing);
    expect(AppStore.i.month!.events.length, greaterThan(110));
    await press(t, find.byTooltip('Back'), '30-day · Back');
    await toMonthCard(t);
    expect(textOf(t, const Key('month-card-text')), startsWith('Open until'));
    await press(t, find.byKey(const Key('month-button')), '30-day · Open (already open)');
    expect(ads.shown, 1, reason: 'no second video while open');
    expect(find.text('30-day tides'), findsOneWidget);
    await press(t, find.byTooltip('Back'), '30-day · Back (2)');
    // 25 hours later it is closed again
    await boot(t, keepPrefs: true, now: testNow.add(const Duration(hours: 25)), ads: ads);
    await toMonthCard(t);
    expect(textOf(t, const Key('month-card-text')), contains('watch a short video'));
  });

  testWidgets('30일 표: 중간에 닫음 → 안 열림 / 영상 없음 → 8초 뒤 안내 / 두 번 눌러도 한 번', (t) async {
    final ads = FakeAds(result: RewardResult.closedEarly);
    await boot(t, prefs: {'station': '9414290'}, ads: ads);
    await toMonthCard(t);
    await press(t, find.byKey(const Key('month-button')), '30-day · Watch (closed early)');
    expect(find.byKey(const Key('month-early')), findsOneWidget);
    expect(find.text('30-day tides'), findsNothing);
    expect(AppStore.i.monthOpen, isFalse);
    await t.pump(const Duration(seconds: 5)); // snackbar goes away
    ads
      ..result = RewardResult.unavailable
      ..ready = false
      ..delay = Ads.waitForVideo;
    await t.tap(find.byKey(const Key('month-button')));
    pressed.add('30-day · Watch (no video)');
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Loading…'), findsOneWidget);
    await t.tap(find.byKey(const Key('month-button')));
    pressed.add('30-day · Watch (double tap)');
    await t.pump(const Duration(milliseconds: 300));
    expect(ads.shown, 2, reason: 'double tap must not ask for a second video');
    await t.pump(Ads.waitForVideo);
    await settle(t);
    expect(find.byKey(const Key('month-unavailable')), findsOneWidget);
    expect(find.text('Loading…'), findsNothing);
    expect(AppStore.i.monthOpen, isFalse);
  });

  testWidgets('30일 표: 열려 있는데 신호 없음 → No data + 다시 시도 (가짜 표 없음)', (t) async {
    await boot(t, prefs: {
      'station': '9414290',
      'month.until': testNow.add(const Duration(hours: 3)).millisecondsSinceEpoch,
    });
    noaa.offline = true;
    await toMonthCard(t);
    await press(t, find.byKey(const Key('month-button')), '30-day · Open (offline)');
    expect(find.byKey(const Key('month-no-data')), findsOneWidget);
    expect(find.byKey(const Key('month-day-0')), findsNothing);
    noaa.offline = false;
    await press(t, find.byKey(const Key('month-retry')), '30-day · Try again');
    expect(find.byKey(const Key('month-day-0')), findsOneWidget);
  });
}
