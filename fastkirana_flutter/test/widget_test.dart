import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FastKirana App Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('FastKirana Express'),
          ),
        ),
      ),
    );
    expect(find.text('FastKirana Express'), findsOneWidget);
  });
}
