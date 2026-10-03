// 테스트 로봇 — 모든 화면의 모든 버튼·입력 칸을 실제로 눌러 본다.
// 막힌 길(버튼이 안 먹음·가려짐)·뒤로가기 불가·깨진 레이아웃(overflow 는 Flutter 가 예외로 던져 테스트 실패)·잘린 글자를 잡는다.
// 실행: flutter test test/robot_test.dart
//   → 누른 버튼 목록이 로그로 찍히고, 화면별 스크린샷이 build/robot_shots/ 에 저장된다.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuellog/core/ads.dart';
import 'package:fuellog/core/files.dart';
import 'package:fuellog/core/model.dart';
import 'package:fuellog/core/notify.dart';
import 'package:fuellog/core/persist.dart';
import 'package:fuellog/core/sample.dart';
import 'package:fuellog/core/store.dart';
import 'package:fuellog/core/units.dart';
import 'package:fuellog/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pressed = <String>[];
final shots = <String>[];

/// 실제 기기 크기 (논리 픽셀, 배율, 아래 안전 영역)
const devices = {
  'iPhone 13 (1170x2532)': (Size(390, 844), 3.0, 34.0),
  'iPhone SE (750x1334)': (Size(375, 667), 2.0, 0.0),
  'iPhone 15 Pro Max (1290x2796)': (Size(430, 932), 3.0, 34.0),
};
const iphone13 = 'iPhone 13 (1170x2532)';
const iphoneSE = 'iPhone SE (750x1334)';

/// 숫자 키패드 높이 (iPhone 13 기준, 논리 픽셀)
const keyboardHeight = 291.0;

final today = DateTime(2026, 10, 2, 9);

late FakeNotifier notifier;
late FakeFiles files;
late MemoryPersist persist;

var _fontsLoaded = false;

/// 스크린샷 글자가 네모(Ahem)로 안 나오고, 잘림 검사가 진짜 글자 폭으로 되게 실제 글꼴을 넣는다 (속도계 교훈).
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final root = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts';
  Future<void> family(String name, List<String> fs) async {
    final loader = FontLoader(name);
    for (final f in fs) {
      final file = File('$root/$f');
      if (!file.existsSync()) throw StateError('font missing: ${file.path}');
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
  LogData? data,
  String? raw,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool keepPersist = false,
}) async {
  await t.runAsync(loadFonts);
  final (size, ratio, bottom) = devices[device]!;
  t.view.physicalSize = size * ratio;
  t.view.devicePixelRatio = ratio;
  t.view.padding = FakeViewPadding(top: 47 * ratio, bottom: bottom * ratio);
  t.view.viewPadding = FakeViewPadding(top: 47 * ratio, bottom: bottom * ratio);
  t.platformDispatcher.platformBrightnessTestValue = brightness;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({});
  Ads.i = FakeAds();
  Notifier.i = notifier = FakeNotifier();
  Files.i = files = FakeFiles();
  if (!keepPersist) persist = MemoryPersist(raw ?? (data == null ? null : jsonEncode(data.toJson())));
  AppStore.i.persist = persist;
  AppStore.i.now = () => today;
  await AppStore.i.load();
  // 다시 켜기 흉내: 앞 화면을 완전히 걷어내고 새로 띄운다
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(const FuelApp());
  await t.pumpAndSettle();
}

Future<void> shot(WidgetTester t, String name) async {
  await t.pumpAndSettle();
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

const _lists = [
  'form',
  'log-list',
  'reminders-list',
  'charts-list',
  'more-list',
  'vehicles-list',
  'import-list',
  'welcome',
];

/// 지금 맨 위 화면의 스크롤 목록.
Finder? get topScroll {
  for (final k in _lists) {
    final f = find.descendant(of: find.byKey(Key(k)), matching: find.byType(Scrollable));
    if (f.evaluate().isNotEmpty) return f.first;
  }
  return null;
}

/// 화면 밖이면 스크롤해서 보이게 한다.
Future<void> reveal(WidgetTester t, Finder f) async {
  final sc = topScroll;
  if (f.evaluate().isEmpty && sc != null) {
    await t.drag(sc, const Offset(0, 10000));
    await t.pumpAndSettle();
    if (f.evaluate().isEmpty) await t.scrollUntilVisible(f, 200, scrollable: sc);
  }
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

void clearSnacks(WidgetTester t) {
  final m = find.byType(ScaffoldMessenger);
  if (m.evaluate().isNotEmpty) t.state<ScaffoldMessengerState>(m.first).removeCurrentSnackBar();
}

/// 누르기 — 버튼이 화면 안에 있고 다른 것에 가려지지 않았는지(hit test)까지 확인한다 (속도계 교훈).
Future<void> press(WidgetTester t, Finder f, String label, {bool keepSnack = false}) async {
  if (!keepSnack) {
    clearSnacks(t);
    await t.pump();
  }
  await reveal(t, f);
  expect(f, findsOneWidget, reason: 'button not found: $label');
  final box = t.renderObject(f) as RenderBox;
  final center = box.localToGlobal(box.size.center(Offset.zero));
  final screen = t.view.physicalSize / t.view.devicePixelRatio;
  expect(
    center.dx >= 0 && center.dy >= 0 && center.dx <= screen.width && center.dy <= screen.height,
    isTrue,
    reason: '$label is off screen at $center',
  );
  final hit = HitTestResult();
  t.binding.hitTestInView(hit, center, t.view.viewId);
  expect(hit.path.any((e) => e.target == box), isTrue, reason: '$label is covered by something else at $center');
  await t.tap(f);
  pressed.add(label);
  await t.pumpAndSettle();
}

Future<void> pressKey(WidgetTester t, String key, [String? label]) => press(t, find.byKey(Key(key)), label ?? key);

Finder fieldOf(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText));

String fieldText(WidgetTester t, String key) => t.widget<EditableText>(fieldOf(key)).controller.text;

/// 칸을 눌러 글자를 친다 (실제처럼 탭 → 입력).
Future<void> typeInto(WidgetTester t, String key, String text) async {
  clearSnacks(t);
  await reveal(t, find.byKey(Key(key)));
  await t.tap(find.byKey(Key(key)));
  await t.pump();
  final f = fieldOf(key);
  await t.enterText(f.evaluate().isEmpty ? find.byKey(Key(key)) : f, text);
  pressed.add('type $key=$text');
  await t.pumpAndSettle();
}

Future<void> done(WidgetTester t) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
}

