import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cheemeow_pos/services/pos_actions_service.dart';
import 'package:cheemeow_pos/services/receipt_service.dart';
import 'package:cheemeow_pos/models/receipt.dart';
import 'package:shared_preferences/shared_preferences.dart';

Receipt dummy(String id) => Receipt(
  id: id,
  timestamp: DateTime(2025, 9, 22, 10, 0),
  items: const [],
  totalAmount: 100,
  totalQuantity: 1,
  paymentMethod: '現金',
);

void main() {
  testWidgets('showReceiptStatistics 顯示對話框', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ReceiptService.instance.initialize();
    await ReceiptService.instance.saveReceipt(dummy('1-001'));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await PosActionsService.instance.showReceiptStatistics(
                      context,
                    );
                  },
                  child: const Text('STAT'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('STAT'));
    await tester.pumpAndSettle();

    // 驗證對話框內容包含 Total: 1
    expect(find.textContaining('Total: 1'), findsOneWidget);
  });
}
