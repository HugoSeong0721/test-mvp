// 테스트 로봇 — 모든 화면의 모든 버튼을 실제로 눌러 본다. GPS 는 가짜 위치를 1초마다 넣는다.
// 막힌 길(버튼이 가려져 안 눌림)·뒤로가기 불가·깨진 레이아웃(overflow 는 Flutter 가 예외로 던져 테스트 실패)을 잡는다.
// 실행: flutter test test/robot_test.dart  → 누른 버튼 목록이 로그로 찍힌다.
// (텍스트 입력칸이 없는 앱이라 키보드가 뜨는 상태는 해당 없음)
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedometer/app.dart';
import 'package:speedometer/core/ads.dart';
import 'package:speedometer/core/device.dart';
import 'package:speedometer/core/engine.dart';
import 'package:speedometer/core/location.dart';
import 'package:speedometer/core/prefs.dart';
import 'package:speedometer/core/units.dart';
import 'package:speedometer/screens/hud_screen.dart';
import 'package:speedometer/screens/settings_sheet.dart';

final pressed = <String>[];

/// 실제 기기 크기 (논리 픽셀 × 배율)
const devices = {
  'iPhone 13 (1170x2532)': (Size(390, 844), 3.0),
  'iPhone SE (750x1334)': (Size(375, 667), 2.0),
  'iPhone 15 Pro Max (1290x2796)': (Size(430, 932), 3.0),
};

late FakeLocationSource loc;
late FakeDeviceIO io;
late Prefs prefs;
final opened = <Uri>[];
double lat = 37.0;

var _fontsLoaded = false;

