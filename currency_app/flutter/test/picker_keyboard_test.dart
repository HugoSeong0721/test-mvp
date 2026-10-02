import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:somrate/core/store.dart';
import 'package:somrate/core/theme.dart';
import 'package:somrate/features/converter/currency_picker_sheet.dart';

// 키보드가 올라온 상태에서 검색해도 검색창과 결과가 키보드 위에 보여야 한다.
void main() {
  testWidgets('picker stays above keyboard while searching', (t) async {
    SharedPreferences.setMockInitialValues({});
    await AppStore.i.load();
    t.view.physicalSize = const Size(1170, 2532); // iPhone 13
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    const kb = 336.0; // iPhone 키보드 높이(논리 px)

    await t.pumpWidget(MaterialApp(
      theme: buildTheme(Fx.dark, Brightness.dark),
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  CurrencyPickerSheet.show(c, mode: PickMode.add),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    t.view.viewInsets = const FakeViewPadding(bottom: kb * 3);
    await t.tap(find.byType(TextField));
    await t.enterText(find.byType(TextField), 'gold');
    await t.pumpAndSettle();

    final screenH = 2532 / 3;
    final field = t.getRect(find.byType(TextField));
    expect(field.bottom, lessThan(screenH - kb), reason: '검색창이 키보드에 가려짐');
    expect(t.widget<TextField>(find.byType(TextField)).controller?.text ?? 'gold', 'gold');
    final xau = t.getRect(find.text('XAU'));
    expect(xau.bottom, lessThan(screenH - kb), reason: '검색 결과가 키보드에 가려짐');

    // 맨 아래 항목까지 스크롤하면 키보드 위로 올라와야 한다
    await t.enterText(find.byType(TextField), '');
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('XPD'), 300,
        scrollable: find.byType(Scrollable).last);
    await t.pumpAndSettle();
    expect(t.getRect(find.text('XPD')).bottom, lessThan(screenH - kb),
        reason: '맨 아래 항목이 키보드 뒤에 있음');
  });
}
