import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cheemow_pos/utils/capture_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CaptureUtil.captureWidget returns non-empty png bytes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));

    final future = CaptureUtil.captureWidget(
      context: tester.element(find.byType(SizedBox)),
      builder: (k) => RepaintBoundary(
        key: k,
        child: const SizedBox(
          width: 100,
          height: 40,
          child: ColoredBox(color: Colors.red),
        ),
      ),
      pixelRatio: 1.0,
    );

    // 推進時間與 frame，滿足內部 Future.delayed 與 endOfFrame 等待
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    final bytes = await future;

    expect(bytes.length, greaterThan(100));
    expect(bytes[0], 0x89); // PNG signature
    expect(String.fromCharCodes(bytes.sublist(1, 4)), 'PNG');
  }, timeout: const Timeout(Duration(seconds: 5)), skip: true,);
}
