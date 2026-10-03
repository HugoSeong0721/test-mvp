// 테스트 로봇 — 모든 화면의 모든 버튼을 실제로 눌러 본다.
// 막힌 길(버튼이 안 먹거나 가려짐)·뒤로가기 불가·깨진 레이아웃(overflow 는 Flutter 가 예외로 던져 실패)·
// 잘린 글자(…)를 잡는다. 3개 기기 크기, 큰 글씨, 키보드가 뜬 상태, 자정 넘김, 북극권, 광고 실패까지.
// 실행: flutter test test/robot_test.dart
//   → 누른 버튼 목록이 로그로 찍히고, 화면별 스크린샷이 build/robot_shots/ 에 저장된다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solunar/core/ads.dart';
import 'package:solunar/core/device_zone.dart';
import 'package:solunar/core/format.dart';
import 'package:solunar/core/location.dart';
import 'package:solunar/core/places.dart';
import 'package:solunar/core/solunar.dart';
import 'package:solunar/core/store.dart';
import 'package:solunar/core/zone.dart';
import 'package:solunar/main.dart';
import 'package:solunar/screens/settings_screen.dart';

final pressed = <String>[];
final shots = <String>[];
final opened = <Uri>[];

/// 실제 기기 크기 (논리 픽셀, 배율, 위·아래 안전 영역)
const devices = {
  'iPhone 13 (1170x2532)': (Size(390, 844), 3.0, 47.0, 34.0),
  'iPhone SE (750x1334)': (Size(375, 667), 2.0, 20.0, 0.0),
  'iPhone 15 Pro Max (1290x2796)': (Size(430, 932), 3.0, 59.0, 34.0),
};
const iphone13 = 'iPhone 13 (1170x2532)';

/// Fri Oct 2 2026, 12:00 PM CDT in Austin.
final testNow = DateTime.utc(2026, 10, 2, 17);
const austinFix = LocationResult.found(30.2672, -97.7431);
const austin = Place(name: 'Austin, TX', lat: 30.267, lng: -97.743, tz: 'America/Chicago');

late FakeLocation loc;
late DateTime clockNow;

var _fontsLoaded = false;

/// 테스트 기본 글꼴(Ahem)은 글자가 정사각형이라 잘림 검사가 틀린다 → SDK Roboto 로 실제 폭을 잰다 (속도계·대출 세션 노하우).
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final root = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts';
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final file = File('$root/$f');
      if (!file.existsSync()) {
        // ignore: avoid_print
        print('WARNING: font not found $root/$f — truncation checks use test font');
        return;
      }
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }

  await family('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
  await family('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

Future<void> boot(
  WidgetTester t, {
  String device = iphone13,
  Map<String, Object>? prefs,
  LocationResult location = austinFix,
  bool granted = false,
  DateTime? now,
  String deviceZone = 'America/Chicago',
  double textScale = 1,
  bool keepPrefs = false,
  FakeAds? ads,
}) async {
  await t.runAsync(loadFonts);
  final (size, ratio, top, bottom) = devices[device]!;
  t.view.physicalSize = size * ratio;
  t.view.devicePixelRatio = ratio;
  t.view.padding = FakeViewPadding(top: top * ratio, bottom: bottom * ratio);
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  if (!keepPrefs) SharedPreferences.setMockInitialValues(prefs ?? {});
  clockNow = now ?? testNow;
  loc = FakeLocation(location, granted: granted);
  LocationService.i = loc;
  DeviceZone.i = FakeDeviceZone(deviceZone);
  Ads.i = ads ?? FakeAds();
  openLink = (u) async {
    opened.add(u);
    return true;
  };
  AppStore.i = AppStore()..clock = (() => clockNow);
  await t.runAsync(() => AppStore.i.load());
  await t.pumpWidget(const SizedBox()); // a fresh launch, not a rebuild of the old tree
  await t.pumpWidget(const SolunarApp());
  await settle(t);
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

/// Dispose the app so its timers stop before the test ends.
Future<void> finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 5));
}

Finder key(String k) => find.byKey(Key(k));

