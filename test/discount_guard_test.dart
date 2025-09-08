import 'package:flutter_test/flutter_test.dart';
import 'package:cheemow_pos/models/product.dart';
import 'package:cheemow_pos/controllers/pos_controller.dart';

void main() {
  group('Checkout discount guard', () {
    test('should block when discount exceeds non-discount total', () async {
      final controller = PosController();

      // Regular product: price 1000
      final regular = Product(
        id: 'p1',
        barcode: '12345678',
        name: 'Regular Item',
        price: 1000,
        category: '一般',
        stock: 10,
      );

      // Discount product: barcode matches discount and negative price
      final discount = Product(
        id: 'd1',
        barcode: '88888888', // discount product identifier
        name: 'Discount',
        price: 0,
        category: '特殊商品',
        stock: 99,
      );

      // Add one regular item (1000)
      controller.addProductToCart(regular, 1000);

      // Add discount exceeding total (e.g., -1100)
      controller.addProductToCart(discount, -1100);

      // Process checkout should be blocked (returns null)
      final receipt = await controller.processCheckout();
      expect(receipt, isNull);
    });
  });
}