/// 테스트 기본 글꼴(Ahem)은 모든 글자가 정사각형이라 실제보다 훨씬 넓다 → 잘림 검사가 틀린다.
/// SDK 에 들어 있는 Roboto(아이폰 SF 와 폭이 비슷)를 넣어 실제 글자 폭으로 잰다 (대출 세션 노하우).
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final root =
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts';
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final file = File('$root/$f');
      if (!file.existsSync()) {
        // ignore: avoid_print
        print(
          'WARNING: font not found $root/$f — truncation checks use test font',
        );
        return;
      }
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
    await loader.load();
  }

  await family('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]);
  await family('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

Future<void> boot(
  WidgetTester t, {
  Size size = const Size(390, 844),
  double ratio = 3,
  Map<String, Object> initial = const {'seenSafety': true},
  Access access = Access.granted,
  Access? afterRequest,
  bool precise = true,
  double textScale = 1,
  bool keepPrefs = false,
}) async {
  await t.runAsync(loadFonts);
  t.view.physicalSize = size * ratio;
  t.view.devicePixelRatio = ratio;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  if (!keepPrefs) SharedPreferences.setMockInitialValues(initial);
  Ads.i = FakeAds();
  openLink = (u) async => opened.add(u);
  loc = FakeLocationSource(access: access, afterRequest: afterRequest)
    ..precise = precise;
  io = FakeDeviceIO();
  prefs = await Prefs.load();
  await t.pumpWidget(
    SpeedApp(key: UniqueKey(), source: loc, prefs: prefs, io: io),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

/// 버튼이 화면 안에 있고, 위에 다른 게 덮여 있지 않은지 확인하고 누른다.
Future<void> press(WidgetTester t, Finder f, String label) async {
  expect(f, findsOneWidget, reason: 'button not found: $label');
  final center = t.getCenter(f);
  final screen = Offset.zero & t.view.physicalSize / t.view.devicePixelRatio;
  expect(
    screen.contains(center),
    isTrue,
    reason: 'button off screen: $label at $center',
  );
  final ro = t.renderObject(f);
  final hit = t.hitTestOnBinding(center);
  expect(
    hit.path.any((e) => identical(e.target, ro)),
    isTrue,
    reason: 'button covered / not tappable: $label',
  );
  await t.tap(f);
  pressed.add(label);
  await t.pump();
  await t.pump(const Duration(milliseconds: 350));
  await t.pump(const Duration(milliseconds: 350));
  expectNoTruncatedText(t, 'after $label');
}

/// 화면의 글자가 '…' 이나 잘림으로 끊기지 않았는지 (대출 세션 노하우 — 큰 값·작은 화면에서만 드러난다).
void expectNoTruncatedText(WidgetTester t, String where) {
  for (final e in find.byType(RichText).evaluate()) {
    final ro = e.renderObject;
    if (ro is RenderParagraph && ro.attached) {
      expect(
        ro.didExceedMaxLines,
        isFalse,
        reason: 'truncated text $where: "${ro.text.toPlainText()}"',
      );
    }
  }
}

/// [mph] 로 [secs] 초 달린다 (1초마다 GPS 측정 1번).
Future<void> drive(
  WidgetTester t,
  double mph,
  int secs, {
  double acc = 5,
  bool report = true,
}) async {
  final ms = SpeedUnit.mph.toMs(mph);
  for (var i = 0; i < secs; i++) {
    await t.pump(const Duration(seconds: 1));
    lat += ms / 111195.08;
    loc.emit(
      Fix(
        lat: lat,
        lon: 127,
        accuracy: acc,
        time: clock.now(),
        speed: report ? ms : null,
      ),
    );
    // 위치 이벤트는 마이크로태스크로 온다 → Duration.zero 로 흘려보낸 뒤 화면을 그린다.
    await t.pump(Duration.zero);
  }
}

String speedText(WidgetTester t, [String key = 'speed']) =>
    t.widget<Text>(find.byKey(Key(key))).data!;
String gpsText(WidgetTester t) =>
    t.widget<Text>(find.byKey(const Key('gps'))).data!;
Finder key(String k) => find.byKey(Key(k));

/// 이동 기록 칸 (StatTile 은 숫자+단위를 한 줄 rich text 로 그린다).
Finder stat(String text) => find.text(text, findRichText: true);

void main() {
  tearDownAll(() {
    // ignore: avoid_print
    print(
      '\n누른 버튼 ${pressed.length}번 (${pressed.toSet().length}종):\n  ${pressed.toSet().join(', ')}',
    );
  });

  testWidgets('first run: safety notice once → allow location → live speed', (
    t,
  ) async {
    await boot(t, initial: const {}, access: Access.unknown);
    expect(find.text('Before you drive'), findsOneWidget);
    expect(loc.requests, 0, reason: '안내를 읽기 전엔 권한 창을 띄우지 않는다');
    await press(t, key('accept'), 'I Understand — Allow Location');
    expect(loc.requests, 1);
    expect(prefs.seenSafety, isTrue);
    expect(gpsText(t), 'Searching for GPS…');
    expect(speedText(t), '--');
    expect(io.awake, isTrue, reason: '화면 꺼짐 방지');
    await drive(t, 30, 3);
    expect(speedText(t), '30');
    expect(gpsText(t), 'GPS · ±5 m');
    // 다시 켜면 안내 없이 바로 속도계
    await boot(t, keepPrefs: true);
    expect(find.text('Before you drive'), findsNothing);
    expect(key('speed'), findsOneWidget);
  });

  for (final entry in devices.entries) {
    testWidgets('every button on every screen — ${entry.key}', (t) async {
      final (size, ratio) = entry.value;
      await boot(t, size: size, ratio: ratio);
      await drive(t, 45, 3);
      expect(speedText(t), '45');
      expect(key('banner'), findsOneWidget);

      // 모드 4개
      for (final m in [Mode.bike, Mode.run, Mode.boat, Mode.car]) {
        await press(t, key('mode-${m.name}'), '${m.label} mode');
        await drive(t, 20, 1);
        expect(prefs.mode, m);
      }
      expect(
        loc.watchedModes.last,
        Mode.car,
        reason: '모드를 바꾸면 iOS 이동 종류도 바꿔 다시 받는다',
      );

      // 단위 글자 탭 → km/h → mph
      await press(t, key('unit'), 'Unit pill');
      expect(prefs.unitFor(Mode.car), SpeedUnit.kmh);
      await press(t, key('unit'), 'Unit pill');
      expect(prefs.unitFor(Mode.car), SpeedUnit.mph);

      // 게이지 ↔ 숫자
      await press(t, key('display'), 'Gauge');
      expect(key('gauge'), findsOneWidget);
      await drive(t, 50, 2);
      expect(speedText(t), '50');
      await press(t, key('unit'), 'Unit pill (gauge)');
      await press(t, key('unit'), 'Unit pill (gauge)');
      await press(t, key('display'), 'Digits');
      expect(key('gauge'), findsNothing);

      // 경고 시트의 모든 버튼
      await press(t, key('alert'), 'Alert button');
      await press(t, key('alert-switch'), 'Alert switch');
      expect(prefs.alertOn(Mode.car), isTrue);
      expect(io.beeps, 1, reason: '켤 때 소리 미리 듣기');
      expect(t.widget<Text>(key('alert-value')).data, '65');
      await press(t, key('alert-plus'), '+1');
      await press(t, key('alert-plus5'), '+5');
      expect(t.widget<Text>(key('alert-value')).data, '71');
      await press(t, key('alert-minus'), '−1');
      await press(t, key('alert-minus5'), '−5');
      expect(t.widget<Text>(key('alert-value')).data, '65');
      await press(t, key('sound-switch'), 'Sound switch');
      expect(prefs.sound, isFalse);
      await press(t, key('sound-switch'), 'Sound switch');
      expect(prefs.sound, isTrue);
      await press(t, key('alert-done'), 'Alert Done');
      expect(key('alert-done'), findsNothing);
      expect(find.text('Alert 65 MPH'), findsOneWidget);

      // 설정 시트의 모든 버튼
      await press(t, key('settings'), 'Settings');
      await press(t, key('unit-kmh'), 'Units KM/H');
      expect(prefs.unitFor(Mode.car), SpeedUnit.kmh);
      await press(t, key('unit-mph'), 'Units MPH');
      await press(t, key('display-gauge'), 'Display Gauge');
      expect(prefs.display, Display.gauge);
      await press(t, key('display-digital'), 'Display Digits');
      await press(t, key('mirror-switch'), 'Mirror switch');
      expect(prefs.hudMirror, isFalse);
      await press(t, key('mirror-switch'), 'Mirror switch');
      await press(t, key('safety'), 'Driving safety');
      expect(find.text('Driving safety'), findsWidgets);
      await press(t, key('safety-ok'), 'Safety OK');
      await press(t, key('privacy'), 'Privacy Policy');
      expect(opened.last.toString(), privacyUrl);
      await press(t, key('settings-done'), 'Settings Done');
      expect(key('settings-done'), findsNothing);

      // HUD — 반전, 광고 없음, 버튼은 탭하면 다시 나옴, 나가기
      await press(t, key('hud'), 'HUD');
      expect(find.byType(HudScreen), findsOneWidget);
      expect(key('banner'), findsNothing, reason: 'HUD 에는 광고가 없다');
      expect(
        t
            .widget<Transform>(
              find
                  .ancestor(
                    of: key('hud-speed'),
                    matching: find.byType(Transform),
                  )
                  .first,
            )
            .transform
            .storage[0],
        -1,
        reason: '좌우 반전',
      );
      await drive(t, 40, 2);
      expect(speedText(t, 'hud-speed'), '40');
      await press(t, key('hud-mirror'), 'HUD Mirror');
      expect(prefs.hudMirror, isFalse);
      await press(t, key('hud-mirror'), 'HUD Mirror');
      await t.pump(HudScreen.controlsFor + const Duration(seconds: 1));
      await press(t, key('hud-area'), 'HUD tap (show controls)');
      await press(t, key('hud-exit'), 'Exit HUD');
      expect(find.byType(HudScreen), findsNothing);

      // 기록 초기화 — 취소 / 확인
      await press(t, key('reset'), 'Reset');
      await press(t, key('reset-cancel'), 'Reset Cancel');
      expect(find.text('Reset trip?'), findsNothing);
      await press(t, key('reset'), 'Reset');
      await press(t, key('reset-confirm'), 'Reset Confirm');
      expect(stat('0.00 mi'), findsOneWidget);
    });
  }

  testWidgets('large text (iPhone SE, 135%) — no broken layout', (t) async {
    await boot(t, size: const Size(375, 667), ratio: 2, textScale: 1.35);
    await drive(t, 88, 2);
    await press(t, key('mode-run'), 'Run mode');
    await drive(t, 7, 2);
    await press(t, key('display'), 'Gauge');
    await press(t, key('alert'), 'Alert button');
    await press(t, key('alert-done'), 'Alert Done');
    await press(t, key('settings'), 'Settings');
    await press(t, key('settings-done'), 'Settings Done');
  });

  testWidgets(
    'longest labels (km/h, alert 155, boat) fit on iPhone SE at 135% text',
    (t) async {
      await boot(
        t,
        size: const Size(375, 667),
        ratio: 2,
        textScale: 1.35,
        initial: {
          'seenSafety': true,
          'unit_car': 'kmh',
          'alertOn_car': true,
          'alertMs_car': SpeedUnit.kmh.toMs(155),
        },
      );
      await drive(t, 99, 3);
      expect(find.text('Alert 155 KM/H'), findsOneWidget);
      expectNoTruncatedText(t, 'main km/h');
      await press(t, key('display'), 'Gauge');
      await press(t, key('mode-boat'), 'Boat mode');
      await press(t, key('unit'), 'Unit pill');
      await press(t, key('unit'), 'Unit pill');
      await press(t, key('hud'), 'HUD');
      await press(t, key('hud-exit'), 'Exit HUD');
    },
  );

  testWidgets('speed alert: red screen + beep, repeats, clears when slower', (
    t,
  ) async {
    await boot(t, initial: const {'seenSafety': true, 'alertOn_car': true});
    await drive(t, 60, 3);
    expect(key('over-label'), findsNothing);
    await drive(t, 70, 1);
    expect(key('over-label'), findsNothing, reason: '한 번으로는 안 울린다');
    await drive(t, 70, 1);
    expect(find.text('Over your 65 MPH alert'), findsOneWidget);
    expect(io.beeps, 1);
    expect(io.buzzes, 1);
    await drive(t, 70, 16);
    expect(io.beeps, 2, reason: '넘은 채로 15초 지나면 한 번 더');
    await drive(t, 65, 2);
    expect(key('over-label'), findsOneWidget, reason: '경계값에선 유지');
    await drive(t, 62, 1);
    expect(key('over-label'), findsNothing);
    // 소리 끔 → 진동만
    prefs.sound = false;
    await drive(t, 72, 2);
    expect(io.beeps, 2);
    expect(io.buzzes, 3);
  });

  testWidgets('weak GPS is shown honestly, lost signal shows --', (t) async {
    await boot(t);
    await drive(t, 30, 2, acc: 60);
    expect(gpsText(t), 'Weak GPS · ±60 m');
    expect(speedText(t), '30');
    final op = t.widget<Opacity>(
      find.ancestor(of: key('speed'), matching: find.byType(Opacity)).first,
    );
    expect(op.opacity, lessThan(1));
    await drive(t, 30, 2);
    expect(gpsText(t), 'GPS · ±5 m');
    await t.pump(const Duration(seconds: 6));
    expect(gpsText(t), 'No GPS signal');
    expect(speedText(t), '--');
  });

  testWidgets('trip: 1 mile at 60 mph, survives restart, reset clears', (
    t,
  ) async {
    await boot(t);
    await drive(t, 60, 61);
    expect(stat('1.00 mi'), findsOneWidget);
    expect(stat('60 mph'), findsNWidgets(2), reason: 'MAX 60, AVG 60');
    // 1초 시계와 GPS 측정의 위상 차이로 0:59 또는 1:00
    expect(stat('1:00').evaluate().length + stat('0:59').evaluate().length, 1);
    await t.pump(const Duration(seconds: 11)); // 10초마다 저장
    await boot(t, keepPrefs: true);
    expect(stat('1.00 mi'), findsOneWidget, reason: '앱을 껐다 켜도 기록 유지');
    await press(t, key('reset'), 'Reset');
    await press(t, key('reset-confirm'), 'Reset Confirm');
    expect(stat('0.00 mi'), findsOneWidget);
    expect(stat('0:00'), findsOneWidget);
  });

  testWidgets('trips are kept per mode (car max never becomes a run pace)', (
    t,
  ) async {
    // 점검 스크린샷에서 발견: 차로 72 mph 달린 뒤 달리기로 바꾸면 BEST 0:50/mi 가 나왔다.
    await boot(t);
    await drive(t, 60, 20);
    await press(t, key('mode-run'), 'Run mode');
    expect(stat('--:--'), findsNWidgets(2), reason: '달리기 기록은 비어 있어야');
    expect(stat('0.00 mi'), findsOneWidget);
    await drive(t, 7.5, 10);
    expect(stat('8:00'), findsWidgets);
    await press(t, key('mode-car'), 'Car mode');
    expect(stat('60 mph'), findsWidgets, reason: '차 기록은 그대로');
  });

  testWidgets('units: km/h, boat knots, run pace', (t) async {
    await boot(t);
    await drive(t, 60, 2);
    await press(t, key('unit'), 'Unit pill');
    expect(speedText(t), '97');
    expect(find.text('KM/H'), findsOneWidget);
    await press(t, key('mode-boat'), 'Boat mode');
    await drive(t, 60, 2);
    expect(find.text('KNOTS'), findsOneWidget);
    expect(speedText(t), '52');
    expect(find.textContaining(' nm', findRichText: true), findsOneWidget);
    await press(t, key('mode-run'), 'Run mode');
    await drive(t, 7.5, 2);
    expect(speedText(t), '8:00');
    expect(find.text('MIN/MI'), findsOneWidget);
    expect(speedText(t, 'run-speed'), '7.5 MPH');
    await press(t, key('mode-bike'), 'Bike mode');
    await drive(t, 15.3, 2);
    expect(speedText(t), '15.3');
  });

  testWidgets('location blocked → Open Settings → allowed → works', (t) async {
    await boot(t, access: Access.blocked);
    expect(find.text('Location is off for this app'), findsOneWidget);
    expect(key('speed'), findsNothing);
    await press(t, key('open-settings'), 'Open Settings');
    expect(loc.settingsOpened, 1);
    // 설정에서 허용하고 돌아옴
    loc.access = Access.granted;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pump();
    await drive(t, 25, 2);
    expect(speedText(t), '25');
  });

  testWidgets('first run, user taps Don’t Allow → clear way forward', (
    t,
  ) async {
    await boot(
      t,
      initial: const {},
      access: Access.unknown,
      afterRequest: Access.blocked,
    );
    await press(t, key('accept'), 'I Understand — Allow Location');
    expect(find.text('Location is off for this app'), findsOneWidget);
    expect(key('open-settings'), findsOneWidget);
  });

  testWidgets('not asked yet → Allow Location button prompts', (t) async {
    await boot(t, access: Access.denied, afterRequest: Access.denied);
    // 앱이 켜질 때 한 번 물어봤고 거절됨 → 버튼으로 다시
    expect(find.text('Location needed'), findsOneWidget);
    loc.afterRequest = Access.granted;
    await press(t, key('allow'), 'Allow Location');
    expect(loc.requests, 2);
    expect(key('speed'), findsOneWidget);
  });

  testWidgets('location services off → Open Settings', (t) async {
    await boot(t, access: Access.servicesOff);
    expect(find.text('Location Services are off'), findsOneWidget);
    await press(t, key('open-settings'), 'Open Settings');
    expect(loc.settingsOpened, 1);
  });

  testWidgets('precise location off → warning + Fix button', (t) async {
    await boot(t, precise: false);
    expect(find.textContaining('Precise Location is off'), findsOneWidget);
    await press(t, key('fix-precise'), 'Fix precise location');
    expect(loc.settingsOpened, 1);
  });

  testWidgets('background stops GPS + screen-on, resume restarts', (t) async {
    await boot(t);
    await drive(t, 30, 2);
    expect(loc.listening, isTrue);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    expect(loc.listening, isFalse);
    expect(io.awake, isFalse);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pump();
    expect(loc.listening, isTrue);
    expect(io.awake, isTrue);
    expect(gpsText(t), 'Searching for GPS…', reason: '돌아오면 옛 숫자 대신 새로 찾는 중');
    expect(speedText(t), '--');
    await drive(t, 33, 2);
    expect(speedText(t), '33');
  });

  testWidgets('GPS error mid-drive → re-checks permission, no crash', (
    t,
  ) async {
    await boot(t);
    await drive(t, 30, 2);
    loc.access = Access.blocked;
    loc.fail(StateError('denied'));
    await t.pump();
    await t.pump();
    expect(find.text('Location is off for this app'), findsOneWidget);
  });

  testWidgets('standing still at a light shows 0, not jumping numbers', (
    t,
  ) async {
    await boot(t);
    await drive(t, 30, 3);
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(seconds: 1));
      loc.emit(
        Fix(
          lat: lat + (i.isEven ? 2 : -2) / 111195,
          lon: 127,
          accuracy: 8,
          time: clock.now(),
          speed: i.isEven ? 0.4 : 0.2,
        ),
      );
      await t.pump(Duration.zero);
    }
    expect(speedText(t), '0');
  });
}