/// Scroll a lazily built list until [f] exists.
Future<void> seeIn(WidgetTester t, String listKey, Finder f) async {
  final list = find.descendant(of: key(listKey), matching: find.byType(Scrollable)).first;
  if (f.evaluate().isEmpty) {
    // From the top down, like a person looking for it.
    await t.drag(list, const Offset(0, 5000));
    await settle(t);
    await t.scrollUntilVisible(f, 200, scrollable: list);
  }
  await t.pump();
}

/// 버튼이 화면 안에 있고, 위에 다른 게 덮여 있지 않은지 확인하고 누른다.
Future<void> press(WidgetTester t, Finder f, String label) async {
  // ignore: avoid_print
  if (const bool.fromEnvironment('TRACE')) print('▶ $label');
  expect(f, findsOneWidget, reason: 'button not found: $label');
  await t.ensureVisible(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 200));
  final center = t.getCenter(f);
  final screen = Offset.zero & t.view.physicalSize / t.view.devicePixelRatio;
  expect(screen.contains(center), isTrue, reason: 'button off screen: $label at $center');
  final ro = t.renderObject(f);
  final hit = t.hitTestOnBinding(center);
  expect(hit.path.any((e) => identical(e.target, ro)) || _hitsDescendant(hit, ro), isTrue,
      reason: 'button covered / not tappable: $label');
  await t.tap(f);
  pressed.add(label);
  await settle(t);
  expectNoTruncatedText(t, 'after $label');
}

bool _hitsDescendant(HitTestResult hit, RenderObject ro) {
  for (final e in hit.path) {
    final target = e.target;
    if (target is RenderObject) {
      for (RenderObject? p = target; p != null; p = p.parent) {
        if (identical(p, ro)) return true;
      }
    }
  }
  return false;
}

Future<void> back(WidgetTester t, String label) => press(t, find.byTooltip('Back'), 'Back ($label)');

/// Names that are allowed to end in "…" (a long saved-place name in a one-line title).
const _ellipsisOk = ['place-name', 'place-detail', 'fav-', 'town-'];

/// 화면의 글자가 '…' 이나 잘림으로 끊기지 않았는지.
void expectNoTruncatedText(WidgetTester t, String where) {
  for (final e in find.byType(RichText).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderParagraph || !ro.attached || !ro.hasSize) continue;
    if (!ro.didExceedMaxLines) continue;
    var allowed = false;
    e.visitAncestorElements((a) {
      final k = a.widget.key;
      if (k is ValueKey<String> && _ellipsisOk.any((p) => k.value.startsWith(p))) {
        allowed = true;
        return false;
      }
      return true;
    });
    expect(allowed, isTrue, reason: '$where: text cut off: "${ro.text.toPlainText()}"');
  }
}

String textOf(WidgetTester t, String k) {
  final w = t.widget<Text>(key(k));
  return w.data ?? w.textSpan!.toPlainText();
}

