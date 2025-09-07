// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cheemow_pos/main.dart';

void main() {
  testWidgets('POS App smoke test', (WidgetTester tester) async {
    // Mock SharedPreferences for testing
    SharedPreferences.setMockInitialValues(<String, Object>{});
    
        // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());
    
    // Wait for the app to initialize
    await tester.pumpAndSettle();

    // Verify that the app title is correct
    expect(find.text('Cheemow POS'), findsOneWidget);
    
    // You can add more specific tests for your POS functionality here
    // For example, testing if the product list loads correctly
  });
}
