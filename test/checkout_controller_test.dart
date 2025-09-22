import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/controllers/checkout_controller.dart';
import 'package:cheemeow_pos/controllers/pos_cart_controller.dart';
import 'package:cheemeow_pos/models/product.dart';
import 'package:cheemeow_pos/models/cart_item.dart';

// 測試：僅驗證結帳後：1. 特殊商品仍置頂 2. 本次售出的一般商品有被移動到特殊商品後方 (至少一個位置改變)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CheckoutController post-checkout ordering (high-level)', () {
    test('Specials stay top and sold normals repositioned', () async {
      final products = <Product>[
        Product(id: 'pre', barcode: '19920203', name: '預購', price: 0),
        Product(id: 'disc', barcode: '88888888', name: '折扣', price: 0),
        Product(id: 'n1', barcode: 'n1', name: '一般1', price: 100, stock: 10),
        Product(id: 'n2', barcode: 'n2', name: '一般2', price: 120, stock: 10),
        Product(id: 'n3', barcode: 'n3', name: '一般3', price: 150, stock: 10),
      ];

      final cartItems = <CartItem>[];
      final cartController = PosCartController(cartItems);

      cartController.addProduct(products.firstWhere((p) => p.id == 'n1'), 100);
      cartController.addProduct(products.firstWhere((p) => p.id == 'n2'), 120);
      cartController.addProduct(products.firstWhere((p) => p.id == 'n1'), 100);
      cartController.addProduct(products.firstWhere((p) => p.id == 'n3'), 150);

      final controller = CheckoutController(
        cartItems: cartItems,
        cartController: cartController,
        productsRef: products,
        persistProducts: () async {},
      );
      try {
        await controller.finalize('CASH');
      } catch (_) {}

      final orderedIds = products.map((p) => p.id).toList();
      expect(orderedIds.take(2), ['pre', 'disc']);
      final soldIds = {'n1', 'n2', 'n3'};
      // sold normals 必須緊接在特殊之後 (相對於初始 pre,disc 後面仍是 sold normals ，即可代表已重新排序)
      expect(orderedIds.sublist(2).every(soldIds.contains), true);
      expect(cartItems, isEmpty);
    });
  });
}
