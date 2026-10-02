import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:somrate/core/currencies.dart';
import 'package:somrate/core/store.dart';
import 'package:somrate/main.dart';

// 아이폰 13 너비에서 모든 통화를 기준/비교 통화로 넣어 봐도 줄이 넘치지 않아야 한다.
// (긴 이름 + 현지 시각 "+1d 00:08" 때문에 환율 글자가 화면 밖으로 밀린 적이 있다)
void main() {
  for (final base in ['USD', 'KRW', 'BTC']) {
    testWidgets('no overflow with every currency, base $base', (t) async {
      tzdata.initializeTimeZones();
      t.view.physicalSize = const Size(1170, 2532);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final targets = currencies.map((c) => c.code).where((c) => c != base).toList();
      SharedPreferences.setMockInitialValues({
        'fx-app-v1': jsonEncode({
          'base': base, 'buf': '123456789', 'targets': targets,
          'active': base, 'onboarded': true,
        }),
      });
      await AppStore.i.load();
      await t.pumpWidget(const GlanceApp());
      await t.pump(const Duration(seconds: 1));
      // 목록 끝까지 내리며 모든 줄을 실제로 그려 본다 (넘치면 테스트가 예외로 실패)
      for (var i = 0; i < 12; i++) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(t.takeException(), isNull);
    });
  }
}
