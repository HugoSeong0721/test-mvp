// 테스트 로봇 — 모든 화면의 모든 버튼·입력 칸을 실제로 눌러 본다.
// 막힌 길(버튼이 안 먹음)·뒤로가기 불가·깨진 레이아웃(overflow 는 Flutter 가 예외로 던져 테스트 실패)을 잡는다.
// 실행: flutter test test/robot_test.dart
//   → 누른 버튼 목록이 로그로 찍히고, 화면별 스크린샷이 build/robot_shots/ 에 저장된다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mortgage/core/ads.dart';
import 'package:mortgage/core/format.dart';
import 'package:mortgage/core/loan.dart';
import 'package:mortgage/core/store.dart';
import 'package:mortgage/main.dart';
import 'package:mortgage/screens/schedule_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pressed = <String>[];
final shots = <String>[];

/// 실제 기기 크기 (논리 픽셀, 배율, 아래 안전 영역)
const devices = {
  'iPhone 13 (1170x2532)': (Size(390, 844), 3.0, 34.0),
  'iPhone SE (750x1334)': (Size(375, 667), 2.0, 0.0),
  'iPhone 15 Pro Max (1290x2796)': (Size(430, 932), 3.0, 34.0),
};

/// 숫자 키패드 높이 (iPhone 13 기준, 논리 픽셀)
const keyboardHeight = 291.0;

var _fontsLoaded = false;

/// 스크린샷 글자가 네모(Ahem)로 안 나오게 실제 글꼴을 넣는다.
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final root =
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter'}'
      '/bin/cache/artifacts/material_fonts';
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final file = File('$root/$f');
      if (!file.existsSync()) return;
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
  String device = 'iPhone 13 (1170x2532)',
  Map<String, Object> prefs = const {},
  Brightness brightness = Brightness.light,
  bool resetPrefs = true,
  Ads? ads,
}) async {
  await t.runAsync(loadFonts);
  final (size, ratio, bottom) = devices[device]!;
  t.view.physicalSize = size * ratio;
  t.view.devicePixelRatio = ratio;
  t.view.padding = FakeViewPadding(top: 47 * ratio, bottom: bottom * ratio);
  t.view.viewPadding = FakeViewPadding(top: 47 * ratio, bottom: bottom * ratio);
  t.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
  if (resetPrefs) SharedPreferences.setMockInitialValues(prefs);
  Ads.i = ads ?? FakeAds();
  await AppStore.i.load();
  AppStore.i.clock = () => DateTime(2026, 10, 2, 9);
  await t.pumpWidget(const MortgageApp());
  await t.pumpAndSettle();
}

Future<void> shot(WidgetTester t, String name) async {
  final view = t.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final ratio = t.view.devicePixelRatio;
  await t.runAsync(() async {
    // 루트 레이어는 이미 기기 배율로 키워져 있다 → 물리 픽셀 영역을 찍고, 3배 기기는 2배로 줄여 저장
    final img = await layer.toImage(
      Offset.zero & t.view.physicalSize,
      pixelRatio: ratio > 2 ? 2 / ratio : 1,
    );
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/robot_shots')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  shots.add(name);
}

Future<void> toTop(WidgetTester t) async {
  await t.drag(formScroll.first, const Offset(0, 10000));
  await t.pumpAndSettle();
}

Finder get formScroll => find.descendant(
  of: find.byKey(const Key('form')),
  matching: find.byType(Scrollable),
);

/// 화면 밖이면 스크롤해서 보이게 한다.
Future<void> reveal(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty && formScroll.evaluate().isNotEmpty) {
    // 목록은 보이는 부분만 만들어 둔다 → 맨 위로 올린 뒤 아래로 훑는다
    await t.drag(formScroll.first, const Offset(0, 10000));
    await t.pumpAndSettle();
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(f, 200, scrollable: formScroll.first);
    }
  }
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

Future<void> press(WidgetTester t, Finder f, String label) async {
  await reveal(t, f);
  expect(f, findsOneWidget, reason: 'button not found: $label');
  await t.tap(f);
  pressed.add(label);
  await t.pumpAndSettle();
}

Future<void> pressKey(WidgetTester t, String key, String label) =>
    press(t, find.byKey(Key(key)), label);

Finder fieldOf(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(EditableText),
);

String fieldText(WidgetTester t, String key) =>
    t.widget<EditableText>(fieldOf(key)).controller.text;

/// 칸을 눌러 숫자를 친다 (실제처럼 탭 → 입력).
Future<void> typeInto(WidgetTester t, String key, String text) async {
  await reveal(t, find.byKey(Key(key)));
  await t.tap(find.byKey(Key(key)));
  await t.pump();
  await t.enterText(fieldOf(key), text);
  pressed.add('type $key=$text');
  await t.pumpAndSettle();
}

Future<void> done(WidgetTester t) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
}

