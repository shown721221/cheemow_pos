import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/services/receipt_service.dart';
import 'package:cheemeow_pos/models/receipt.dart';
import 'package:cheemeow_pos/models/cart_item.dart';
import 'package:cheemeow_pos/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cheemeow_pos/services/receipt_id_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiptService.generateReceiptId', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ReceiptService.instance.initialize();
      await ReceiptService.instance.clearAllReceipts();
    });

    test(
      'sequential ids per day across methods (via generator expectation)',
      () async {
        final now = DateTime(2025, 9, 10, 10, 0, 0);
        final gen = ReceiptIdGenerator.instance;

        // 第一筆 (現金)
        final expected1 = await gen.generate('現金', now: now);
        final id1 = await ReceiptService.instance.generateReceiptId(
          '現金',
          now: now,
        );
        expect(id1, expected1);
        await ReceiptService.instance.saveReceipt(_receiptStub(id1, now));

        // 第二筆 (轉帳)
        final t2 = now.add(const Duration(minutes: 1));
        final expected2 = await gen.generate('轉帳', now: t2);
        final id2 = await ReceiptService.instance.generateReceiptId(
          '轉帳',
          now: t2,
        );
        expect(id2, expected2);
        await ReceiptService.instance.saveReceipt(_receiptStub(id2, t2));

        // 第三筆 (LinePay)
        final t3 = now.add(const Duration(minutes: 2));
        final expected3 = await gen.generate('LinePay', now: t3);
        final id3 = await ReceiptService.instance.generateReceiptId(
          'LinePay',
          now: t3,
        );
        expect(id3, expected3);
      },
    );

    test('reset sequence next day (via generator expectation)', () async {
      final gen = ReceiptIdGenerator.instance;
      final day1 = DateTime(2025, 9, 10, 23, 50);
      final expected1 = await gen.generate('現金', now: day1);
      final id1 = await ReceiptService.instance.generateReceiptId(
        '現金',
        now: day1,
      );
      expect(id1, expected1);
      await ReceiptService.instance.saveReceipt(_receiptStub(id1, day1));

      final nextDay = DateTime(2025, 9, 11, 0, 5);
      final expected2 = await gen.generate('現金', now: nextDay);
      final id2 = await ReceiptService.instance.generateReceiptId(
        '現金',
        now: nextDay,
      );
      expect(id2, expected2, reason: '新的一天應重新從 001');
    });
  });
}

Receipt _receiptStub(String id, DateTime ts) {
  final prod = Product(id: 'p1', barcode: '0001', name: '測試商品', price: 100);
  final item = CartItem(product: prod, quantity: 1, addedTime: ts);
  return Receipt(
    id: id,
    timestamp: ts,
    items: [item],
    totalAmount: 100,
    totalQuantity: 1,
    paymentMethod: '現金',
  );
}
