import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/services/receipt_service.dart';
import 'package:cheemeow_pos/models/receipt.dart';
import 'package:cheemeow_pos/models/cart_item.dart';
import 'package:cheemeow_pos/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiptService.generateReceiptId', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ReceiptService.instance.initialize();
      await ReceiptService.instance.clearAllReceipts();
    });

    test('sequential ids per day across methods', () async {
      final now = DateTime(2025, 9, 10, 10, 0, 0);
      final id1 = await ReceiptService.instance.generateReceiptId('現金', now: now);
      expect(id1, '1-001');
      // 儲存第一筆收據
      final r1 = _receiptStub(id1, now);
      await ReceiptService.instance.saveReceipt(r1);

      final id2 = await ReceiptService.instance.generateReceiptId('轉帳', now: now.add(const Duration(minutes: 1)));
      expect(id2, '2-002');
      final r2 = _receiptStub(id2, now.add(const Duration(minutes: 1)));
      await ReceiptService.instance.saveReceipt(r2);

      final id3 = await ReceiptService.instance.generateReceiptId('LinePay', now: now.add(const Duration(minutes: 2)));
      expect(id3, '3-003');
    });

    test('reset sequence next day', () async {
      final day1 = DateTime(2025, 9, 10, 23, 50);
      final id1 = await ReceiptService.instance.generateReceiptId('現金', now: day1);
      expect(id1, '1-001');
      await ReceiptService.instance.saveReceipt(_receiptStub(id1, day1));

      final nextDay = DateTime(2025, 9, 11, 0, 5);
      final id2 = await ReceiptService.instance.generateReceiptId('現金', now: nextDay);
      // 新的一天重新從 001
      expect(id2, '1-001');
    });
  });
}

Receipt _receiptStub(String id, DateTime ts) {
  final prod = Product(
    id: 'p1',
    barcode: '0001',
    name: '測試商品',
    price: 100,
  );
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
