import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cheemow_pos/models/product.dart';
import 'package:cheemow_pos/models/cart_item.dart';
import 'package:cheemow_pos/services/product_update_service.dart';
import 'package:cheemow_pos/services/time_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('compute updates stock for normal products and keeps special stock', () {
    final now = DateTime(2025, 9, 10, 12, 0, 0);
    TimeService.nowOverride = () => now;

    final products = [
      Product(id: 'A', barcode: '111', name: '普通A', price: 100, stock: 10),
      Product(id: 'B', barcode: '19920203', name: '🎁 預約奇妙', price: 0, category: '特殊商品', stock: 99),
      Product(id: 'C', barcode: '88888888', name: '💸 祝您有奇妙的一天', price: 0, category: '特殊商品', stock: 99),
    ];

    final cart = [
      CartItem(product: products[0], quantity: 2), // 普通扣2
      CartItem(product: products[1], quantity: 5), // 預約不扣
      CartItem(product: products[2], quantity: 3), // 折扣不扣
    ];

    final outcome = ProductUpdateService.instance.compute(products, cart, now: now);

    // updated count 應該只算有在購物車的不同條碼數量（這裡3筆）
    expect(outcome.updatedCount, 3);

    // stock
    final updatedA = outcome.updatedProducts.firstWhere((p) => p.id == 'A');
    final updatedB = outcome.updatedProducts.firstWhere((p) => p.id == 'B');
    final updatedC = outcome.updatedProducts.firstWhere((p) => p.id == 'C');

    expect(updatedA.stock, 8); // 10-2
    expect(updatedB.stock, 99); // 特殊不扣
    expect(updatedC.stock, 99); // 特殊不扣

    // lastCheckoutTime 都應該設為 now
    expect(updatedA.lastCheckoutTime, now);
    expect(updatedB.lastCheckoutTime, now);
    expect(updatedC.lastCheckoutTime, now);

    // resortedProducts 應依每日排序（此處只檢查長度與包含）
    expect(outcome.resortedProducts.length, products.length);
  });
}
