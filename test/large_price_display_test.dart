import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/widgets/price_display.dart';

void main() {
  testWidgets('LargePriceDisplay shows thousands formatting', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LargePriceDisplay(amount: 1234567)),
      ),
    );
    // Expect to find the formatted text 1,234,567
    expect(find.text('1,234,567'), findsOneWidget);
    // And the money icon now uses plain '$'
    expect(find.text('\$'), findsOneWidget);
  });
}