String textOf(WidgetTester t, String key) {
  final w = t.widget(find.byKey(Key(key)));
  if (w is Text) return w.data ?? w.textSpan!.toPlainText();
  if (w is RichText) return w.text.toPlainText();
  return find
      .descendant(of: find.byKey(Key(key)), matching: find.byType(Text))
      .evaluate()
      .map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '')
      .join(' ');
}

String snack(WidgetTester t) => textOf(t, 'snack');

/// 화면에 그려진 글자 중 '…' 로 잘린 게 있으면 실패. [allow] 에 든 글자는 일부러 줄인 것(긴 차 이름·메모).
void expectNoTruncatedText(WidgetTester t, String where, {Set<String> allow = const {}}) {
  for (final ro in t.allRenderObjects.whereType<RenderParagraph>()) {
    if (!ro.attached || !ro.hasSize) continue;
    final txt = ro.text.toPlainText();
    if (allow.any(txt.contains)) continue;
    expect(
      ro.didExceedMaxLines,
      isFalse,
      reason: '$where: text cut off: "$txt" (${ro.size.width.toStringAsFixed(0)}px)',
    );
  }
  pressed.add('truncation check: $where');
}

/// 보이는 숫자 칸 중 글자가 칸보다 넓어 잘린 게 있으면 실패 (대출 앱 교훈).
void expectNoClippedFields(WidgetTester t, String where) {
  for (final ro in t.allRenderObjects.whereType<RenderEditable>()) {
    if (!ro.attached || !ro.hasSize) continue;
    final need = ro.getMaxIntrinsicWidth(ro.size.height);
    expect(
      need,
      lessThanOrEqualTo(ro.size.width + 0.5),
      reason:
          '$where: "${ro.text?.toPlainText()}" needs ${need.toStringAsFixed(1)}px but field is ${ro.size.width.toStringAsFixed(1)}px',
    );
  }
  pressed.add('clip check: $where');
}

/// 화면 읽기(VoiceOver) 입력 칸 수 == 실제 입력 칸 수 (대출 앱: 칸이 두 개씩 읽히던 버그).
void expectOneSemanticFieldEach(WidgetTester t, String where) {
  final sem = t.ensureSemantics();
  // 목록 안 화면 밖(미리 만들어 둔) 칸도 화면 읽기에는 있으므로 같이 센다
  final fields = find.byType(EditableText, skipOffstage: false).evaluate().length;
  final nodes = find.semantics.byPredicate((n) => n.flagsCollection.isTextField).evaluate().length;
  expect(nodes, fields, reason: '$where: $nodes text fields for VoiceOver, $fields on screen');
  sem.dispose();
  pressed.add('voiceover fields: $where');
}

