// 1.1 기능 로봇: 주 선택(재산세·판매세 자동 입력), 추가 상환 시작 달·한 번 크게 갚기·격주 납부.
// 모든 기기에서 새 칸이 잘리지 않는지도 본다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mortgage/core/counties.dart';
import 'package:mortgage/core/format.dart';
import 'package:mortgage/core/loan.dart';
import 'package:mortgage/core/states.dart';

import 'robot_test.dart' as r;

Future<void> pickState(WidgetTester t, String code) async {
  await r.pressKey(t, 'f-state', 'State picker');
  expect(find.text('Choose your state'), findsOneWidget);
  final list = find.descendant(
    of: find.byKey(const Key('state-list')),
    matching: find.byType(Scrollable),
  );
  // 시트는 지금 고른 주 근처로 열린다 → 맨 위에서부터 훑는다
  await t.drag(list.first, const Offset(0, 5000));
  await t.pumpAndSettle();
  await t.scrollUntilVisible(
    find.byKey(Key('state-$code')),
    300,
    scrollable: list.first,
  );
  await t.ensureVisible(find.byKey(Key('state-$code')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key('state-$code')));
  r.pressed.add('State $code');
  await t.pumpAndSettle();
}

void main() {
  // 화면 밖·가려진 곳을 눌러 놓고 '통과'하는 일이 없게
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  test('state table: 51 entries, sane ranges, no-sales-tax states', () {
    expect(usStates.length, 51);
    expect(usStates.map((s) => s.code).toSet().length, 51);
    for (final s in usStates) {
      expect(s.propertyTax, inInclusiveRange(0.2, 2.5), reason: s.name);
      expect(s.combinedSalesTax, inInclusiveRange(0, 11), reason: s.name);
    }
    for (final c in ['AK', 'DE', 'MT', 'NH', 'OR']) {
      expect(stateByCode(c)!.salesTax, 0, reason: c);
    }
    expect(
      stateByCode('NJ')!.combinedSalesTax,
      6.625,
      reason: 'negative local clamps to 0',
    );
  });

  testWidgets('mortgage: choose a state fills property tax, edit still works', (
    t,
  ) async {
    await r.boot(t);
    final s = r.sc(LoanKind.mortgage);
    await r.pressKey(t, 'fees-toggle', 'fees open');
    await pickState(t, 'TX');
    expect(s.stateCode, 'TX');
    expect(s.tax, 1.4);
    expect(s.taxIsPercent, isTrue);
    expect(find.text('Texas average · per year'), findsOneWidget);
    expect(r.monthlyText(t), r.expectedMonthly(LoanKind.mortgage));
    await r.shot(t, '30_state_texas');
    // 카운티 세율로 직접 고치면 '평균' 표시가 사라진다
    await r.typeInto(t, 'f-tax-pct', '2.1');
    await r.done(t);
    expect(s.tax, 2.1);
    expect(find.text('Texas average · per year'), findsNothing);
    // 다시 다른 주
    await pickState(t, 'HI');
    expect(s.tax, 0.29);
    // 취소는 아무것도 안 바꾼다
    await r.pressKey(t, 'f-state', 'State picker');
    await r.press(t, find.byKey(const Key('state-close')), 'State: Cancel');
    expect(s.stateCode, 'HI');
    await r.finish(t);
  });

  testWidgets('auto: choose a state fills sales tax (state + avg local)', (
    t,
  ) async {
    await r.boot(t);
    await r.pressKey(t, 'kind-LoanKind.auto', 'Auto');
    final a = r.sc(LoanKind.auto);
    await pickState(t, 'CA');
    expect(a.salesTax, closeTo(7.25 + 1.74, 1e-9));
    expect(find.text('California state + avg. local'), findsOneWidget);
    expect(r.fieldText(t, 'f-salestax'), '8.99');
    expect(r.monthlyText(t), r.expectedMonthly(LoanKind.auto));
    // 주는 종류마다 따로 (집 쪽은 그대로)
    expect(r.sc(LoanKind.mortgage).stateCode, isNull);
    await r.finish(t);
  });

  testWidgets('extras: start month, one-time payment, bi-weekly', (t) async {
    await r.boot(t);
    final s = r.sc(LoanKind.mortgage);
    expect(
      find.byKey(const Key('f-extra-from')),
      findsNothing,
      reason: 'only with a monthly extra',
    );
    await r.pressKey(t, 'extra-200.0', 'Extra +\$200');
    await r.pressKey(t, 'f-extra-from', 'Starting picker');
    expect(find.text('Extra payments start'), findsOneWidget);
    await t.drag(
      find.byKey(const Key('year-wheel')),
      const Offset(0, -72),
    ); // +2년
    await t.pumpAndSettle();
    await r.pressKey(t, 'month-done', 'Picker: Done');
    expect((s.extraFromYear, s.extraFromMonth), (2028, 11));
    var e = extraEffect(s.toInput());
    expect(e.withExtra.schedule.first.extra, 0);
    expect(
      find.text('Debt-free ${duration(e.monthsSaved)} sooner'),
      findsOneWidget,
    );

    await r.typeInto(t, 'f-lump', '10000');
    await r.done(t);
    expect(s.lump, 10000);
    expect(
      (s.lumpYear, s.lumpMonth),
      (2027, 11),
      reason: 'defaults to a year after the first payment',
    );
    await r.pressKey(t, 'f-lump-when', 'One-time picker');
    await r.pressKey(t, 'month-done', 'Picker: Done');

    await r.reveal(t, find.byKey(const Key('f-biweekly')));
    await t.tap(find.byKey(const Key('f-biweekly')));
    r.pressed.add('Bi-weekly on');
    await t.pumpAndSettle();
    expect(s.biweekly, isTrue);
    e = extraEffect(s.toInput());
    expect(
      find.text('Debt-free ${duration(e.monthsSaved)} sooner'),
      findsOneWidget,
    );
    expect(find.textContaining(money(e.interestSaved)), findsOneWidget);
    await r.reveal(t, find.byKey(const Key('extra-result')));
    await r.shot(t, '31_extras_all');
    await r.toTop(t);
    expect(
      find.text(
        '+ \$200/mo · bi-weekly · \$10,000 once extra toward principal',
      ),
      findsOneWidget,
    );

    // 상환표에도 반영
    await r.pressKey(t, 'open-schedule', 'Schedule');
    expect(find.textContaining('payments instead of 360'), findsOneWidget);
    await r.press(t, find.byKey(const Key('back')), 'Back');

    // 끄면 효과 사라짐
    await r.reveal(t, find.byKey(const Key('f-biweekly')));
    await t.tap(find.byKey(const Key('f-biweekly')));
    await t.pumpAndSettle();
    await r.pressKey(t, 'extra-200.0', 'Extra off');
    await r.typeInto(t, 'f-lump', '0');
    await r.done(t);
    expect(s.toInput().hasExtras, isFalse);
    expect(find.byKey(const Key('extra-result')), findsNothing);

    // 다시 켜도 저장돼 다음 실행에 남는다
    await r.pressKey(t, 'extra-100.0', 'Extra +\$100');
    await r.finish(t);
    await r.boot(t, resetPrefs: false);
    expect(r.sc(LoanKind.mortgage).extraFromYear, 2028);
    await r.finish(t);
  });

  testWidgets('new rows never cut off text on any device', (t) async {
    for (final device in r.devices.keys) {
      await r.boot(t, device: device);
      await r.pressKey(t, 'fees-toggle', 'fees open');
      await pickState(t, 'MA');
      await r.pressKey(t, 'extra-500.0', 'Extra +\$500');
      await r.typeInto(t, 'f-lump', '25000');
      await r.done(t);
      await r.toTop(t);
      for (var k = 0; k < 10; k++) {
        r.expectNoTruncatedText(t, '1.1 $device $k');
        r.expectNoClippedFields(t, '1.1 $device $k');
        await t.drag(r.formScroll.first, const Offset(0, -250));
        await t.pumpAndSettle();
      }
      await r.pressKey(t, 'kind-LoanKind.auto', 'Auto');
      await pickState(t, 'NY');
      r.expectNoTruncatedText(t, 'auto state $device');
      await r.finish(t);
    }
  });

  test('county table: every state has counties, sane rates', () {
    var total = 0;
    for (final st in usStates) {
      final cs = countiesOf(st.code);
      expect(cs, isNotEmpty, reason: st.code);
      total += cs.length;
      for (final c in cs) {
        expect(
          c.rate,
          inInclusiveRange(0.05, 4),
          reason: '${st.code} ${c.name}',
        );
      }
    }
    expect(total, greaterThan(3000));
    expect(countyOf('TX', 'Harris County')!.rate, 1.62);
    expect(countiesOf('XX'), isEmpty);
  });

  testWidgets('mortgage: state then county fills county property tax', (
    t,
  ) async {
    for (final device in r.devices.keys) {
      await r.boot(t, device: device);
      final s = r.sc(LoanKind.mortgage);
      await r.pressKey(t, 'fees-toggle', 'fees open');
      expect(
        find.byKey(const Key('f-county')),
        findsNothing,
        reason: 'county after state',
      );
      await pickState(t, 'TX');
      await r.pressKey(t, 'f-county', 'County picker');
      expect(find.text('Choose your county'), findsOneWidget);
      await t.enterText(find.byKey(const Key('county-search')), 'harr');
      await t.pumpAndSettle();
      r.pressed.add('County search');
      expect(find.byKey(const Key('county-Harris County')), findsOneWidget);
      expect(find.byKey(const Key('county-Travis County')), findsNothing);
      if (device.startsWith('iPhone 13')) await r.shot(t, '32_county_search');
      await t.tap(find.byKey(const Key('county-Harris County')));
      await t.pumpAndSettle();
      r.pressed.add('County Harris');
      expect(s.countyName, 'Harris County');
      expect(s.tax, 1.62);
      expect(find.text('Harris County average · per year'), findsOneWidget);
      expect(r.monthlyText(t), r.expectedMonthly(LoanKind.mortgage));
      r.expectNoTruncatedText(t, 'county row $device');
      // 검색 결과 없음 + 취소
      await r.pressKey(t, 'f-county', 'County picker');
      await t.enterText(find.byKey(const Key('county-search')), 'zzzz');
      await t.pumpAndSettle();
      expect(find.text('No county found'), findsOneWidget);
      await r.press(t, find.byKey(const Key('county-close')), 'County: Cancel');
      expect(s.countyName, 'Harris County');
      // 주를 바꾸면 카운티는 지워진다
      await pickState(t, 'NJ');
      expect(s.countyName, isNull);
      expect(s.tax, 1.88);
      // DC 는 카운티가 하나라 행이 안 보인다
      await pickState(t, 'DC');
      expect(find.byKey(const Key('f-county')), findsNothing);
      await r.finish(t);
    }
  });
}
