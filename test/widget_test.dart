import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iottie_automation/app.dart';

void main() {
  testWidgets('unlocks the web entry screen with the shared password', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TestMvpApp());

    expect(find.text('Preview Login'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Daisy');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Login'));
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Choose the right portal route'), findsOneWidget);
    expect(find.text('Practitioner Login'), findsWidgets);
    expect(find.text('Patient Test Login'), findsWidgets);
    expect(find.text('Friend Beta Sign Up / Login'), findsWidgets);
  });
}
