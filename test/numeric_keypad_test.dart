import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cheemow_pos/widgets/numeric_keypad.dart';

void main() {
  testWidgets('NumericKeypad taps emit keys in order', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumericKeypad(
            keys: const [
              ['1','2','3'],
              ['⌫'],
            ],
            onKeyTap: (k) => pressed.add(k),
          ),
        ),
      ),
    );

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.tap(find.text('⌫'));
    await tester.pump();

    expect(pressed, ['1','2','3','⌫']);
  });
}
