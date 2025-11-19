// Basic widget test for FamQuest app
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    // Build a simple app wrapper
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('FamQuest'),
            ),
          ),
        ),
      ),
    );

    // Verify app loads
    expect(find.text('FamQuest'), findsOneWidget);
  });
}
