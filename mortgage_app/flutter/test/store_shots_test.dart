// 스토어 스크린샷 원본 찍기 (iPhone 13 화면 1170×2532, 광고 자리 없이).
// 실행: flutter test test/store_shots_test.dart  → ../store/screenshots/raw/*.png
// 그다음 node ../store/screenshots/make.js 로 1290×2796 홍보 이미지를 만든다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mortgage/core/ads.dart';

import 'robot_test.dart' as r;

/// 스토어 사진에는 광고 자리를 비우지 않는다.
class _NoAds extends FakeAds {
  @override
  Widget banner() => const SizedBox.shrink();
}

Future<void> raw(WidgetTester t, String name) async {
  final view = t.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  await t.runAsync(() async {
    final img = await layer.toImage(Offset.zero & t.view.physicalSize);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('../store/screenshots/raw')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('store screenshots', (t) async {
    await r.boot(t, ads: _NoAds());
    await raw(t, '1-payment');

    // 세금·보험·PMI 펼친 화면 (계약금 10% → PMI)
    await r.typeInto(t, 'f-down-pct', '10');
    await r.done(t);
    await r.pressKey(t, 'fees-toggle', 'fees');
    await r.toTop(t);
    await t.drag(r.formScroll.first, const Offset(0, -560));
    await t.pumpAndSettle();
    await raw(t, '2-fees');

    // 내역 도넛
    await r.reveal(t, find.byKey(const Key('card-breakdown')));
    await t.drag(r.formScroll.first, const Offset(0, 120));
    await t.pumpAndSettle();
    await raw(t, '3-breakdown');

    // 추가 상환
    await r.pressKey(t, 'extra-200.0', 'extra');
    await r.reveal(t, find.byKey(const Key('card-extra')));
    await t.drag(r.formScroll.first, const Offset(0, 100));
    await t.pumpAndSettle();
    await raw(t, '4-extra');

    // 상환표
    await r.pressKey(t, 'open-schedule', 'schedule');
    await raw(t, '5-schedule');
    await r.press(t, find.byKey(const Key('back')), 'back');

    // 자동차 대출
    await r.pressKey(t, 'kind-LoanKind.auto', 'auto');
    await raw(t, '6-auto');
    await t.pumpWidget(const SizedBox());
  });
}