String monthlyText(WidgetTester t) =>
    t.widget<Text>(find.byKey(const Key('monthly'))).textSpan!.toPlainText();

/// 상환표 한 줄의 마지막 칸(잔액).
String? balanceCell(WidgetTester t, String rowKey) => t
    .widgetList<Text>(
      find.descendant(of: find.byKey(Key(rowKey)), matching: find.byType(Text)),
    )
    .last
    .data;

Scenario sc(LoanKind k) => AppStore.i.scenario(k);

String expectedMonthly(LoanKind k) =>
    money2(calculate(sc(k).toInput()).monthlyTotal);

/// 보이는 숫자 칸 중 글자가 칸보다 넓어 잘린 게 있으면 실패 (예: "12.5 %" 가 "12.!" 로 보이던 문제).
void expectNoClippedFields(WidgetTester t, String where) {
  for (final ro in t.allRenderObjects.whereType<RenderEditable>()) {
    if (!ro.attached || !ro.hasSize) continue;
    final need = ro.getMaxIntrinsicWidth(ro.size.height);
    expect(
      need,
      lessThanOrEqualTo(ro.size.width + 0.5),
      reason:
          '$where: "${ro.text?.toPlainText()}" needs ${need.toStringAsFixed(1)}px '
          'but the field is ${ro.size.width.toStringAsFixed(1)}px',
    );
  }
  pressed.add('clip check: $where');
}

/// 화면에 그려진 글자 중 '…' 로 잘린 게 있으면 실패.
void expectNoTruncatedText(WidgetTester t, String where) {
  for (final ro in t.allRenderObjects.whereType<RenderParagraph>()) {
    if (!ro.attached || !ro.hasSize) continue;
    expect(
      ro.didExceedMaxLines,
      isFalse,
      reason: '$where: text cut off: "${ro.text.toPlainText()}"',
    );
  }
  pressed.add('truncation check: $where');
}

