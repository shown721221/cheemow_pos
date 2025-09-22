import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/utils/post_checkout_reorder.dart';
import 'package:cheemeow_pos/utils/product_special_strategy.dart';
import 'package:cheemeow_pos/models/product.dart';
import 'package:cheemeow_pos/models/cart_item.dart';
import 'package:cheemeow_pos/config/constants.dart';

Product bp(String id, {bool pre = false, bool discount = false}) => Product(
  id: id,
  barcode: pre
      ? AppConstants.barcodePreOrder
      : discount
      ? AppConstants.barcodeDiscount
      : 'code_$id',
  name: id,
  price: 100,
);
CartItem ci(Product p) => CartItem(product: p, quantity: 1);

void main() {
  test('自訂策略：折扣優先於預購', () {
    final pre = bp('pre', pre: true);
    final disc = bp('disc', discount: true);
    final a = bp('a');
    final list = [pre, disc, a];
    final cart = [ci(a)];
    final reordered = reorderAfterCheckout(
      currentProducts: list,
      soldCartSnapshot: cart,
      strategy: const DiscountThenPreOrderStrategy(),
    );
    // 折扣在前，接著預購，再來售出一般 a
    expect(reordered.map((e) => e.id).toList(), ['disc', 'pre', 'a']);
  });
}
