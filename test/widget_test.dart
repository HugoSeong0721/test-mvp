import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iottie_automation/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('unlocks the web entry screen with the shared password', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TestMvpApp());

    expect(find.text('Choose where you are heading.'), findsOneWidget);

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Continue as Practitioner'),
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Continue as Practitioner'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Practitioner Login'), findsWidgets);
    expect(
      find.text(
        'Demo account: 123 / 123 or log in with a practitioner account created in this browser.',
      ),
      findsOneWidget,
    );
  });
}
