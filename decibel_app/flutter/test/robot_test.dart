// 테스트 로봇 — 모든 화면의 모든 버튼을 실제로 눌러 본다.
// 막힌 길(버튼이 안 먹음)·뒤로가기 불가·깨진 레이아웃(overflow 는 Flutter 가 예외로 던져 테스트 실패)을 잡는다.
// 마이크는 가짜(정해 둔 크기의 1 kHz 사인파)라서 화면 숫자가 계산대로 나오는지까지 확인한다.
// 실행: flutter test test/robot_test.dart  → 누른 버튼 목록이 로그로 찍힌다.
import 'dart:typed_data';

import 'package:decibel/core/ads.dart';
import 'package:decibel/core/mic.dart';
import 'package:decibel/core/share.dart';
import 'package:decibel/core/store.dart';
import 'package:decibel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pressed = <String>[];
final screens = <String>{};

/// 실제 기기 크기 (논리 픽셀 × 배율)
const devices = {
  'iPhone 13 (1170x2532)': (Size(390, 844), 3.0),
  'iPhone SE (750x1334)': (Size(375, 667), 2.0),
  'iPhone 15 Pro Max (1290x2796)': (Size(430, 932), 3.0),
};

late FakeSource mic;
late FakeOutside outside;

Future<void> boot(
  WidgetTester t, {
  Size size = const Size(390, 844),
  double ratio = 3,
  Map<String, Object> prefs = const {'seenIntro': true},
  bool granted = true,
  double level = -40,
}) async {
  t.view.physicalSize = size * ratio;
  t.view.devicePixelRatio = ratio;
  t.view.padding = FakeViewPadding(top: 47 * ratio, bottom: 34 * ratio);
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  Ads.i = FakeAds();
  mic = FakeSource(granted: granted, level: level);
  SoundSource.i = mic;
  outside = FakeOutside();
  Outside.i = outside;
  await AppStore.i.load();
  AppStore.i.clock = () => DateTime(2026, 10, 2, 22, 41, 0);
  await t.pumpWidget(const DecibelApp());
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> press(WidgetTester t, Finder f, String label) async {
  expect(f, findsOneWidget, reason: 'button not found: $label');
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  pressed.add(label);
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> back(WidgetTester t, String from) async {
  final nav = find.byType(BackButton);
  expect(nav, findsOneWidget, reason: 'no back button on $from');
  await press(t, nav, '$from: Back');
}

/// 가짜 마이크로 [seconds] 초 동안 측정한다.
Future<void> listen(WidgetTester t, double seconds) async {
  for (var i = 0; i < (seconds * 4).round(); i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

String textOf(WidgetTester t, Key k) {
  final w = t.widget<Text>(find.byKey(k));
  return w.data ?? w.textSpan?.toPlainText() ?? '';
}

/// 화면의 모든 글자에 한글이 섞이지 않았는지 (앱 UI 는 전부 영어).
void noKorean(WidgetTester t, String screen) {
  screens.add(screen);
  final ko = RegExp(r'[가-힣]');
  for (final e in find.byType(RichText).evaluate()) {
    final s = (e.widget as RichText).text.toPlainText();
    expect(ko.hasMatch(s), isFalse, reason: 'Korean text on $screen: $s');
  }
}

Future<void> finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  tearDownAll(() {
    // ignore: avoid_print
    print(
      'ROBOT pressed ${pressed.length} buttons on ${screens.length} screens:\n'
      '  screens: ${screens.join(', ')}\n'
      '  buttons: ${pressed.toSet().join(', ')}',
    );
  });

  testWidgets(
    'first launch: intro → Continue asks for the mic and starts measuring',
    (t) async {
      await boot(t, prefs: const {});
      expect(find.text('How loud is it\naround you?'), findsOneWidget);
      noKorean(t, 'Intro');
      expect(mic.asked, isFalse, reason: 'must not ask before Continue');
      await press(
        t,
        find.byKey(const Key('intro-continue')),
        'Intro: Continue',
      );
      expect(mic.asked, isTrue);
      expect(mic.running, isTrue);
      await listen(t, 2);
      expect(textOf(t, const Key('current')), '54'); // -40 dBFS + 94
      // 두 번째 실행에는 안내가 안 뜬다
      await finish(t);
      await t.pumpWidget(const DecibelApp());
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('How loud is it\naround you?'), findsNothing);
      expect(find.byKey(const Key('main')), findsOneWidget);
      await finish(t);
    },
  );

  testWidgets('meter: start, real numbers, pause, resume, reset, report', (
    t,
  ) async {
    await boot(t);
    noKorean(t, 'Meter (idle)');
    expect(textOf(t, const Key('like')), 'Tap Start to measure');
    // 아무것도 없을 때 Reset·Report 는 눌러도 아무 일 없음 (막혀 있음이 보임)
    await t.tap(find.byKey(const Key('report')));
    await t.pump();
    expect(find.text('Noise Report'), findsNothing);

    await press(t, find.byKey(const Key('main')), 'Meter: Start');
    await listen(t, 3);
    expect(textOf(t, const Key('current')), '54');
    expect(find.text('Moderate'), findsOneWidget);
    expect(textOf(t, const Key('like')), 'Like moderate rain');
    noKorean(t, 'Meter (running)');

    mic.level = -20; // 74 dBA
    await listen(t, 2);
    expect(textOf(t, const Key('current')), '74');
    expect(find.text('Like a vacuum cleaner'), findsOneWidget);

    await press(t, find.byKey(const Key('main')), 'Meter: Pause');
    expect(mic.running, isFalse);
    expect(textOf(t, const Key('notice')), contains('Paused'));
    expect(
      AppStore.i.records,
      hasLength(1),
      reason: 'pause saves automatically',
    );
    final secsAtPause = AppStore.i.records.first.leq.length;

    await press(t, find.byKey(const Key('main')), 'Meter: Resume');
    expect(mic.running, isTrue);
    await listen(t, 3);
    await press(t, find.byKey(const Key('report')), 'Meter: Report');
    expect(find.text('Noise Report'), findsWidgets);
    noKorean(t, 'Report');
    final r = AppStore.i.records.first;
    expect(r.leq.length, greaterThan(secsAtPause));
    expect(find.text('Fri, Oct 2, 2026'), findsOneWidget);
    expect(textOf(t, const Key('report-time')), startsWith('10:41 PM'));
    expect(r.max, closeTo(74, 0.6));
    // 레벨별 시간 막대가 실제로 칠해진다 (높이 0 으로 사라졌던 버그)
    final segs = find.descendant(
      of: find.byKey(const Key('band-bar')),
      matching: find.byType(ColoredBox),
    );
    expect(segs, findsWidgets);
    for (final e in segs.evaluate()) {
      expect((e.renderObject! as RenderBox).size.height, 10);
    }
    await back(t, 'Report');

    // 완전한 무음(디지털 0)은 숫자 대신 "<20" — 바닥 아래를 지어내지 않는다
    mic.level = -400;
    await listen(t, 2);
    expect(textOf(t, const Key('current')), '<20');

    await press(t, find.byKey(const Key('reset')), 'Meter: Reset');
    expect(mic.running, isFalse);
    expect(textOf(t, const Key('current')), '--');
    expect(textOf(t, const Key('like')), 'Tap Start to measure');
    expect(
      AppStore.i.records,
      hasLength(1),
      reason: 'reset keeps the saved measurement',
    );
    await finish(t);
  });

  testWidgets('report: note with keyboard up, share image, back', (t) async {
    await boot(t);
    await press(t, find.byKey(const Key('main')), 'Meter: Start');
    await listen(t, 6);
    await press(t, find.byKey(const Key('report')), 'Meter: Report');

    // 키보드가 뜬 상태 (아이폰 13 키보드 ≈ 336pt)
    await t.tap(find.byKey(const Key('note')));
    t.view.viewInsets = FakeViewPadding(bottom: 336 * 3.0);
    addTearDown(t.view.resetViewInsets);
    await t.pump(const Duration(milliseconds: 300));
    await t.enterText(
      find.byKey(const Key('note')),
      'Upstairs neighbor, Apt 4B',
    );
    pressed.add('Report: type note (keyboard up)');
    await t.pump(const Duration(milliseconds: 700));
    final field = t.getRect(find.byKey(const Key('note')));
    expect(
      field.bottom,
      lessThanOrEqualTo(844 - 336 + 1),
      reason: 'note field hidden behind keyboard',
    );
    expect(find.byKey(const Key('report-note')), findsOneWidget);
    noKorean(t, 'Report (keyboard)');
    t.view.resetViewInsets();
    await t.pump(const Duration(milliseconds: 300));

    // 이미지 만들기는 진짜 비동기라 runAsync 로 기다린다
    await t.ensureVisible(find.byKey(const Key('share')));
    await t.pump();
    await t.tap(find.byKey(const Key('share')));
    pressed.add('Report: Save or Share Image');
    for (var i = 0; i < 10 && outside.lastImage == null; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pump();
    }
    expect(outside.calls.single, 'share:noise-report-2026-10-02-2241.png');
    final png = outside.lastImage!;
    expect(
      png.sublist(0, 4),
      Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
      reason: 'PNG header',
    );
    // 이미지 폭 = 리포트 카드 폭(390 - 좌우 16×2) × 3배
    final width = ByteData.sublistView(png, 16, 20).getUint32(0);
    expect(width, (390 - 32) * 3);
    await t.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Save or Share Image'),
      findsOneWidget,
      reason: 'button returns after sharing',
    );

    // 공유 실패 → 안내
    outside.ok = false;
    await t.tap(find.byKey(const Key('share')));
    for (var i = 0; i < 10 && outside.calls.length < 2; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pump();
    }
    await t.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Could not share the image. Please try again.'),
      findsOneWidget,
    );
    pressed.add('Report: share fails → message');

    await back(t, 'Report');
    await t.pump(const Duration(milliseconds: 800));
    expect(AppStore.i.records.first.note, 'Upstairs neighbor, Apt 4B');
    await finish(t);
  });

  testWidgets('guide: chip opens it, current level is highlighted, back', (
    t,
  ) async {
    await boot(t, level: -14); // 80 dBA
    await press(t, find.byKey(const Key('main')), 'Meter: Start');
    await listen(t, 2);
    await press(t, find.byKey(const Key('guide')), 'Meter: Level guide chip');
    expect(find.text('How loud is that?'), findsOneWidget);
    expect(find.byKey(const Key('guide-here')), findsOneWidget);
    expect(textOf(t, const Key('guide-now')), contains('like a lawnmower'));
    await t.scrollUntilVisible(
      find.text('Hearing safety'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    noKorean(t, 'Guide');
    await back(t, 'Guide');
    expect(find.byKey(const Key('main')), findsOneWidget);
    await finish(t);
  });

  testWidgets('loud average shows the NIOSH notice', (t) async {
    await boot(t, level: -3); // 91 dBA → 2 hr
    await press(t, find.byKey(const Key('main')), 'Meter: Start');
    await listen(t, 3);
    expect(
      textOf(t, const Key('notice')),
      contains('NIOSH suggests no more than 2 hr a day'),
    );
    expect(find.text('Very loud'), findsOneWidget);
    await finish(t);
  });

  testWidgets(
    'mic denied: honest message, Open Settings, retry after enabling',
    (t) async {
      await boot(t, granted: false);
      await press(t, find.byKey(const Key('main')), 'Meter: Start (denied)');
      expect(mic.running, isFalse);
      expect(
        textOf(t, const Key('notice')),
        contains('Microphone access is off'),
      );
      expect(textOf(t, const Key('like')), 'Microphone is off');
      noKorean(t, 'Meter (mic denied)');
      await press(
        t,
        find.byKey(const Key('open-settings')),
        'Meter: Open Settings',
      );
      expect(outside.calls, ['open:app-settings:']);
      // 설정에서 켜고 돌아옴
      mic.granted = true;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('open-settings')), findsNothing);
      await press(
        t,
        find.byKey(const Key('main')),
        'Meter: Start (after enabling)',
      );
      expect(mic.running, isTrue);
      await finish(t);
    },
  );

  testWidgets('leaving the app or a phone call pauses honestly and saves', (
    t,
  ) async {
    await boot(t);
    await press(t, find.byKey(const Key('main')), 'Meter: Start');
    await listen(t, 5);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await t.pump(const Duration(milliseconds: 300));
    expect(mic.running, isFalse);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump(const Duration(milliseconds: 300));
    expect(textOf(t, const Key('notice')), contains('when you leave the app'));
    expect(AppStore.i.records, hasLength(1));

    await press(t, find.byKey(const Key('main')), 'Meter: Resume');
    await listen(t, 2);
    mic.interrupt(); // 전화
    await t.pump(const Duration(milliseconds: 300));
    expect(textOf(t, const Key('notice')), contains('interrupted'));
    expect(find.text('Resume'), findsOneWidget);
    await finish(t);
  });

  testWidgets('long measurement autosaves every 10 s; report of 3 minutes', (
    t,
  ) async {
    await boot(t);
    await press(t, find.byKey(const Key('main')), 'Meter: Start');
    await listen(t, 12);
    expect(AppStore.i.records, hasLength(1), reason: 'autosave while running');
    final first = AppStore.i.records.first.leq.length;
    mic.level = -10;
    await listen(t, 60);
    mic.level = -45;
    await listen(t, 110);
    expect(AppStore.i.records.first.leq.length, greaterThan(first + 150));
    await press(t, find.byKey(const Key('report')), 'Meter: Report (3 min)');
    expect(textOf(t, const Key('report-time')), contains('3 min'));
    expect(textOf(t, const Key('report-loudest')), contains('84'));
    noKorean(t, 'Report (3 min)');
    await back(t, 'Report');
    await finish(t);
  });

  testWidgets(
    'history: list, open report, delete (cancel, then delete), empty',
    (t) async {
      await boot(t);
      await press(t, find.byKey(const Key('history')), 'Meter: History');
      expect(find.byKey(const Key('history-empty')), findsOneWidget);
      noKorean(t, 'History (empty)');
      await back(t, 'History');

      await press(t, find.byKey(const Key('main')), 'Meter: Start');
      await listen(t, 5);
      await press(t, find.byKey(const Key('main')), 'Meter: Pause');
      await press(t, find.byKey(const Key('history')), 'Meter: History');
      final id = AppStore.i.records.single.id;
      noKorean(t, 'History');
      await press(t, find.byKey(Key('record-$id')), 'History: open record');
      expect(find.byKey(const Key('report-card')), findsOneWidget);
      await back(t, 'Report');
      await press(t, find.byKey(Key('delete-$id')), 'History: Delete');
      await press(
        t,
        find.byKey(const Key('delete-cancel')),
        'Delete dialog: Cancel',
      );
      expect(AppStore.i.records, hasLength(1));
      await press(t, find.byKey(Key('delete-$id')), 'History: Delete');
      await press(
        t,
        find.byKey(const Key('delete-ok')),
        'Delete dialog: Delete',
      );
      expect(AppStore.i.records, isEmpty);
      expect(find.byKey(const Key('history-empty')), findsOneWidget);
      await back(t, 'History');
      await finish(t);
    },
  );

  testWidgets(
    'settings: calibration, weighting, keep awake, privacy — and they take effect',
    (t) async {
      await boot(t);
      await press(t, find.byKey(const Key('main')), 'Meter: Start');
      await listen(t, 2);
      expect(textOf(t, const Key('current')), '54');

      await press(t, find.byKey(const Key('settings')), 'Meter: Settings');
      noKorean(t, 'Settings');
      for (var i = 0; i < 4; i++) {
        await press(t, find.byKey(const Key('trim-plus')), 'Settings: +0.5 dB');
      }
      expect(textOf(t, const Key('trim-value')), '+2.0 dB');
      await press(t, find.byKey(const Key('trim-minus')), 'Settings: −0.5 dB');
      expect(textOf(t, const Key('trim-value')), '+1.5 dB');
      await press(
        t,
        find.byKey(const Key('trim-reset')),
        'Settings: Reset calibration',
      );
      expect(textOf(t, const Key('trim-value')), '0.0 dB');
      for (var i = 0; i < 6; i++) {
        await press(t, find.byKey(const Key('trim-plus')), 'Settings: +0.5 dB');
      }
      // 범위 끝까지 눌러도 깨지지 않는다
      for (var i = 0; i < 50; i++) {
        await t.tap(find.byKey(const Key('trim-plus')));
        await t.pump();
      }
      expect(textOf(t, const Key('trim-value')), '+20.0 dB');
      for (var i = 0; i < 36; i++) {
        await t.tap(find.byKey(const Key('trim-minus')));
        await t.pump();
      }
      expect(textOf(t, const Key('trim-value')), '+2.0 dB');

      await press(t, find.text('dBC'), 'Settings: dBC');
      expect(textOf(t, const Key('weighting-help')), contains('bass'));
      await press(t, find.text('dBZ'), 'Settings: dBZ');
      expect(textOf(t, const Key('weighting-help')), contains('flat'));
      await press(t, find.text('dBA'), 'Settings: dBA');
      await press(
        t,
        find.byKey(const Key('keep-awake')),
        'Settings: Keep screen on',
      );
      expect(AppStore.i.keepAwake, isFalse);
      await press(
        t,
        find.byKey(const Key('keep-awake')),
        'Settings: Keep screen on',
      );
      await t.scrollUntilVisible(
        find.byKey(const Key('privacy')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await press(
        t,
        find.byKey(const Key('privacy')),
        'Settings: Privacy Policy',
      );
      expect(
        outside.calls.last,
        'open:https://soulfulfillable.github.io/test-mvp/decibel-privacy.html',
      );
      await back(t, 'Settings');

      // 가중을 바꿨으니 새 측정 (지금까지 것은 기록에 남음), 보정 +2.0 반영
      await listen(t, 2);
      expect(mic.running, isTrue);
      expect(textOf(t, const Key('current')), '56'); // 54 + 2
      expect(find.text('dBA'), findsWidgets);
      expect(AppStore.i.records, isNotEmpty);
      await finish(t);
    },
  );

  for (final d in devices.entries) {
    testWidgets('every screen fits on ${d.key}', (t) async {
      final (size, ratio) = d.value;
      await boot(t, size: size, ratio: ratio, prefs: const {});
      noKorean(t, 'Intro @${d.key}');
      await press(
        t,
        find.byKey(const Key('intro-continue')),
        'Intro: Continue',
      );
      mic.level = -3; // 시끄러운 상태에서 안내 줄까지 다 뜬 화면
      await listen(t, 4);
      expect(find.byKey(const Key('notice')), findsOneWidget);
      final main = t.getRect(find.byKey(const Key('main')));
      final banner = t.getRect(find.byKey(const Key('banner')));
      expect(
        main.bottom,
        lessThanOrEqualTo(banner.top),
        reason: 'controls overlap the ad',
      );
      await press(t, find.byKey(const Key('report')), 'Meter: Report');
      await back(t, 'Report');
      await press(t, find.byKey(const Key('guide')), 'Meter: Level guide chip');
      await back(t, 'Guide');
      await press(t, find.byKey(const Key('settings')), 'Meter: Settings');
      await back(t, 'Settings');
      await press(t, find.byKey(const Key('history')), 'Meter: History');
      await back(t, 'History');
      await press(t, find.byKey(const Key('main')), 'Meter: Pause');
      expect(find.byKey(const Key('notice')), findsOneWidget);
      await finish(t);
    });
  }
}