Future<void> finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  tearDownAll(() {
    // ignore: avoid_print
    print(
      'ROBOT pressed ${pressed.length} buttons/fields:\n'
      '${pressed.toSet().join(', ')}\n'
      'SCREENSHOTS (${shots.length}) in build/robot_shots/: ${shots.join(', ')}',
    );
  });

  testWidgets('mortgage: defaults, every input, chips, fees, extra, picker', (
    t,
  ) async {
    await boot(t);
    final s = sc(LoanKind.mortgage);
    // 기본값: $400k, 20% 계약금, 7%, 30년, 재산세 0.9%, 보험 $2,400
    expect(s.loanAmount, 320000);
    expect(monthlyText(t), expectedMonthly(LoanKind.mortgage));
    expect(monthlyText(t), money2(2128.97 + 300 + 200));
    expect(find.text('Paid off Oct 2056'), findsOneWidget);
    expect(find.byKey(const Key('banner')), findsOneWidget);
    await shot(t, '01_mortgage_default');

    // 집값을 고치면 쉼표가 붙고 월 납입액이 바로 바뀐다
    await typeInto(t, 'f-price', '500000');
    expect(fieldText(t, 'f-price'), '500,000');
    expect(s.price, 500000);
    // 계약금은 %(20%) 기준이라 $가 따라 바뀐다
    expect(s.downDollars, 100000);
    expect(monthlyText(t), expectedMonthly(LoanKind.mortgage));
    await done(t);
    expect(fieldText(t, 'f-down'), '100,000');

    // 계약금 $ 를 고치면 % 가 따라온다
    await typeInto(t, 'f-down', '50000');
    await done(t);
    expect(s.downIsPercent, isFalse);
    expect(fieldText(t, 'f-down-pct'), '10');
    // 20% 미만 → PMI 안내
    expect(find.text('Under 20% — PMI applies'), findsOneWidget);
    expect(calculate(s.toInput()).monthlyPmi, greaterThan(0));
    expect(monthlyText(t), expectedMonthly(LoanKind.mortgage));

    // % 를 고치면 $ 가 따라온다
    await typeInto(t, 'f-down-pct', '25');
    await done(t);
    expect(s.downIsPercent, isTrue);
    expect(fieldText(t, 'f-down'), '125,000');
    expect(find.text('Under 20% — PMI applies'), findsNothing);

    // 금리: 소수 3자리까지, 그 이상은 잘린다
    await typeInto(t, 'f-rate', '6.1259');
    expect(fieldText(t, 'f-rate'), '6.125');
    expect(s.rate, 6.125);
    await done(t);

    // 기간 칩
    for (final (m, label) in [(180, '15 yr'), (240, '20 yr'), (360, '30 yr')]) {
      await pressKey(t, 'term-$m', 'Term chip $label');
      expect(s.termMonths, m);
      expect(fieldText(t, 'f-term'), '${m ~/ 12}');
      expect(monthlyText(t), expectedMonthly(LoanKind.mortgage));
    }
    // 기간 직접 입력
    await typeInto(t, 'f-term', '25');
    expect(s.termMonths, 300);
    await done(t);

    // 첫 납입 달: 바퀴를 돌려 바꾼다
    await pressKey(t, 'f-start', 'First payment picker');
    expect(find.text('First payment'), findsWidgets);
    await t.drag(find.byKey(const Key('month-wheel')), const Offset(0, 72));
    await t.pumpAndSettle();
    await t.drag(find.byKey(const Key('year-wheel')), const Offset(0, -36));
    await t.pumpAndSettle();
    await shot(t, '02_month_picker');
    await pressKey(t, 'month-done', 'Picker: Done');
    expect((s.startYear, s.startMonth), (2027, 9));
    expect(find.text('Sep 2027'), findsOneWidget);

    // 세금·보험·HOA·PMI 펼치기
    await pressKey(t, 'fees-toggle', 'Taxes & fees: open');
    await typeInto(t, 'f-tax-pct', '1.2');
    await done(t);
    expect(s.taxYearly, closeTo(500000 * 0.012, 1e-6));
    expect(fieldText(t, 'f-tax'), '6,000');
    await typeInto(t, 'f-tax', '4800');
    await done(t);
    expect(s.taxIsPercent, isFalse);
    expect(fieldText(t, 'f-tax-pct'), '0.96');
    await typeInto(t, 'f-ins', '1500');
    await typeInto(t, 'f-hoa', '120');
    await typeInto(t, 'f-pmi', '0.8');
    await done(t);
    final r = calculate(s.toInput());
    expect(r.monthlyTax, 400);
    expect(r.monthlyInsurance, 125);
    expect(r.monthlyHoa, 120);
    expect(r.monthlyPmi, 0, reason: '25% down → no PMI');
    expect(monthlyText(t), money2(r.monthlyTotal));
    expect(find.text('Only if down payment is under 20%'), findsOneWidget);
    // 계약금을 5% 로 → PMI 가 붙고 끝나는 달이 보인다
    await typeInto(t, 'f-down-pct', '5');
    await done(t);
    expect(find.textContaining('(78% LTV)'), findsOneWidget);
    expect(calculate(s.toInput()).monthlyPmi, greaterThan(0));
    await reveal(t, find.byKey(const Key('card-fees')));
    await shot(t, '03_fees_open_pmi');
    await pressKey(t, 'fees-toggle', 'Taxes & fees: close');
    expect(find.byKey(const Key('f-hoa')), findsNothing);

    // 내역 도넛·합계
    await reveal(t, find.byKey(const Key('card-breakdown')));
    expect(find.text('Monthly breakdown'), findsOneWidget);
    expect(find.text('HOA dues'), findsOneWidget);
    await shot(t, '04_breakdown');

    // 추가 상환 칩: 켜기 → 결과 → 같은 칩 다시 누르면 끄기
    await pressKey(t, 'extra-200.0', 'Extra chip +\$200');
    expect(s.extra, 200);
    final e = extraEffect(s.toInput());
    expect(e.monthsSaved, greaterThan(0));
    await reveal(t, find.byKey(const Key('extra-result')));
    expect(
      find.text('Debt-free ${duration(e.monthsSaved)} sooner'),
      findsOneWidget,
    );
    expect(find.textContaining(money(e.interestSaved)), findsOneWidget);
    await toTop(t);
    expect(find.text('+ \$200 extra toward principal'), findsOneWidget);
    await shot(t, '05_extra_200');
    for (final v in [50.0, 100.0, 500.0]) {
      await pressKey(t, 'extra-$v', 'Extra chip +\$${v.round()}');
      expect(s.extra, v);
    }
    await pressKey(t, 'extra-500.0', 'Extra chip +\$500 again (off)');
    expect(s.extra, 0);
    expect(find.byKey(const Key('extra-result')), findsNothing);
    await typeInto(t, 'f-extra', '350');
    await done(t);
    expect(s.extra, 350);
    expect(find.byKey(const Key('extra-result')), findsOneWidget);
    await finish(t);
  });

  testWidgets('schedule: yearly, monthly, scroll to payoff, back', (t) async {
    await boot(t);
    await pressKey(t, 'extra-200.0', 'Extra chip +\$200');
    final res = calculate(sc(LoanKind.mortgage).toInput());
    await pressKey(t, 'open-schedule', 'Amortization schedule');
    expect(find.byType(ScheduleScreen), findsOneWidget);
    expect(find.text('Amortization schedule'), findsOneWidget);
    expect(find.byKey(const Key('row-y0')), findsOneWidget);
    final payoff = res.payoff!;
    expect(
      t.widget<Text>(find.byKey(const Key('sched-payoff'))).data,
      monthYear(payoff.$1, payoff.$2),
    );
    expect(find.textContaining('payments instead of 360'), findsOneWidget);
    await shot(t, '06_schedule_yearly');
    // 맨 아래 해 — 잔액 $0
    final list = find.descendant(
      of: find.byKey(const Key('schedule-list')),
      matching: find.byType(Scrollable),
    );
    final lastY = res.yearly.length - 1;
    await t.scrollUntilVisible(
      find.byKey(Key('row-y$lastY')),
      400,
      scrollable: list.first,
    );
    expect(balanceCell(t, 'row-y$lastY'), '\$0');
    await t.drag(list.first, const Offset(0, 4000));
    await t.pumpAndSettle();
    await press(t, find.byKey(const Key('view-false')), 'Schedule: Monthly');
    expect(find.byKey(const Key('row-m0')), findsOneWidget);
    expect(find.text('Nov 2026'), findsOneWidget);
    await shot(t, '07_schedule_monthly');
    final lastM = res.months - 1;
    await t.scrollUntilVisible(
      find.byKey(Key('row-m$lastM')),
      2000,
      scrollable: list.first,
      maxScrolls: 400,
    );
    expect(balanceCell(t, 'row-m$lastM'), '\$0.00');
    await shot(t, '08_schedule_last_payment');
    await t.drag(list.first, const Offset(0, 100000));
    await t.pumpAndSettle();
    await press(t, find.byKey(const Key('view-true')), 'Schedule: Yearly');
    await press(t, find.byKey(const Key('back')), 'Schedule: Back');
    expect(find.byType(ScheduleScreen), findsNothing);
    expect(find.byKey(const Key('monthly')), findsOneWidget);
    // 스와이프 뒤로가기 대신 시스템 뒤로 (안드로이드 버튼)
    await pressKey(t, 'open-schedule', 'Amortization schedule again');
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(ScheduleScreen), findsNothing);
    await finish(t);
  });

  testWidgets('auto and personal loans', (t) async {
    await boot(t);
    await pressKey(t, 'kind-LoanKind.auto', 'Mode: Auto');
    expect(find.text('Car loan'), findsOneWidget);
    expect(find.byKey(const Key('card-fees')), findsNothing);
    final a = sc(LoanKind.auto);
    expect(a.termMonths, 72);
    expect(a.loanAmount, 35000);
    expect(monthlyText(t), expectedMonthly(LoanKind.auto));
    await shot(t, '09_auto');
    await typeInto(t, 'f-trade', '8000');
    await typeInto(t, 'f-salestax', '6.25');
    await done(t);
    // (40000 − 8000) × 6.25% = 2000 판매세 → 40000 + 2000 − 8000 − 5000
    expect(a.salesTaxDollars, 2000);
    expect(a.loanAmount, 29000);
    expect(monthlyText(t), expectedMonthly(LoanKind.auto));
    await reveal(t, find.byKey(const Key('loan-amount')));
    expect(
      t.widget<Text>(find.byKey(const Key('loan-amount'))).data,
      '\$29,000',
    );
    for (final m in [36, 48, 60, 72, 84]) {
      await pressKey(t, 'term-$m', 'Auto term $m');
      expect(a.termMonths, m);
      expect(fieldText(t, 'f-term'), '$m');
    }
    await typeInto(t, 'f-down-pct', '10');
    await done(t);
    expect(a.downDollars, 4000);

    await pressKey(t, 'kind-LoanKind.personal', 'Mode: Personal');
    expect(find.text('Personal loan'), findsOneWidget);
    expect(find.byKey(const Key('f-down')), findsNothing);
    final p = sc(LoanKind.personal);
    expect(p.loanAmount, 10000);
    expect(monthlyText(t), money2(332.14));
    for (final m in [12, 24, 36, 48, 60]) {
      await pressKey(t, 'term-$m', 'Personal term $m');
      expect(p.termMonths, m);
    }
    await typeInto(t, 'f-price', '25000');
    await done(t);
    expect(monthlyText(t), expectedMonthly(LoanKind.personal));
    await shot(t, '10_personal');

    // 종류마다 값이 따로 남는다
    await pressKey(t, 'kind-LoanKind.mortgage', 'Mode: Mortgage');
    expect(sc(LoanKind.mortgage).price, 400000);
    await pressKey(t, 'kind-LoanKind.auto', 'Mode: Auto');
    expect(fieldText(t, 'f-trade'), '8,000');
    await finish(t);
  });

  testWidgets('keyboard up: Done bar, next/previous, compact payment', (
    t,
  ) async {
    for (final device in ['iPhone SE (750x1334)', 'iPhone 13 (1170x2532)']) {
      await boot(t, device: device);
      await t.tap(find.byKey(const Key('f-price')));
      final ratio = t.view.devicePixelRatio;
      t.view.viewInsets = FakeViewPadding(bottom: keyboardHeight * ratio);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('kb-done')), findsOneWidget);
      expect(
        find.byKey(const Key('banner')),
        findsNothing,
        reason: 'banner hides behind keyboard',
      );
      // 키보드가 떠도 월 납입액은 계속 보인다
      expect(find.byKey(const Key('monthly')), findsOneWidget);
      await t.enterText(fieldOf('f-price'), '450000');
      await t.pumpAndSettle();
      expect(monthlyText(t), expectedMonthly(LoanKind.mortgage));
      await shot(
        t,
        '11_keyboard_${device.startsWith('iPhone SE') ? 'se' : '13'}',
      );
      // 다음 칸 → 계약금 $, % … 이전 칸 → 집값
      await press(t, find.byKey(const Key('kb-next')), 'Keyboard: Next');
      expect(
        t.widget<EditableText>(fieldOf('f-down')).focusNode.hasFocus,
        isTrue,
      );
      await press(t, find.byKey(const Key('kb-next')), 'Keyboard: Next');
      expect(
        t.widget<EditableText>(fieldOf('f-down-pct')).focusNode.hasFocus,
        isTrue,
      );
      await press(t, find.byKey(const Key('kb-next')), 'Keyboard: Next');
      expect(
        t.widget<EditableText>(fieldOf('f-rate')).focusNode.hasFocus,
        isTrue,
      );
      // 맨 아래 칸에서도 칸이 키보드에 가려지지 않는다
      final fieldBottom = t.getRect(find.byKey(const Key('f-rate'))).bottom;
      final barTop = t.getRect(find.byKey(const Key('kb-done'))).top;
      expect(fieldBottom, lessThanOrEqualTo(barTop));
      await press(t, find.byKey(const Key('kb-prev')), 'Keyboard: Previous');
      await press(t, find.byKey(const Key('kb-prev')), 'Keyboard: Previous');
      await press(t, find.byKey(const Key('kb-prev')), 'Keyboard: Previous');
      expect(
        t.widget<EditableText>(fieldOf('f-price')).focusNode.hasFocus,
        isTrue,
      );
      await press(t, find.byKey(const Key('kb-done')), 'Keyboard: Done');
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );
      t.view.resetViewInsets();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('banner')), findsOneWidget);
      // 맨 아래 칸(추가 상환)도 키보드 위로 올라온다
      await typeInto(t, 'f-extra', '100');
      t.view.viewInsets = FakeViewPadding(bottom: keyboardHeight * ratio);
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('f-extra')));
      await t.pumpAndSettle();
      expect(
        t.getRect(find.byKey(const Key('f-extra'))).bottom,
        lessThanOrEqualTo(t.getRect(find.byKey(const Key('kb-done'))).top),
      );
      await press(t, find.byKey(const Key('kb-done')), 'Keyboard: Done');
      t.view.resetViewInsets();
      await finish(t);
    }
  });

  testWidgets(
    'top card folds to one line when scrolling down, unfolds at top',
    (t) async {
      await boot(t, device: 'iPhone SE (750x1334)');
      final tall = t.getSize(find.byKey(const Key('result-card'))).height;
      expect(find.text('Paid off Oct 2056'), findsOneWidget);
      await t.drag(formScroll.first, const Offset(0, -200));
      await t.pumpAndSettle();
      pressed.add('scroll down');
      final short = t.getSize(find.byKey(const Key('result-card'))).height;
      expect(short, lessThan(tall - 60));
      expect(find.text('Paid off Oct 2056'), findsNothing);
      expect(find.byKey(const Key('monthly')), findsOneWidget);
      await shot(t, '14_folded_se');
      await toTop(t);
      pressed.add('scroll up');
      expect(t.getSize(find.byKey(const Key('result-card'))).height, tall);
      await finish(t);
    },
  );

  testWidgets('VoiceOver: each number field is one labelled text box', (
    t,
  ) async {
    final sem = t.ensureSemantics();
    await boot(t);
    await pressKey(t, 'fees-toggle', 'Taxes & fees: open');
    await toTop(t);
    for (final label in [
      'Home price',
      'Down payment dollars',
      'Down payment percent',
      'Interest rate percent',
      'Loan term years',
    ]) {
      final f = find.bySemanticsLabel(label);
      expect(f, findsOneWidget, reason: label);
      expect(
        t.getSemantics(f).flagsCollection.isTextField,
        isTrue,
        reason: '$label must be a text field',
      );
    }
    // 입력 칸 수 == 화면 읽기 입력 칸 수 (겹쳐서 두 번 읽히지 않는다)
    final fields = find.byType(EditableText).evaluate().length;
    final boxes = find.semantics
        .byPredicate((n) => n.flagsCollection.isTextField)
        .evaluate()
        .length;
    expect(boxes, fields);
    pressed.add('semantics check: $fields fields');
    sem.dispose();
    await finish(t);
  });

  testWidgets('about, reset (cancel + confirm), values survive a restart', (
    t,
  ) async {
    await boot(t);
    await pressKey(t, 'about', 'About');
    expect(find.text('Estimates only'), findsOneWidget);
    await shot(t, '12_about');
    await pressKey(t, 'about-close', 'About: Close');
    expect(find.text('Estimates only'), findsNothing);

    await typeInto(t, 'f-price', '612345');
    await done(t);
    await pressKey(t, 'kind-LoanKind.auto', 'Mode: Auto');
    // 다시 켜기: 저장된 값으로 열린다 (마지막 모드 포함)
    await finish(t);
    await boot(t, resetPrefs: false);
    expect(find.text('Car loan'), findsOneWidget);
    await pressKey(t, 'kind-LoanKind.mortgage', 'Mode: Mortgage');
    expect(fieldText(t, 'f-price'), '612,345');

    await pressKey(t, 'reset', 'Reset');
    expect(find.text('Reset this calculator?'), findsOneWidget);
    await pressKey(t, 'reset-cancel', 'Reset: Cancel');
    expect(sc(LoanKind.mortgage).price, 612345);
    await pressKey(t, 'reset', 'Reset');
    await pressKey(t, 'reset-ok', 'Reset: Confirm');
    expect(sc(LoanKind.mortgage).price, 400000);
    await t.drag(formScroll.first, const Offset(0, 3000));
    await t.pumpAndSettle();
    expect(fieldText(t, 'f-price'), '400,000');
    await finish(t);
  });

  testWidgets('expensive house: big amounts never cut off text (all devices)', (
    t,
  ) async {
    for (final device in devices.keys) {
      await boot(t, device: device);
      await typeInto(t, 'f-price', '2500000');
      await typeInto(t, 'f-rate', '7.25');
      await typeInto(t, 'f-extra', '1500');
      await done(t);
      await toTop(t);
      for (var k = 0; k < 8; k++) {
        expectNoTruncatedText(t, '\$2.5M house $device scroll $k');
        expectNoClippedFields(t, '\$2.5M house $device scroll $k');
        await t.drag(formScroll.first, const Offset(0, -250));
        await t.pumpAndSettle();
      }
      if (device.startsWith('iPhone 13')) {
        await shot(t, '15_expensive_house_13');
      }
      await finish(t);
    }
  });

  testWidgets('empty, zero and huge inputs never break the screen', (t) async {
    await boot(t, device: 'iPhone SE (750x1334)');
    await typeInto(t, 'f-price', '');
    await done(t);
    expect(monthlyText(t), '\$0.00');
    await toTop(t);
    expect(
      find.text('Enter a price and loan term to see your payment.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('open-schedule')), findsNothing);
    await typeInto(t, 'f-price', '300000');
    await typeInto(t, 'f-term', '0');
    await done(t);
    expect(monthlyText(t), '\$0.00');
    await typeInto(t, 'f-term', '30');
    await typeInto(t, 'f-rate', '0');
    await done(t);
    expect(monthlyText(t), expectedMonthly(LoanKind.mortgage));
    // 아주 큰 값: 줄이 넘치지 않는다 (넘치면 Flutter 가 예외를 던져 실패)
    await typeInto(t, 'f-price', '9999999999');
    expect(fieldText(t, 'f-price'), '99,999,999', reason: 'max 8 digits');
    await typeInto(t, 'f-rate', '99');
    await typeInto(t, 'f-term', '50');
    await pressKey(t, 'fees-toggle', 'Taxes & fees: open');
    await typeInto(t, 'f-tax', '9999999');
    await typeInto(t, 'f-ins', '999999');
    await typeInto(t, 'f-hoa', '99999');
    await typeInto(t, 'f-extra', '9999999');
    await done(t);
    await t.drag(formScroll.first, const Offset(0, 5000));
    await t.pumpAndSettle();
    await shot(t, '13_huge_values_se');
    await pressKey(t, 'open-schedule', 'Amortization schedule (huge)');
    await press(t, find.byKey(const Key('view-false')), 'Schedule: Monthly');
    await press(t, find.byKey(const Key('back')), 'Schedule: Back');
    // 이상한 글자는 들어가지 않는다
    await typeInto(t, 'f-price', 'abc12.5x');
    expect(fieldText(t, 'f-price'), '12', reason: 'no decimals in dollars');
    await done(t);
    await finish(t);
  });

  testWidgets('layout sweep: every device × mode × open card, light and dark', (
    t,
  ) async {
    for (final device in devices.keys) {
      for (final b in Brightness.values) {
        await boot(t, device: device, brightness: b);
        for (final k in LoanKind.values) {
          await pressKey(t, 'kind-$k', 'Mode ${k.name} ($device ${b.name})');
          if (k == LoanKind.mortgage) {
            await pressKey(t, 'fees-toggle', 'Fees open');
            await typeInto(t, 'f-down-pct', '18.75');
            await typeInto(t, 'f-tax', '4800');
            await done(t);
            expect(fieldText(t, 'f-tax-pct'), '1.2');
            await typeInto(t, 'f-price', '412345');
            await done(t);
            await reveal(t, find.byKey(const Key('f-tax-pct')));
            expectNoClippedFields(t, 'fees $device');
          }
          if (k == LoanKind.auto) {
            await typeInto(t, 'f-down', '5000');
            await done(t);
            expect(fieldText(t, 'f-down-pct'), '12.5');
            await typeInto(t, 'f-salestax', '10.375');
            await done(t);
            expectNoClippedFields(t, 'auto $device');
          }
          await t.drag(formScroll.first, const Offset(0, 5000));
          await t.pumpAndSettle();
          expectNoClippedFields(t, '${k.name} top $device');
          // 아래로 훑으면서 잘린 글자 검사
          for (var k2 = 0; k2 < 8; k2++) {
            expectNoTruncatedText(t, '${k.name} $device scroll $k2');
            await t.drag(formScroll.first, const Offset(0, -250));
            await t.pumpAndSettle();
          }
          await t.drag(formScroll.first, const Offset(0, 5000));
          await t.pumpAndSettle();
          await pressKey(t, 'extra-100.0', 'Extra +\$100');
          await t.drag(formScroll.first, const Offset(0, -5000));
          await t.pumpAndSettle();
          final tag = device
              .split(' (')
              .first
              .replaceAll(' ', '')
              .toLowerCase();
          if (k == LoanKind.mortgage) {
            await shot(t, '20_sweep_${tag}_${b.name}_bottom');
          }
          await pressKey(t, 'open-schedule', 'Schedule');
          await press(t, find.byKey(const Key('view-false')), 'Monthly');
          await press(t, find.byKey(const Key('back')), 'Back');
          await t.drag(formScroll.first, const Offset(0, 5000));
          await t.pumpAndSettle();
        }
        final tag = device.split(' (').first.replaceAll(' ', '').toLowerCase();
        await pressKey(t, 'kind-LoanKind.mortgage', 'Mode mortgage');
        await shot(t, '21_sweep_${tag}_${b.name}_top');
        await finish(t);
      }
    }
  });
}
