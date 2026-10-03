// 아래로 내린 뒤 대출 종류를 바꾸면 맨 위(펼친 카드)에서 시작해야 한다.
// (고치기 전: 같은 키 카드가 옛 위치째 재사용돼 380px 아래에서 멈췄다)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'robot_test.dart' as r;

void main() {
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  testWidgets('switching loan type after scrolling lands at the top', (
    t,
  ) async {
    for (final device in r.devices.keys) {
      await r.boot(t, device: device);
      for (final k in ['auto', 'personal', 'mortgage']) {
        await t.drag(r.formScroll.first, const Offset(0, -1500));
        await t.pumpAndSettle();
        await r.pressKey(t, 'kind-LoanKind.$k', 'Mode $k after scroll');
        final pos = t.state<ScrollableState>(r.formScroll.first).position;
        expect(pos.pixels, 0, reason: '$device $k');
        expect(
          find.textContaining('Paid off'),
          findsOneWidget,
          reason: 'top card unfolded',
        );
      }
      await t.pumpWidget(const SizedBox());
    }
  });
}
