import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_2/main.dart';

void main() {
  testWidgets('music app navigates between its main sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AuroraApp(enableAudio: false));

    expect(find.text('Afterglow'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.explore_rounded));
    await tester.pump();

    expect(find.text('Find your next sound'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.library_music_rounded));
    await tester.pump();

    expect(find.text('Your library'), findsOneWidget);
  });
}
