import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:somrate/core/store.dart';
import 'package:somrate/main.dart';

void main() {
  testWidgets('onboarding → convert → chart in English', (t) async {
    tzdata.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
    await AppStore.i.load();
    await t.pumpWidget(const GlanceApp());
    await t.pump();
    expect(find.textContaining('Which currency'), findsOneWidget);
    expect(find.text('POPULAR'), findsOneWidget);
    await t.tap(find.text('USD').first);
    await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('Convert'), findsOneWidget);
    expect(find.text('EUR'), findsWidgets);
    expect(find.text('Add currency'), findsOneWidget);
    await t.tap(find.text('Chart'));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('1M'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
    await t.pump(const Duration(seconds: 20));
    final ko = RegExp(r'[가-힣]');
    for (final w in t.widgetList<Text>(find.byType(Text))) {
      expect(ko.hasMatch(w.data ?? ''), isFalse, reason: 'Korean text: ${w.data}');
    }
  });
}
