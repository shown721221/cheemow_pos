import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/utils/post_checkout_reorder.dart';
import 'package:cheemeow_pos/models/product.dart';
import 'package:cheemeow_pos/models/cart_item.dart';
import 'package:cheemeow_pos/config/constants.dart';

// 建立測試用商品 (最小必要欄位)
Product buildProduct(String id, {bool pre = false, bool discount = false}) =>
    Product(
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
  group('post checkout reorder', () {
    test('預購與折扣永遠置頂，其次為本次售出的非特殊', () {
      final a = buildProduct('a');
      final b = buildProduct('b');
      final c1 = buildProduct('c');
      final pre = buildProduct('pre', pre: true);
      final dis = buildProduct('dis', discount: true);
      final products = [a, pre, b, dis, c1];
      final cart = [ci(a), ci(b), ci(a), ci(c1)]; // a 出現兩次 -> 保留唯一
      final reordered = reorderAfterCheckout(
        currentProducts: products,
        soldCartSnapshot: cart,
      );
      // 預期: pre, dis, (逆序唯一: c, b, a)
      expect(reordered.map((e) => e.id).toList(), [
        'pre',
        'dis',
        'c',
        'b',
        'a',
      ]);
    });

    test('無售出維持原引用 (避免不必要 rebuild)', () {
      final a = buildProduct('a');
      final pre = buildProduct('pre', pre: true);
      final list = [a, pre];
      final reordered = reorderAfterCheckout(
        currentProducts: list,
        soldCartSnapshot: [],
      );
      expect(identical(reordered, list), true);
    });

    test('售出的都是特殊商品 -> 非特殊仍留後面', () {
      final pre = buildProduct('pre', pre: true);
      final dis = buildProduct('dis', discount: true);
      final a = buildProduct('a');
      final products = [a, pre, dis];
      final cart = [ci(pre), ci(dis)];
      final reordered = reorderAfterCheckout(
        currentProducts: products,
        soldCartSnapshot: cart,
      );
      expect(reordered.map((e) => e.id).toList(), ['pre', 'dis', 'a']);
    });
  });
}