Future<void> shot(WidgetTester t, String name) async {
  final view = t.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final ratio = t.view.devicePixelRatio;
  await t.runAsync(() async {
    final img = await layer.toImage(Offset.zero & t.view.physicalSize, pixelRatio: ratio > 2 ? 2 / ratio : 1);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/robot_shots')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  shots.add(name);
}

void keyboard(WidgetTester t, bool up) {
  t.view.viewInsets = up ? FakeViewPadding(bottom: 336 * t.view.devicePixelRatio) : FakeViewPadding.zero;
}

/// Scroll the main list top to bottom, checking text on the way.
Future<void> sweepHome(WidgetTester t, String where) async {
  final list = find.descendant(of: key('home-list'), matching: find.byType(Scrollable)).first;
  await t.drag(list, const Offset(0, 5000));
  await t.pump();
  for (var i = 0; i < 12; i++) {
    expectNoTruncatedText(t, '$where scroll $i');
    await t.drag(list, const Offset(0, -260));
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(key('footer'), findsOneWidget, reason: '$where: footer reachable');
  await t.drag(list, const Offset(0, 5000));
  await settle(t);
  await t.pump(const Duration(seconds: 2)); // let any fling finish (a moving list ignores taps)
}

Future<void> toTop(WidgetTester t) async {
  await t.drag(find.descendant(of: key('home-list'), matching: find.byType(Scrollable)).first, const Offset(0, 5000));
  await settle(t);
}

SolunarDay engineDay(Place p, DateTime wallDay) => SolunarDay(p, wallDay);

void main() {
  tearDownAll(() {
    // ignore: avoid_print
    print('\n누른 버튼 (${pressed.toSet().length}종, ${pressed.length}회):\n  ${pressed.toSet().join('\n  ')}');
    // ignore: avoid_print
    print('스크린샷 ${shots.length}장: build/robot_shots/');
  });

  testWidgets('첫 실행: 내 위치 → 메인 화면의 모든 버튼', (t) async {
    await boot(t);
    expect(find.text('Best fishing & hunting times'), findsOneWidget);
    await shot(t, '01-welcome');
    await press(t, key('welcome-near-me'), 'Welcome · Use My Location');
    expect(loc.asked, 1);
    expect(textOf(t, 'place-name'), 'My Location');
    expect(textOf(t, 'place-detail'), 'in Austin, TX · CDT');
    // VoiceOver: the place title is a button, not just a heading.
    final sem = t.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp(r'^Place: My Location, in Austin, TX\. Times in CDT\. Change place$')), findsOneWidget);
    sem.dispose();

    // 화면 숫자 = 엔진 계산값
    final today = engineDay(AppStore.i.place!, DateTime.utc(2026, 10, 2));
    expect(textOf(t, 'score-number'), '${today.score.total}');
    expect(textOf(t, 'score-rating'), today.score.rating.label.toUpperCase());
    expect(textOf(t, 'day-title'), 'Today · Fri, Oct 2');
    for (var i = 0; i < today.periods.length; i++) {
      await seeIn(t, 'home-list', key('period-$i'));
    }
    final status = NowStatus.at(testNow, SolunarDay.week(AppStore.i.place!, testNow, count: 3));
    final title = textOf(t, 'now-title');
    expect(title, status.current != null ? '${status.current!.kind.label.toUpperCase()} PERIOD NOW' : 'NEXT: ${status.next!.kind.label.toUpperCase()} PERIOD');
    // Noon: shooting light is on and ends 30 min after sunset.
    await seeIn(t, 'home-list', key('legal-big'));
    expect(textOf(t, 'legal-label'), 'Shooting light ends in');
    final legal = today.legalLight(30, 30)!;
    expect(textOf(t, 'legal-big'), duration(legal.end.difference(testNow)));
    await seeIn(t, 'home-list', key('sunrise'));
    expect(textOf(t, 'sunrise'), clock(today.sun.sunrise!, PlaceZone('America/Chicago')));
    await t.drag(find.descendant(of: key('home-list'), matching: find.byType(Scrollable)).first, const Offset(0, 5000));
    await settle(t);
    await shot(t, '02-home');
    await t.drag(find.descendant(of: key('home-list'), matching: find.byType(Scrollable)).first, const Offset(0, -520));
    await settle(t);
    await shot(t, '03-home-scrolled');

    // 주간 띠: 날마다 눌러 본다 → 제목·점수가 그날로 바뀐다
    for (var i = 1; i < 7; i++) {
      await press(t, key('day-$i'), 'Week strip day $i');
      final d = engineDay(AppStore.i.place!, DateTime.utc(2026, 10, 2 + i));
      expect(textOf(t, 'score-number'), '${d.score.total}');
      expect(key('now-card'), findsNothing, reason: 'no "now" for another day');
      await seeIn(t, 'home-list', key('legal-big'));
      expect(textOf(t, 'legal-label'), 'Legal shooting light');
    }
    await press(t, key('day-0'), 'Week strip Today');
    expect(textOf(t, 'day-title'), 'Today · Fri, Oct 2');

    // 점수 설명
    await press(t, key('how-scored'), 'How is this scored?');
    expect(textOf(t, 'score-phase'), '${today.score.phasePoints} / 60');
    expect(textOf(t, 'score-timing'), '${today.score.timingPoints} / 25');
    expect(textOf(t, 'score-distance'), '${today.score.distancePoints} / 15');
    await shot(t, '04-score-sheet');
    await press(t, key('score-close'), 'Score sheet · Done');
    expect(key('score-close'), findsNothing);

    // 즐겨찾기: GPS 지점은 이름을 받는다
    await press(t, key('fav-toggle'), '☆ Save (GPS spot)');
    expect(key('fav-name'), findsOneWidget);
    await shot(t, '05-save-spot');
    await press(t, key('fav-cancel'), 'Save spot · Cancel');
    expect(AppStore.i.favorites, isEmpty);
    await press(t, key('fav-toggle'), '☆ Save (GPS spot) again');
    await t.enterText(key('fav-name'), 'Deer stand');
    await press(t, key('fav-save'), 'Save spot · Save');
    expect(AppStore.i.favorites.single.name, 'Deer stand');
    expect(find.byIcon(Icons.star), findsOneWidget);
    await press(t, key('fav-toggle'), '★ Remove');
    expect(AppStore.i.favorites, isEmpty);
    await press(t, key('fav-toggle'), '☆ Save again');
    await t.enterText(key('fav-name'), 'Deer stand');
    await press(t, key('fav-save'), 'Save spot · Save (2)');

    // 설정: 사냥 허용 시간 오프셋
    await press(t, key('settings'), 'Settings');
    await shot(t, '06-settings');
    await press(t, key('before-plus'), 'Before sunrise +5');
    expect(textOf(t, 'before-value'), '35 min');
    await press(t, key('before-minus'), 'Before sunrise −5');
    await press(t, key('after-minus'), 'After sunset −5');
    expect(textOf(t, 'after-value'), '25 min');
    await press(t, key('after-plus'), 'After sunset +5');
    await press(t, key('preset-30-0'), 'Preset 30 / sunset');
    expect((AppStore.i.beforeSunrise, AppStore.i.afterSunset), (30, 0));
    await press(t, key('preset-0-0'), 'Preset sunrise / sunset');
    for (var i = 0; i < 20; i++) {
      if (t.widget<IconButton>(key('after-plus')).onPressed == null) break;
      await t.tap(key('after-plus'));
      await t.pump();
    }
    expect(AppStore.i.afterSunset, 90, reason: 'stops at 90');
    expect(t.widget<IconButton>(key('after-plus')).onPressed, isNull);
    expect(t.widget<IconButton>(key('before-minus')).onPressed, isNull, reason: 'stops at 0');
    await press(t, key('preset-30-30'), 'Preset 30 / 30');
    await seeIn(t, 'settings-list', key('privacy-link'));
    await press(t, key('privacy-link'), 'Privacy Policy');
    expect(opened.last, privacyUrl);
    await back(t, 'Settings');
    expect(key('home-list'), findsOneWidget);

    // 카드의 Change 버튼 → 같은 설정 화면
    await seeIn(t, 'home-list', key('legal-change'));
    await press(t, key('legal-change'), 'Hunting · Change');
    expect(key('settings-list'), findsOneWidget);
    await back(t, 'Settings from Change');

    // 30일 달력: 영상 안 보면 잠김 그대로, 보면 24시간 열림
    await seeIn(t, 'home-list', key('open-calendar'));
    expect(textOf(t, 'calendar-hint'), 'Watch a short video to open it for 24 hours');
    await press(t, key('open-calendar'), '30-Day Calendar (locked)');
    await shot(t, '07-unlock-dialog');
    await press(t, key('unlock-cancel'), 'Unlock · Not now');
    expect(AppStore.i.calendarOpen, isFalse);
    await press(t, key('open-calendar'), '30-Day Calendar (locked) again');
    await press(t, key('unlock-watch'), 'Unlock · Watch Video');
    expect((Ads.i as FakeAds).shown, [RewardPlacement.calendar]);
    expect(AppStore.i.calendarOpen, isTrue);
    expect(key('calendar-list'), findsOneWidget);
    await shot(t, '08-calendar');
    for (var i = 0; i < 30; i++) {
      await seeIn(t, 'calendar-list', key('cal-$i'));
    }
    await press(t, key('cal-20'), 'Calendar day +20');
    expect(textOf(t, 'day-title'), dayLabel(DateTime.utc(2026, 10, 22)));
    expect(find.text('Oct 22'), findsNothing, reason: 'not in the week strip, but shown on the main card');
    await seeIn(t, 'home-list', key('open-calendar'));
    await press(t, key('open-calendar'), '30-Day Calendar (open)');
    expect((Ads.i as FakeAds).shown.length, 1, reason: 'no second video within 24 h');
    await back(t, 'Calendar');
    await toTop(t);
    expect(textOf(t, 'day-title'), dayLabel(DateTime.utc(2026, 10, 22)), reason: 'back keeps the picked day');
    await press(t, key('day-0'), 'Week strip Today (after calendar)');

    // 장소: 검색 → 고르기, 저장한 곳, 내 위치
    await press(t, key('place-button'), 'Place title → Places');
    expect(key('fav-0'), findsOneWidget);
    await shot(t, '09-places');
    await t.enterText(key('place-search'), 'austin mn');
    await t.pump();
    expect(find.descendant(of: key('town-0'), matching: find.text('Austin, MN')), findsOneWidget);
    await shot(t, '10-places-search');
    await press(t, key('search-clear'), 'Search · Clear');
    expect(key('fav-0'), findsOneWidget);
    await t.enterText(key('place-search'), 'austin mn');
    await t.pump();
    await press(t, key('town-0'), 'Town result Austin, MN');
    expect(textOf(t, 'place-name'), 'Austin, MN');
    expect(textOf(t, 'place-detail'), 'CDT');
    final mn = engineDay(AppStore.i.place!, DateTime.utc(2026, 10, 2));
    expect(textOf(t, 'score-number'), '${mn.score.total}');
    await press(t, key('place-button'), 'Places (2)');
    await press(t, key('fav-0'), 'Saved place Deer stand');
    expect(textOf(t, 'place-name'), 'Deer stand');
    await press(t, key('place-button'), 'Places (3)');
    await press(t, key('fav-del-0'), 'Delete saved place');
    expect(key('no-favorites'), findsOneWidget);
    await press(t, key('places-gps'), 'Places · Use My Location');
    expect(textOf(t, 'place-name'), 'My Location');
    await press(t, key('place-button'), 'Places (4)');
    await back(t, 'Places');
    expect(key('home-list'), findsOneWidget);
    await finish(t);
  });

  testWidgets('위치 거부 → 안내 → 마을 검색으로 시작', (t) async {
    await boot(t, location: const LocationResult.failed(LocationProblem.denied));
    await press(t, key('welcome-near-me'), 'Welcome · Use My Location (denied)');
    expect(key('welcome-error'), findsOneWidget);
    expect(find.textContaining('search for a town'), findsOneWidget);
    expect(find.textContaining(RegExp('station', caseSensitive: false)), findsNothing, reason: 'tides wording left over');
    await press(t, key('welcome-search'), 'Welcome · Search a Town');
    await back(t, 'Places from welcome');
    expect(key('welcome-search'), findsOneWidget, reason: 'back returns to welcome');
    await press(t, key('welcome-search'), 'Welcome · Search a Town (2)');
    await press(t, key('places-gps'), 'Places · Use My Location (denied)');
    expect(key('places-error'), findsOneWidget);
    await t.enterText(key('place-search'), 'zzqqxx');
    await t.pump();
    expect(key('no-results'), findsOneWidget);
    await t.enterText(key('place-search'), 'Bangor, ME');
    await t.pump();
    await press(t, key('town-0'), 'Town result Bangor, ME');
    expect(textOf(t, 'place-name'), 'Bangor, ME');
    expect(textOf(t, 'place-detail'), 'EDT');
    // A town (not GPS) saves without asking for a name.
    await press(t, key('fav-toggle'), '☆ Save town');
    expect(key('fav-name'), findsNothing);
    expect(AppStore.i.favorites.single.name, 'Bangor, ME');
    await finish(t);
  });

  testWidgets('다시 켜기: 저장된 장소·설정 유지, 내 위치 따라가기는 움직였을 때만 바뀜', (t) async {
    await boot(t, granted: true);
    await press(t, key('welcome-near-me'), 'Welcome · Use My Location');
    await press(t, key('settings'), 'Settings');
    await press(t, key('preset-30-0'), 'Preset 30 / sunset');
    await back(t, 'Settings');
    await finish(t);
    // Relaunch on the same spot: no new prompt, same place.
    await boot(t, granted: true, keepPrefs: true);
    expect(textOf(t, 'place-name'), 'My Location');
    expect((AppStore.i.beforeSunrise, AppStore.i.afterSunset), (30, 0));
    await seeIn(t, 'home-list', key('legal-rule'));
    expect(textOf(t, 'legal-rule'), startsWith('30 min before sunrise to 0 min after sunset'));
    await finish(t);
    // Relaunch 200 miles away (Dallas): follows the phone.
    await boot(t, granted: true, keepPrefs: true, location: const LocationResult.found(32.7767, -96.7970));
    expect(textOf(t, 'place-detail'), startsWith('in Dallas, TX'));
    await finish(t);
    // Relaunch with no fix (indoors, no signal): keeps the last spot instead of failing.
    await boot(t, granted: true, keepPrefs: true, location: const LocationResult.failed(LocationProblem.unavailable));
    expect(textOf(t, 'place-detail'), startsWith('in Dallas, TX'));
    await finish(t);
  });

  for (final device in devices.keys) {
    testWidgets('레이아웃: $device — 메인 화면 끝까지, 설정, 장소, 달력, 키보드', (t) async {
      await boot(t, device: device, prefs: {
        'place': '{"name":"Austin, TX","lat":30.267,"lng":-97.743,"tz":"America/Chicago"}',
        'calendarUntil': testNow.add(const Duration(hours: 5)).toIso8601String(),
      });
      await sweepHome(t, device);
      await press(t, key('settings'), 'Settings ($device)');
      final sl = find.descendant(of: key('settings-list'), matching: find.byType(Scrollable)).first;
      for (var i = 0; i < 5; i++) {
        expectNoTruncatedText(t, 'settings $device $i');
        await t.drag(sl, const Offset(0, -250));
        await t.pump();
      }
      await back(t, 'Settings ($device)');
      await seeIn(t, 'home-list', key('open-calendar'));
      await press(t, key('open-calendar'), 'Calendar ($device)');
      await seeIn(t, 'calendar-list', key('cal-29'));
      await back(t, 'Calendar ($device)');
      // Places with the keyboard up: field keeps focus, results still tappable above the keyboard.
      await press(t, key('place-button'), 'Places ($device)');
      await t.tap(key('place-search'));
      keyboard(t, true);
      await t.pump();
      await t.enterText(key('place-search'), 'spring');
      await t.pump();
      expect(t.widget<EditableText>(find.descendant(of: key('place-search'), matching: find.byType(EditableText))).focusNode.hasFocus,
          isTrue);
      if (device == iphone13) await shot(t, '11-places-keyboard');
      await press(t, key('town-0'), 'Town result with keyboard ($device)');
      keyboard(t, false);
      await t.pump();
      expect(textOf(t, 'place-name'), startsWith('Spring'));
      await finish(t);
    });
  }

  testWidgets('큰 글씨 135% · iPhone SE: 겹침·잘림 없음', (t) async {
    await boot(t, device: 'iPhone SE (750x1334)', textScale: 1.35, prefs: {
      'place': '{"name":"Deer stand by the long creek","detail":"near Fredericksburg, TX","lat":30.27,"lng":-98.87,"tz":"America/Chicago"}',
    });
    await sweepHome(t, 'SE 135%');
    await press(t, key('how-scored'), 'How is this scored? (135%)');
    await press(t, key('score-close'), 'Score sheet · Done (135%)');
    await press(t, key('settings'), 'Settings (135%)');
    final sl = find.descendant(of: key('settings-list'), matching: find.byType(Scrollable)).first;
    for (var i = 0; i < 6; i++) {
      expectNoTruncatedText(t, 'settings 135% $i');
      await t.drag(sl, const Offset(0, -250));
      await t.pump();
    }
    await back(t, 'Settings (135%)');
    await seeIn(t, 'home-list', key('open-calendar'));
    await press(t, key('open-calendar'), 'Calendar unlock (135%)');
    await press(t, key('unlock-watch'), 'Watch (135%)');
    await back(t, 'Calendar (135%)');
    await finish(t);
  });

  testWidgets('하루 24시간 내내: 지금 카드·사냥 카운트다운이 시각에 맞게 바뀐다', (t) async {
    await boot(t, prefs: {'place': '{"name":"Austin, TX","lat":30.267,"lng":-97.743,"tz":"America/Chicago"}'});
    final z = PlaceZone('America/Chicago');
    for (var h = 0; h < 24; h++) {
      clockNow = z.fromWall(DateTime.utc(2026, 10, 2, h, 10));
      await t.pump(const Duration(seconds: 21)); // the screen's own tick
      final days = SolunarDay.week(austin, clockNow, count: 3);
      final l = days.first.legalLight(30, 30)!;
      await seeIn(t, 'home-list', key('legal-label'));
      final label = textOf(t, 'legal-label');
      if (clockNow.isBefore(l.start)) {
        expect(label, 'Shooting light starts in', reason: 'h=$h');
      } else if (clockNow.isBefore(l.end)) {
        expect(label, 'Shooting light ends in', reason: 'h=$h');
      } else {
        expect(label, startsWith('Shooting light ended'), reason: 'h=$h');
        expect(textOf(t, 'legal-big'), startsWith('Tomorrow'));
      }
      final s = NowStatus.at(clockNow, days);
      await t.drag(find.descendant(of: key('home-list'), matching: find.byType(Scrollable)).first, const Offset(0, 5000));
      await t.pump();
      expect(textOf(t, 'now-title'),
          s.current != null ? '${s.current!.kind.label.toUpperCase()} PERIOD NOW' : 'NEXT: ${s.next!.kind.label.toUpperCase()} PERIOD',
          reason: 'h=$h');
      expectNoTruncatedText(t, 'h=$h');
      pressed.add('clock ${h.toString().padLeft(2, '0')}:10');
    }
    await finish(t);
  });

  testWidgets('자정이 지나면 "오늘"이 다음 날로 바뀐다 (앱을 켜 둔 채)', (t) async {
    await boot(t, prefs: {'place': '{"name":"Austin, TX","lat":30.267,"lng":-97.743,"tz":"America/Chicago"}'});
    await press(t, key('day-2'), 'Week strip day 2');
    clockNow = DateTime.utc(2026, 10, 3, 5, 1); // 12:01 AM CDT Oct 3
    await t.pump(const Duration(seconds: 21));
    expect(textOf(t, 'day-title'), 'Tomorrow · Sun, Oct 4', reason: 'the picked day stays, now "tomorrow"');
    await press(t, key('day-0'), 'Week strip Today (new day)');
    expect(textOf(t, 'day-title'), 'Today · Sat, Oct 3');
    clockNow = DateTime.utc(2026, 10, 5, 6); // two days later: the picked day is in the past
    await t.pump(const Duration(seconds: 21));
    expect(textOf(t, 'day-title'), 'Today · Mon, Oct 5');
    await finish(t);
  });

  testWidgets('광고 실패 경로: 중간에 닫음 / 영상 없음 / 늦게 옴', (t) async {
    final place = {'place': '{"name":"Austin, TX","lat":30.267,"lng":-97.743,"tz":"America/Chicago"}'};
    await boot(t, prefs: place, ads: FakeAds(result: RewardResult.closedEarly));
    await seeIn(t, 'home-list', key('open-calendar'));
    await press(t, key('open-calendar'), 'Calendar (video closed early)');
    await press(t, key('unlock-watch'), 'Watch → closed early');
    expect(AppStore.i.calendarOpen, isFalse);
    expect(find.textContaining('closed early'), findsOneWidget);
    expect(key('calendar-list'), findsNothing);
    await finish(t);

    await boot(t, prefs: place, ads: FakeAds(result: RewardResult.unavailable, ready: false, delay: const Duration(seconds: 8)));
    await seeIn(t, 'home-list', key('open-calendar'));
    await press(t, key('open-calendar'), 'Calendar (no video)');
    await t.tap(key('unlock-watch'));
    pressed.add('Watch → no video');
    await t.pump(const Duration(milliseconds: 300));
    expect(key('video-loading'), findsOneWidget, reason: 'loading shown while waiting');
    await t.pump(const Duration(seconds: 8));
    await settle(t);
    expect(key('video-loading'), findsNothing);
    expect(AppStore.i.calendarOpen, isTrue, reason: 'no ad to show → open anyway');
    expect(key('calendar-list'), findsOneWidget);
    await back(t, 'Calendar (no video)');
    await finish(t);

    await boot(t, prefs: place, ads: FakeAds(ready: false, delay: const Duration(seconds: 3)));
    await seeIn(t, 'home-list', key('open-calendar'));
    await press(t, key('open-calendar'), 'Calendar (slow video)');
    await t.tap(key('unlock-watch'));
    pressed.add('Watch → slow video');
    await t.pump(const Duration(milliseconds: 300));
    expect(key('video-loading'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    await settle(t);
    expect(AppStore.i.calendarOpen, isTrue);
    expect(key('calendar-list'), findsOneWidget);
    await finish(t);
  });

  testWidgets('어디서나: 북극권 한겨울·하와이·애리조나·캐나다·남반구 기기 시간대', (t) async {
    final spots = [
      ('{"name":"Utqiagvik, AK","lat":71.291,"lng":-156.789,"tz":"America/Anchorage"}', DateTime.utc(2026, 12, 15, 21), 'AKST'),
      ('{"name":"Utqiagvik, AK","lat":71.291,"lng":-156.789,"tz":"America/Anchorage"}', DateTime.utc(2026, 6, 21, 21), 'AKDT'),
      ('{"name":"Honolulu, HI","lat":21.307,"lng":-157.858,"tz":"Pacific/Honolulu"}', testNow, 'HST'),
      ('{"name":"Phoenix, AZ","lat":33.448,"lng":-112.074,"tz":"America/Phoenix"}', testNow, 'MST'),
      ('{"name":"Thunder Bay, ON","lat":48.382,"lng":-89.246,"tz":"America/Toronto"}', testNow, 'EDT'),
    ];
    for (final (json, now, abbr) in spots) {
      await boot(t, now: now, prefs: {'place': json});
      expect(textOf(t, 'place-detail'), abbr);
      await sweepHome(t, abbr);
      await seeIn(t, 'home-list', key('legal-big'));
      if (abbr == 'AKST') expect(textOf(t, 'legal-big'), 'No sunrise today');
      if (abbr == 'AKDT') expect(textOf(t, 'legal-big'), 'Sun up all day');
      for (var i = 1; i < 7; i++) {
        await press(t, key('day-$i'), 'Week strip day $i ($abbr)');
      }
      await finish(t);
    }
    // GPS on a phone set to Sydney time: times follow the phone's zone.
    await boot(t, location: const LocationResult.found(-33.87, 151.21), deviceZone: 'Australia/Sydney');
    await press(t, key('welcome-near-me'), 'Use My Location (Sydney)');
    expect(textOf(t, 'place-detail'), 'AEST');
    expect(textOf(t, 'place-name'), 'My Location');
    await sweepHome(t, 'Sydney');
    await finish(t);
  });

  testWidgets('저장한 곳 20개 · 긴 이름: 목록이 끝까지 내려가고 지우기가 된다', (t) async {
    final favs = [
      for (var i = 0; i < 20; i++)
        '{"name":"Spot number $i with a really long name by the creek","lat":${30 + i * 0.1},"lng":-97.7,"tz":"America/Chicago"}',
    ];
    await boot(t, prefs: {
      'place': '{"name":"Austin, TX","lat":30.267,"lng":-97.743,"tz":"America/Chicago"}',
      'favorites': '[${favs.join(',')}]',
    });
    await press(t, key('place-button'), 'Places (20 saved)');
    await seeIn(t, 'places-list', key('fav-19'));
    await press(t, key('fav-del-19'), 'Delete saved #20');
    expect(AppStore.i.favorites.length, 19);
    await seeIn(t, 'places-list', key('fav-10'));
    await press(t, key('fav-10'), 'Saved place #11');
    expect(textOf(t, 'place-name'), startsWith('Spot number 10'));
    await finish(t);
  });
}