/// 화면 읽기에서 '버튼'이라고 읽히는데 누를 수 없는 것 (VoiceOver 로는 못 누른다) — 웹 점검에서 차량 버튼으로 발견.
void expectButtonsTappable(WidgetTester t, String where) {
  final sem = t.ensureSemantics();
  final bad = <String>[];
  void visit(SemanticsNode n) {
    final d = n.getSemanticsData();
    // ignore: deprecated_member_use
    final disabled = d.hasFlag(SemanticsFlag.hasEnabledState) && !d.hasFlag(SemanticsFlag.isEnabled);
    // ignore: deprecated_member_use
    if (d.hasFlag(SemanticsFlag.isButton) && !d.hasAction(SemanticsAction.tap) && !disabled) {
      bad.add(d.label);
    }
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
  sem.dispose();
  expect(bad, isEmpty, reason: '$where: buttons without a tap action: $bad');
  pressed.add('voiceover buttons tappable: $where');
}

LogData demo() => sampleData(today);

String get civicId => 'demo-civic';

void main() {
  tearDownAll(() {
    // ignore: avoid_print
    print(
      '\n=== robot pressed ${pressed.length} things ===\n${pressed.join('\n')}\n=== screenshots (${shots.length}) ===\n${shots.join('\n')}',
    );
  });

  testWidgets('first launch: name the car, pick units, start → empty log with tips', (t) async {
    await boot(t);
    expect(find.byKey(const Key('welcome')), findsOneWidget);
    await shot(t, '01-welcome');
    await pressKey(t, 'welcome-units-false', 'units: metric');
    await pressKey(t, 'welcome-units-true', 'units: US');
    await typeInto(t, 'welcome-name', 'My Civic');
    await done(t);
    await pressKey(t, 'welcome-start');
    expect(find.byKey(const Key('log-empty')), findsOneWidget);
    expect(textOf(t, 'avg-economy'), '—');
    expect(textOf(t, 'avg-hint'), contains('two full fill-ups'));
    expect(find.text('My Civic'), findsOneWidget);
    expect(find.byKey(const Key('banner')), findsOneWidget, reason: 'banner on tabs');
    await shot(t, '02-log-empty');
    // 빈 기록에서도 모든 탭이 열린다
    for (final tab in ['charts', 'reminders', 'more', 'log']) {
      await pressKey(t, 'tab-$tab');
      await shot(t, '03-empty-$tab');
    }
    expect(find.byKey(const Key('econ-empty')), findsNothing); // 기록 탭으로 돌아옴
    await t.runAsync(AppStore.i.flush);
    expect(persist.data, contains('My Civic'));
  });

  testWidgets('blank car name becomes "My Car"', (t) async {
    await boot(t);
    await pressKey(t, 'welcome-start');
    expect(AppStore.i.vehicle!.name, 'My Car');
  });

  testWidgets('fill-ups: any two of gallons/price/total, live MPG, partial, missed, odometer checks', (t) async {
    await boot(
      t,
      data: LogData(
        vehicles: [Vehicle(id: 'v', name: 'Civic')],
        currentVehicleId: 'v',
      ),
    );
    // 1) 첫 주유: 갤런 + 단가 → 총액 자동
    await pressKey(t, 'add-fill');
    expect(find.byKey(const Key('banner')), findsNothing, reason: 'no ads on the entry form');
    expect(find.byKey(const Key('mode-trip')), findsNothing, reason: 'no trip mode before the first fill-up');
    await typeInto(t, 'fill-odo', '10000');
    await typeInto(t, 'fill-vol', '12');
    await typeInto(t, 'fill-price', '3.25');
    await done(t);
    expect(fieldText(t, 'fill-total'), '39.00');
    expect(textOf(t, 'preview-title'), 'First full tank');
    await shot(t, '10-fill-first');
    await pressKey(t, 'fill-save');
    expect(snack(t), 'Fill-up saved');
    expect(textOf(t, 'avg-hint'), contains('next full fill-up'));

    // 2) 두 번째: 총액 + 갤런 → 단가 자동, 이번 탱크 30.0 MPG 미리보기
    await pressKey(t, 'add-fill');
    await typeInto(t, 'fill-odo', '10300');
    await typeInto(t, 'fill-total', '35');
    await typeInto(t, 'fill-vol', '10');
    await done(t);
    expect(fieldText(t, 'fill-price'), '3.500');
    expect(textOf(t, 'preview-title'), 'This tank: 30.0 MPG');
    await shot(t, '11-fill-preview');
    await pressKey(t, 'fill-save-top');
    expect(snack(t), 'Fill-up saved · 30.0 MPG this tank');
    expect(textOf(t, 'avg-economy'), '30.0');
    expect(textOf(t, 'stat-last'), '30.0 MPG');
    expect(textOf(t, 'stat-cpm'), r'$0.117/mi');

    // 3) 저장 버튼을 먼저 누르면 무엇이 빠졌는지 보인다
    await pressKey(t, 'add-fill');
    await pressKey(t, 'fill-save', 'save empty form');
    expect(find.byKey(const Key('odo-error')), findsOneWidget);
    expect(find.byKey(const Key('vol-error')), findsOneWidget);
    expect(find.byKey(const Key('cost-error')), findsOneWidget);
    await shot(t, '12-fill-errors');
    // 이미 있는 주행거리면 저장 안 됨 (같은 날 여러 번은 주행거리 순으로 본다)
    await typeInto(t, 'fill-odo', '10300');
    expect(textOf(t, 'odo-error'), 'Same as the Oct 2, 2026 fill-up (10,300 mi)');
    await pressKey(t, 'fill-save', 'save with odometer error');
    expect(find.byKey(const Key('fill-odo')), findsOneWidget, reason: 'still on the form');
    // 부분 주유: 구간 거리(트립)로
    await pressKey(t, 'mode-trip', 'trip meter mode');
    await typeInto(t, 'fill-trip', '150');
    expect(find.text('Odometer 10,450 mi'), findsOneWidget);
    await typeInto(t, 'fill-vol', '4');
    await typeInto(t, 'fill-price', '3.5');
    await done(t);
    await pressKey(t, 'fill-full', 'toggle full tank off');
    expect(textOf(t, 'preview-title'), 'Partial fill-up');
    await pressKey(t, 'fill-date', 'open date picker');
    expect(find.byKey(const Key('date-wheel')), findsOneWidget);
    await shot(t, '13-date-picker');
    await pressKey(t, 'date-done');
    await typeInto(t, 'fill-note', 'Costco');
    await done(t);
    await pressKey(t, 'fill-save');
    expect(snack(t), 'Fill-up saved');

    // 4) 다음 가득: 부분 주유량까지 합쳐서 (300 mi / 10 gal = 30)
    await pressKey(t, 'add-fill');
    await typeInto(t, 'fill-odo', '10600');
    await typeInto(t, 'fill-vol', '6');
    await typeInto(t, 'fill-total', '21');
    await done(t);
    expect(textOf(t, 'preview-title'), 'This tank: 30.0 MPG');
    await pressKey(t, 'fill-save');

    // 5) 기록 빠짐 스위치: 이번 탱크는 건너뜀
    await pressKey(t, 'add-fill');
    await typeInto(t, 'fill-odo', '11500');
    await typeInto(t, 'fill-vol', '10');
    await typeInto(t, 'fill-total', '35');
    await done(t);
    expect(textOf(t, 'preview-title'), contains('MPG'));
    final hint = find.textContaining('Much higher than usual');
    expect(hint, findsOneWidget, reason: '90 MPG should hint at a missed fill-up');
    await pressKey(t, 'fill-missed', 'toggle missed fill-up');
    expect(textOf(t, 'preview-title'), 'MPG skipped for this tank');
    await pressKey(t, 'fill-save');
    expect(textOf(t, 'avg-economy'), '30.0', reason: 'skipped tank does not change the average');
    await shot(t, '14-log-after-fills');

    // 6) 고치기 → 지우기 → 되돌리기
    final last = AppStore.i.data.fills.firstWhere((f) => f.odometer == 11500);
    await pressKey(t, 'entry-${last.id}', 'open fill-up');
    expect(fieldText(t, 'fill-odo'), '11,500');
    await typeInto(t, 'fill-note', 'edited');
    await done(t);
    await pressKey(t, 'fill-delete');
    await shot(t, '15-delete-confirm');
    await pressKey(t, 'confirm-ok');
    expect(snack(t), 'Fill-up deleted');
    expect(AppStore.i.data.fills.length, 4);
    await press(t, find.byKey(const Key('snack-action')), 'undo delete', keepSnack: true);
    expect(AppStore.i.data.fills.length, 5);

    // 7) 고친 채로 닫으면 버릴지 묻는다 → 취소 → 다시 닫기 → 버림
    await pressKey(t, 'add-fill');
    await typeInto(t, 'fill-odo', '12000');
    await done(t);
    await pressKey(t, 'fill-close');
    expect(find.text('Discard changes?'), findsOneWidget);
    await pressKey(t, 'confirm-cancel');
    expect(find.byKey(const Key('fill-odo')), findsOneWidget);
    await pressKey(t, 'fill-close');
    await pressKey(t, 'confirm-ok', 'discard');
    expect(find.byKey(const Key('add-fill')), findsOneWidget);
    expect(AppStore.i.data.fills.length, 5);
    // 아무것도 안 쓰고 닫으면 바로 닫힌다
    await pressKey(t, 'add-fill');
    await pressKey(t, 'fill-close', 'close untouched form');
    expect(find.byKey(const Key('add-fill')), findsOneWidget);
  });

  testWidgets('odometer must fit between fill-ups on other days', (t) async {
    await boot(
      t,
      data: LogData(
        vehicles: [Vehicle(id: 'v', name: 'Civic')],
        currentVehicleId: 'v',
        fills: [
          FillUp(id: 'a', vehicleId: 'v', date: DateTime(2026, 9, 1, 9), odometer: 10000, volume: 12, cost: 40),
          FillUp(id: 'b', vehicleId: 'v', date: DateTime(2026, 9, 20, 9), odometer: 10600, volume: 12, cost: 40),
        ],
      ),
    );
    await pressKey(t, 'add-fill');
    await typeInto(t, 'fill-odo', '10500');
    await done(t);
    expect(textOf(t, 'odo-error'), 'Must be more than 10,600 mi (Sep 20, 2026 fill-up)');
    // 지난 주유를 고칠 때는 다음 주유보다 작아야 한다
    await pressKey(t, 'fill-close');
    await pressKey(t, 'confirm-ok');
    await pressKey(t, 'entry-a', 'edit first fill-up');
    await typeInto(t, 'fill-odo', '10700');
    await done(t);
    expect(textOf(t, 'odo-error'), 'Must be less than 10,600 mi (Sep 20, 2026 fill-up)');
    await typeInto(t, 'fill-odo', '10100');
    await done(t);
    expect(find.byKey(const Key('odo-error')), findsNothing);
    await pressKey(t, 'fill-save');
    expect(snack(t), 'Fill-up updated');
  });

  testWidgets('keyboard up (iPhone 13 number pad): Done bar moves between fields, nothing covered', (t) async {
    await boot(t, data: demo());
    await pressKey(t, 'add-fill');
    await t.tap(find.byKey(const Key('fill-odo')));
    t.view.viewInsets = FakeViewPadding(bottom: keyboardHeight * 3);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('kb-done')), findsOneWidget);
    await shot(t, '20-keyboard');
    expectNoTruncatedText(t, 'fill form with keyboard');
    await pressKey(t, 'kb-next', 'keyboard next');
    final focusedField = find.descendant(of: find.byKey(const Key('fill-vol')), matching: find.byType(EditableText));
    expect(t.widget<EditableText>(focusedField).focusNode.hasFocus, isTrue, reason: 'Next goes to Gallons');
    await t.enterText(focusedField, '11.2');
    await pressKey(t, 'kb-next', 'keyboard next 2');
    final price = find.descendant(of: find.byKey(const Key('fill-price')), matching: find.byType(EditableText));
    expect(t.widget<EditableText>(price).focusNode.hasFocus, isTrue, reason: 'Next goes to Price');
    await pressKey(t, 'kb-prev', 'keyboard previous');
    expect(t.widget<EditableText>(focusedField).focusNode.hasFocus, isTrue);
    await pressKey(t, 'kb-done', 'keyboard done');
    t.view.viewInsets = FakeViewPadding.zero;
    await t.pumpAndSettle();
    expect(find.byKey(const Key('kb-done')), findsNothing);
    expect(fieldText(t, 'fill-vol'), '11.2');
  });

  testWidgets('service + reminders: quick add, Log it resets, custom kind, notifications scheduled', (t) async {
    final d = LogData(
      vehicles: [Vehicle(id: 'v', name: 'Civic')],
      currentVehicleId: 'v',
      fills: [
        FillUp(id: 'a', vehicleId: 'v', date: DateTime(2026, 6, 1, 9), odometer: 40000, volume: 12, cost: 40),
        FillUp(id: 'b', vehicleId: 'v', date: DateTime(2026, 9, 29, 9), odometer: 44000, volume: 12, cost: 40),
      ],
    );
    await boot(t, data: d);
    await pressKey(t, 'tab-reminders');
    expect(find.byKey(const Key('reminders-empty')), findsOneWidget);
    await shot(t, '30-reminders-empty');
    await pressKey(t, 'quick-Oil change', 'quick add oil change');
    expect(fieldText(t, 'rem-every'), '5,000');
    expect(fieldText(t, 'rem-months'), '6');
    expect(fieldText(t, 'rem-last-odo'), '44,000');
    // 마지막으로 한 때: 3,000 마일 전
    await typeInto(t, 'rem-last-odo', '41000');
    await done(t);
    await pressKey(t, 'rem-date', 'open last-done date');
    await pressKey(t, 'date-done');
    await shot(t, '31-reminder-form');
    await pressKey(t, 'rem-save');
    expect(notifier.asked, 1, reason: 'asks notification permission when the first reminder is saved');
    expect(snack(t), 'Reminder added');
    final r = AppStore.i.data.reminders.single;
    expect(textOf(t, 'rem-due-${r.id}'), startsWith('In 2,000 mi or by Apr 2, 2027'));
    expect(notifier.scheduled.single.title, 'Oil change due · Civic');
    await shot(t, '32-reminders');

    // 같은 종류 또 만들기 → 막힘
    await pressKey(t, 'add-reminder');
    await pressKey(t, 'rk-Oil change');
    await pressKey(t, 'rem-save');
    expect(textOf(t, 'rem-error'), contains('already have'));
    await pressKey(t, 'rk-other', 'custom reminder');
    await pressKey(t, 'rem-save');
    expect(textOf(t, 'rem-error'), contains('Pick what'));
    await typeInto(t, 'rem-custom', 'Spark plugs');
    await typeInto(t, 'rem-every', '');
    await typeInto(t, 'rem-months', '');
    await done(t);
    await pressKey(t, 'rem-save');
    expect(textOf(t, 'rem-error'), contains('distance, a number of months'));
    await typeInto(t, 'rem-every', '30000');
    await done(t);
    await pressKey(t, 'rem-notify', 'toggle notify off');
    await pressKey(t, 'rem-save');
    expect(AppStore.i.data.reminders.length, 2);
    expect(notifier.scheduled.length, 1, reason: 'notify off → not scheduled');

    // Log it → 정비 기록 → 알림이 다시 센다
    await pressKey(t, 'rem-log-${r.id}', 'Log it');
    await typeInto(t, 'svc-odo', '44100');
    await typeInto(t, 'svc-cost', '64.99');
    await typeInto(t, 'svc-note', 'synthetic');
    await done(t);
    await pressKey(t, 'svc-date', 'service date');
    await pressKey(t, 'date-done');
    await shot(t, '33-service-form');
    await pressKey(t, 'svc-save');
    expect(snack(t), 'Oil change saved · next due 49,100 mi or Apr 2, 2027');
    expect(textOf(t, 'rem-due-${r.id}'), startsWith('In 5,000 mi'));
    await press(t, find.byKey(Key('rem-${r.id}')), 'open reminder');
    expect(find.byKey(const Key('rem-from-log')), findsOneWidget);
    await pressKey(t, 'rem-close');

    // 지난 알림 → 기록 탭에 빨간 줄 + 탭 배지
    final over = Reminder(
      id: 'over',
      vehicleId: 'v',
      kind: 'Tire rotation',
      everyMiles: 3000,
      lastOdometer: 40000,
      lastDate: DateTime(2026, 6, 1),
    );
    AppStore.i.saveReminder(over);
    await t.pumpAndSettle();
    await pressKey(t, 'tab-log');
    expect(find.byKey(const Key('due-over')), findsOneWidget);
    expect(textOf(t, 'due-over'), contains('Overdue by 1,100 mi'));
    await shot(t, '34-log-due');
    await pressKey(t, 'due-over', 'due row → reminders tab');
    expect(find.byKey(const Key('reminders-list')), findsOneWidget);

    // 기록 탭에서 정비 기록: 종류 안 고르면 막힘 → 다른 종류 → '다음에 알려 줘' 로 알림 만들기
    await pressKey(t, 'tab-log');
    await pressKey(t, 'add-service');
    await pressKey(t, 'svc-save', 'save without kind');
    expect(find.byKey(const Key('kind-error')), findsOneWidget);
    await pressKey(t, 'kind-Brakes');
    await typeInto(t, 'svc-cost', '320');
    await done(t);
    await pressKey(t, 'svc-save-top');
    expect(snack(t), 'Brakes saved');
    await press(t, find.byKey(const Key('snack-action')), 'Remind me next time', keepSnack: true);
    expect(fieldText(t, 'rem-every'), '12,000');
    await pressKey(t, 'rem-save');
    expect(AppStore.i.data.reminders.any((e) => e.kind == 'Brakes'), isTrue);

    // 사용자 정의 종류 정비 → 고치기 → 지우기 → 되돌리기
    await pressKey(t, 'add-service');
    await pressKey(t, 'kind-other');
    await typeInto(t, 'svc-custom', 'Detailing');
    await typeInto(t, 'svc-cost', '120');
    await done(t);
    await pressKey(t, 'svc-save');
    expect(snack(t), 'Saved: Detailing');
    final det = AppStore.i.data.services.firstWhere((e) => e.kind == 'Detailing');
    await pressKey(t, 'entry-${det.id}', 'open service');
    expect(t.widget<TextField>(find.byKey(const Key('svc-custom'))).controller!.text, 'Detailing');
    await pressKey(t, 'svc-delete');
    await pressKey(t, 'confirm-ok');
    expect(AppStore.i.data.services.any((e) => e.kind == 'Detailing'), isFalse);
    await press(t, find.byKey(const Key('snack-action')), 'undo service delete', keepSnack: true);
    expect(AppStore.i.data.services.any((e) => e.kind == 'Detailing'), isTrue);

    // 알림 지우기 → 되돌리기
    await pressKey(t, 'tab-reminders');
    await pressKey(t, 'rem-${r.id}');
    await pressKey(t, 'rem-delete');
    await pressKey(t, 'confirm-ok');
    expect(AppStore.i.data.reminders.any((e) => e.id == r.id), isFalse);
    await press(t, find.byKey(const Key('snack-action')), 'undo reminder delete', keepSnack: true);
    expect(AppStore.i.data.reminders.any((e) => e.id == r.id), isTrue);
  });

  testWidgets('every reminder with notify on gets a future notification (incl. "likely due now")', (t) async {
    await boot(t, data: demo());
    await pressKey(t, 'tab-reminders');
    expect(find.textContaining('likely due now'), findsOneWidget, reason: 'oil change estimate already passed');
    final on = AppStore.i.data.reminders.where((r) => r.notify).length;
    expect(notifier.scheduled.length, on, reason: notifier.scheduled.join('\n'));
    for (final n in notifier.scheduled) {
      expect(n.when.isAfter(today), isTrue, reason: '$n');
    }
    expect(notifier.scheduled.first.title, contains('· 2019 Honda Civic'));
    pressed.add('notification schedule check (${notifier.scheduled.length})');
  });

  testWidgets('notifications denied → reminder still saved, user told how to turn on', (t) async {
    await boot(
      t,
      data: LogData(
        vehicles: [Vehicle(id: 'v', name: 'Civic')],
        currentVehicleId: 'v',
      ),
    );
    notifier.allow = false;
    await pressKey(t, 'tab-reminders');
    await pressKey(t, 'add-reminder');
    await pressKey(t, 'rk-Inspection');
    await pressKey(t, 'rem-save');
    expect(snack(t), contains('Notifications are off'));
    expect(AppStore.i.data.reminders.length, 1);
  });

  testWidgets('charts: every range, tap to read values, numbers from the log', (t) async {
    await boot(t, data: demo());
    await pressKey(t, 'tab-charts');
    expect(find.byKey(const Key('econ-chart')), findsOneWidget);
    expect(find.byKey(const Key('cost-chart')), findsOneWidget);
    await shot(t, '40-charts');
    final before = textOf(t, 'chart-readout');
    await t.tapAt(t.getTopLeft(find.byKey(const Key('econ-chart'))) + const Offset(60, 120));
    await t.pumpAndSettle();
    pressed.add('tap MPG chart');
    expect(textOf(t, 'chart-readout'), isNot(before));
    await t.tapAt(t.getTopLeft(find.byKey(const Key('cost-chart'))) + const Offset(70, 120));
    await t.pumpAndSettle();
    pressed.add('tap cost chart');
    expect(textOf(t, 'bars-readout'), isNotEmpty);
    for (final r in ['m3', 'm6', 'all', 'y1']) {
      await pressKey(t, 'range-$r', 'range $r');
      expectNoTruncatedText(t, 'charts $r');
    }
    await reveal(t, find.byKey(const Key('n-cpm')));
    // 숫자 칸은 기록에서 바로 계산한 값과 같아야 한다 (1Y = 지난 12개월)
    final log = AppStore.i.log;
    final f = AppStore.i.fmt;
    final since = DateTime(2025, 11);
    expect(textOf(t, 'n-avg'), f.econ(log.avgMpg(since: since)!));
    expect(textOf(t, 'n-cpm'), f.perDist(log.fuelCostPerMile(since: since)!));
    await shot(t, '41-charts-numbers');
  });

  testWidgets('more: units, vehicles (add/switch/rename/delete/undo), trip split, export, import', (t) async {
    await boot(t, data: demo());
    final avgMpg = AppStore.i.log.avgMpg()!;
    await pressKey(t, 'tab-more');
    await shot(t, '50-more');
    await pressKey(t, 'u-dist-km');
    await pressKey(t, 'u-vol-l');
    expect(AppStore.i.units, Units.metric);
    await pressKey(t, 'u-econ-kml');
    await pressKey(t, 'tab-log');
    expect(textOf(t, 'avg-economy'), EconomyUnit.kml.fromMpg(avgMpg).toStringAsFixed(1));
    await shot(t, '51-log-metric');
    await pressKey(t, 'tab-more');
    await pressKey(t, 'u-econ-l100km');
    await pressKey(t, 'u-dist-mi');
    await pressKey(t, 'u-vol-gal');
    expect(AppStore.i.units, Units.us);

    // 로드트립
    await pressKey(t, 'more-trip');
    expect(fieldText(t, 'trip-econ'), avgMpg.toStringAsFixed(1));
    await typeInto(t, 'trip-dist', '300');
    await done(t);
    await pressKey(t, 'trip-round');
    await pressKey(t, 'trip-plus');
    await pressKey(t, 'trip-plus');
    await pressKey(t, 'trip-minus');
    expect(textOf(t, 'trip-people'), '3');
    final price = double.parse(fieldText(t, 'trip-price'));
    final mpg = double.parse(fieldText(t, 'trip-econ'));
    final expected = 600 / mpg * price / 3;
    expect(textOf(t, 'trip-each'), '\$${expected.toStringAsFixed(2)}');
    await shot(t, '52-trip');
    await t.pageBack();
    await t.pumpAndSettle();
    pressed.add('back from trip');

    // 내보내기
    await pressKey(t, 'more-export');
    expect(files.shared.single.$1, 'fuel-log-2026-10-02.csv');
    expect(files.shared.single.$2, startsWith('Vehicle,Type,Date,Odometer (mi)'));
    expect(snack(t), startsWith('Exported'));

    // 가져오기: 단위 없는 파일 → 단위 고르기 → 가져오기
    files.nextPick = 'Date,Odometer,Fuel,Total,Car\n2026-09-01,1000,40,60,Rental\n2026-09-08,1400,30,45,Rental\n';
    await pressKey(t, 'more-import');
    expect(textOf(t, 'imp-fills'), '2');
    expect(textOf(t, 'imp-vehicles'), '1');
    expect(find.byKey(const Key('imp-units')), findsOneWidget);
    await pressKey(t, 'imp-dist-km');
    await pressKey(t, 'imp-vol-l');
    await shot(t, '53-import');
    await pressKey(t, 'imp-go');
    expect(snack(t), 'Imported 2 records');
    final rental = AppStore.i.vehicles.firstWhere((v) => v.name == 'Rental');
    final log = AppStore.i.logFor(rental.id);
    expect(log.avgMpg()! / EconomyUnit.kml.toMpg(1), closeTo(400 / 30, 1e-6), reason: 'km & L applied');
    // 같은 파일 다시 → 전부 중복
    await pressKey(t, 'more-import', 'import same file again');
    expect(textOf(t, 'imp-fills'), '2', reason: 'as miles/gallons these are different fill-ups');
    await pressKey(t, 'imp-dist-km', 'same file: km');
    await pressKey(t, 'imp-vol-l', 'same file: L');
    expect(textOf(t, 'imp-dups'), contains('2 already'));
    expect(textOf(t, 'imp-fills'), '0');
    expect(
      t
          .widget<FilledButton>(
            find.descendant(of: find.byKey(const Key('imp-go')), matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNull,
    );
    await t.pageBack();
    await t.pumpAndSettle();
    // 읽을 수 없는 파일
    files.nextPick = 'hello,world\n1,2\n';
    await pressKey(t, 'more-import', 'import junk file');
    expect(find.byKey(const Key('imp-problems')), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    // 고르기 취소
    files.nextPick = null;
    await pressKey(t, 'more-import', 'cancel file picker');
    expect(find.byKey(const Key('more-list')), findsOneWidget);

    // 차량: 위 제목에서 고르기·추가
    await pressKey(t, 'tab-log');
    await pressKey(t, 'vehicle-switch', 'open vehicle picker');
    await shot(t, '54-vehicle-picker');
    await pressKey(t, 'pick-demo-truck', 'switch to truck');
    expect(AppStore.i.vehicle!.name, '2021 Ford F-150');
    await pressKey(t, 'vehicle-switch');
    await pressKey(t, 'picker-add');
    await t.enterText(find.byKey(const Key('vehicle-name')), 'Wife\'s RAV4');
    await pressKey(t, 'name-ok');
    expect(AppStore.i.vehicle!.name, "Wife's RAV4");
    await pressKey(t, 'tab-log');
    expect(find.byKey(const Key('log-empty')), findsOneWidget);
    await pressKey(t, 'vehicle-switch');
    await pressKey(t, 'picker-done');
    // 관리: 이름 바꾸기 → 지우기 → 되돌리기
    await pressKey(t, 'vehicle-switch');
    await pressKey(t, 'picker-manage');
    await shot(t, '55-vehicles');
    await pressKey(t, 'veh-demo-civic', 'rename civic');
    await t.enterText(find.byKey(const Key('vehicle-name')), 'Civic');
    await pressKey(t, 'name-ok');
    expect(AppStore.i.vehicles.first.name, 'Civic');
    await pressKey(t, 'veh-demo-civic', 'rename then cancel');
    await pressKey(t, 'name-cancel');
    await pressKey(t, 'veh-del-demo-civic', 'delete civic');
    expect(find.textContaining('fill-ups and'), findsOneWidget);
    await pressKey(t, 'confirm-ok');
    expect(AppStore.i.vehicles.any((v) => v.id == civicId), isFalse);
    await press(t, find.byKey(const Key('snack-action')), 'undo vehicle delete', keepSnack: true);
    expect(AppStore.i.vehicles.any((v) => v.id == civicId), isTrue);
    expect(AppStore.i.data.fills.where((f) => f.vehicleId == civicId).length, greaterThan(40));
    await pressKey(t, 'veh-add');
    await pressKey(t, 'name-cancel', 'cancel add vehicle');
    await t.pageBack();
    await t.pumpAndSettle();
    pressed.add('back from vehicles');
    await pressKey(t, 'tab-more');
    expect(find.byKey(const Key('more-privacy')), findsOneWidget);
    expect(textOf(t, 'more-version'), contains('Glance MPG 1.0'));
  });

  testWidgets('deleting the last vehicle goes back to the welcome screen', (t) async {
    await boot(
      t,
      data: LogData(
        vehicles: [Vehicle(id: 'v', name: 'Only car')],
        currentVehicleId: 'v',
      ),
    );
    await pressKey(t, 'tab-more');
    await pressKey(t, 'more-vehicles');
    await pressKey(t, 'veh-del-v');
    await pressKey(t, 'confirm-ok');
    expect(find.byKey(const Key('welcome')), findsOneWidget);
    await press(t, find.byKey(const Key('snack-action')), 'undo last vehicle delete', keepSnack: true);
    expect(find.byKey(const Key('log-list')), findsOneWidget);
  });

  testWidgets('saved log survives a restart; broken file restored from the last good copy', (t) async {
    await boot(t, data: demo());
    await pressKey(t, 'add-service');
    await pressKey(t, 'kind-Car wash');
    await typeInto(t, 'svc-cost', '12');
    await done(t);
    await pressKey(t, 'svc-save');
    await t.runAsync(AppStore.i.flush);
    final saved = persist.data!;
    // 다시 켜기
    await boot(t, keepPersist: true);
    expect(AppStore.i.data.services.where((s) => s.kind == 'Car wash').length, 2);
    // 본 파일이 깨지면 직전 사본으로
    persist
      ..backup = saved
      ..data = '{"v":1,"vehicles":[{"id":';
    await boot(t, keepPersist: true);
    expect(AppStore.i.vehicles.length, 2);
    expect(find.text('Your log was restored from the last good copy.'), findsOneWidget);
    pressed.add('restart + restore from backup');
  });

  // ───── 화면 크기·다크 모드·큰 글씨에서 모든 화면을 돌며 잘림·넘침·가림 검사 + 스크린샷 ─────
  for (final device in devices.keys) {
    for (final (dark, scale) in [(false, 1.0), (true, 1.35)]) {
      final tag =
          '${device.split(' (').first.replaceAll(' ', '')}-${dark ? 'dark' : 'light'}-${scale == 1 ? '100' : '135'}';
      testWidgets('layout sweep $tag', (t) async {
        final d = demo();
        // 긴 값: 큰 주행거리·큰 금액·긴 차 이름
        d.vehicles.add(Vehicle(id: 'long', name: '2024 Mercedes-Benz GLE 450 4MATIC Coupé'));
        d.fills.add(
          FillUp(
            id: 'big',
            vehicleId: 'long',
            date: DateTime(2026, 9, 1),
            odometer: 999999,
            volume: 88.888,
            cost: 9999.99,
          ),
        );
        d.fills.add(
          FillUp(
            id: 'big2',
            vehicleId: 'long',
            date: DateTime(2026, 9, 20),
            odometer: 1000600.5,
            volume: 30.5,
            cost: 1234.56,
          ),
        );
        await boot(t, device: device, data: d, brightness: dark ? Brightness.dark : Brightness.light, textScale: scale);
        const allow = {'Mercedes', 'Costco', 'Full synthetic'};
        Future<void> check(String screen) async {
          // 실패해도 증거가 남게 스크린샷 먼저
          await shot(t, 'sweep-$tag-$screen');
          expectNoTruncatedText(t, '$tag $screen', allow: allow);
          expectNoClippedFields(t, '$tag $screen');
          expectButtonsTappable(t, '$tag $screen');
        }

        await check('log');
        await t.drag(topScroll!, const Offset(0, -600));
        await check('log-scrolled');
        await pressKey(t, 'tab-charts');
        await check('charts');
        await pressKey(t, 'tab-reminders');
        await check('reminders');
        await pressKey(t, 'tab-more');
        await check('more');
        await pressKey(t, 'tab-log');
        await pressKey(t, 'add-fill');
        await typeInto(t, 'fill-odo', '9999999.9');
        await typeInto(t, 'fill-vol', '9999.999');
        await typeInto(t, 'fill-price', '999.999');
        await done(t);
        expectOneSemanticFieldEach(t, '$tag fill form');
        await check('fill-form');
        await pressKey(t, 'fill-close');
        await pressKey(t, 'confirm-ok');
        await pressKey(t, 'add-service');
        await typeInto(t, 'svc-cost', '999999.99');
        await done(t);
        await check('service-form');
        await pressKey(t, 'svc-close');
        await pressKey(t, 'confirm-ok');
        await pressKey(t, 'tab-reminders');
        await pressKey(t, 'add-reminder');
        await pressKey(t, 'rk-Coolant');
        await check('reminder-form');
        await pressKey(t, 'rem-close');
        await pressKey(t, 'tab-more');
        await pressKey(t, 'more-trip');
        await typeInto(t, 'trip-dist', '99999');
        await done(t);
        for (var k = 0; k < 9; k++) {
          await pressKey(t, 'trip-plus');
        }
        await check('trip');
        await t.pageBack();
        await t.pumpAndSettle();
        // 긴 이름 차량으로 바꿔서 기록 화면
        await pressKey(t, 'tab-log');
        await pressKey(t, 'vehicle-switch');
        await pressKey(t, 'pick-long');
        await check('log-long-name');
        await pressKey(t, 'tab-charts');
        await check('charts-long');
      });
    }
  }
}
