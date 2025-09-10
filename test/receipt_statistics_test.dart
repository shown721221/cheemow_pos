import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cheemow_pos/services/receipt_service.dart';
import 'package:cheemow_pos/services/time_service.dart';
import 'package:cheemow_pos/models/receipt.dart';
import 'package:cheemow_pos/models/cart_item.dart';
import 'package:cheemow_pos/models/product.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ReceiptService.instance.initialize();
    await ReceiptService.instance.clearAllReceipts();
    TimeService.disableSchedulingForTests = true;
  });

  tearDown(() {
    TimeService.nowOverride = null;
    TimeService.disableSchedulingForTests = false;
  });

  test('statistics empty when no receipts', () async {
    TimeService.nowOverride = () => DateTime(2025, 9, 10, 12, 0, 0);
    final stats = await ReceiptService.instance.getReceiptStatistics();
    expect(stats['totalReceipts'], 0);
    expect(stats['todayReceipts'], 0);
    expect(stats['monthReceipts'], 0);
    expect(stats['totalRevenue'], 0);
    expect(stats['todayRevenue'], 0);
    expect(stats['monthRevenue'], 0);
  });

  test('statistics across days and months', () async {
    // Freeze time at 2025-09-10 noon
    final now = DateTime(2025, 9, 10, 12, 0, 0);
    TimeService.nowOverride = () => now;

    // Helper to create and save a receipt at timestamp ts with amount amt
    Future<void> addReceipt(DateTime ts, int amt, {String id = ''}) async {
      final prod = Product(id: 'p', barcode: 'b', name: 'x', price: amt);
      final item = CartItem(product: prod, quantity: 1, addedTime: ts);
      final r = Receipt(
        id: id.isEmpty ? 'id-${ts.microsecondsSinceEpoch}' : id,
        timestamp: ts,
        items: [item],
        totalAmount: amt,
        totalQuantity: 1,
        paymentMethod: '現金',
      );
      await ReceiptService.instance.saveReceipt(r);
    }

    // Today two receipts
    await addReceipt(DateTime(2025, 9, 10, 9, 0, 0), 100, id: '1-001');
    await addReceipt(DateTime(2025, 9, 10, 10, 0, 0), 200, id: '1-002');

    // Earlier this month
    await addReceipt(DateTime(2025, 9, 5, 18, 0, 0), 50, id: '1-003');

    // Last month - should not be counted in month
    await addReceipt(DateTime(2025, 8, 31, 23, 50, 0), 300, id: '1-999');

    final stats = await ReceiptService.instance.getReceiptStatistics();

    expect(stats['totalReceipts'], 4);
    expect(stats['todayReceipts'], 2);
    expect(stats['monthReceipts'], 3);
    expect(stats['totalRevenue'], 650);
    expect(stats['todayRevenue'], 300);
    expect(stats['monthRevenue'], 350);
  });
}
