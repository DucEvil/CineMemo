// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todoapp/app.dart';
import 'package:todoapp/bootstrap/app_bootstrap.dart';

void main() {
  testWidgets('CineMemo app renders MaterialApp', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const CineMemoRootApp(
        bootstrap: AppBootstrapResult(
          firebaseReady: false,
          localStorageReady: true,
        ),
      ),
    );

    // Smoke test: root app should provide a MaterialApp.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
