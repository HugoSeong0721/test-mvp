import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:somrate/core/store.dart';
import 'package:somrate/main.dart';

// 비교 통화 줄을 꾹 눌러 끌면 순서가 바뀌고, 저장된 뒤에도 유지돼야 한다.
void main() {
  testWidgets('long-press drag reorders currency rows', (t) async {
    tzdata.initializeTimeZones();
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({
      'fx-app-v1': '{"base":"USD","buf":"100","targets":["EUR","GBP","MXN"],"active":"USD","onboarded":true}',
    });
    await AppStore.i.load();
    await t.pumpWidget(const GlanceApp());
    await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
    expect(AppStore.i.targets, ['EUR', 'GBP', 'MXN']);

    // EUR 줄을 꾹 누르고 MXN 아래로 끌기
    final from = t.getCenter(find.text('Euro', findRichText: true).first);
    final to = t.getCenter(find.text('Mexican Peso', findRichText: true).first);
    final g = await t.startGesture(from);
    await t.pump(const Duration(milliseconds: 600)); // long press
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset(from.dx, from.dy + (to.dy - from.dy + 40) * i / 10));
      await t.pump(const Duration(milliseconds: 30));
    }
    await g.up();
    await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
    expect(AppStore.i.targets, ['GBP', 'MXN', 'EUR']);

    // 짧게 탭하면 순서가 안 바뀌고 금액 입력이 열린다 (탭과 끌기가 섞이지 않아야 함)
    await t.tap(find.text('Mexican Peso', findRichText: true).first);
    await t.pump();
    expect(AppStore.i.targets, ['GBP', 'MXN', 'EUR']);

    // 저장 확인: 다시 불러와도 순서 유지
    await AppStore.i.load();
    expect(AppStore.i.targets, ['GBP', 'MXN', 'EUR']);
  });

  testWidgets('top (base) row can be dragged down, and a row dragged to the top becomes base', (t) async {
    tzdata.initializeTimeZones();
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({
      'fx-app-v1': '{"base":"USD","buf":"100","targets":["EUR","GBP","MXN"],"active":"USD","onboarded":true}',
    });
    await AppStore.i.load();
    await t.pumpWidget(const GlanceApp());
    await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));

    Future<void> drag(String fromName, String toName, double extra) async {
      final from = t.getCenter(find.text(fromName, findRichText: true).first);
      final to = t.getCenter(find.text(toName, findRichText: true).first);
      final g = await t.startGesture(from);
      await t.pump(const Duration(milliseconds: 600));
      for (var i = 1; i <= 12; i++) {
        await g.moveTo(Offset(from.dx, from.dy + (to.dy - from.dy + extra) * i / 12));
        await t.pump(const Duration(milliseconds: 30));
      }
      await g.up();
      await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
    }

    // 맨 위 USD 를 GBP 아래로 → EUR 가 기준 통화, USD 는 목록 안으로
    await drag('US Dollar', 'British Pound', 0);
    expect(AppStore.i.base, 'EUR');
    expect(AppStore.i.targets, ['GBP', 'USD', 'MXN']);
    expect(t.takeException(), isNull);

    // MXN 을 맨 위로 → MXN 이 기준 통화
    await drag('Mexican Peso', 'Euro', -60);
    expect(AppStore.i.base, 'MXN');
    expect(AppStore.i.targets, ['EUR', 'GBP', 'USD']);

    // 금액은 그대로 이어져야 한다 (입력하던 통화의 금액 유지)
    expect(AppStore.i.active, 'USD');
    expect(AppStore.i.buf, '100');

    await AppStore.i.load();
    expect(AppStore.i.base, 'MXN');
    expect(AppStore.i.targets, ['EUR', 'GBP', 'USD']);
  });
}
