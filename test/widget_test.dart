// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/main.dart';
import 'package:cheemeow_pos/services/time_service.dart';
import 'package:cheemeow_pos/widgets/primary_app_bar.dart';

void main() {
  testWidgets('POS App smoke test', (WidgetTester tester) async {
    // 關閉實際排程避免長時間 Timer
    TimeService.disableSchedulingForTests = true;
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 100));
    // 標題目前是圖片，改為確認主要 AppBar 是否存在
    expect(find.byType(PrimaryAppBar), findsOneWidget);
  });
}
