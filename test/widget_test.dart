// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/main.dart';
import 'package:cheemeow_pos/services/time_service.dart';


void main() {
  testWidgets('POS App smoke test', (WidgetTester tester) async {
    // 關閉實際排程避免長時間 Timer
    TimeService.disableSchedulingForTests = true;
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('POS'), findsWidgets);
  });
}
