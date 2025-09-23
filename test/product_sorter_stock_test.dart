import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/utils/product_sorter.dart';
import 'package:cheemeow_pos/models/product.dart';
import 'package:cheemeow_pos/config/constants.dart';

void main() {
  group('ProductSorter.sort byStock', () {
    DateTime base = DateTime(2025, 9, 23, 10, 0, 0);

    Product p({
      required String id,
      int stock = 0,
      bool today = false,
      bool pre = false,
      bool discount = false,
    }) {
      String barcode;
      if (pre) {
        barcode = AppConstants.barcodePreOrder;
      } else if (discount) {
        barcode = AppConstants.barcodeDiscount;
      } else {
        barcode = 'N$id';
      }
      return Product(
        id: id,
        barcode: barcode,
        name: 'P$id',
        price: 10,
        stock: stock,
        lastCheckoutTime: today
            ? base.subtract(Duration(minutes: int.parse(id)))
            : null,
      );
    }

    test(
      'special pinned (pre>discount), then today normal (recency), then others by stock',
      () {
        final list = [
          p(id: '1', stock: 5, today: true),
          p(id: '2', stock: 30, today: true),
          p(id: '3', stock: 10, pre: true),
          p(id: '4', stock: 40),
          p(id: '5', stock: 25, discount: true),
          p(id: '6', stock: 18),
        ];

        final sorted = ProductSorter.sort(list, now: base, byStock: true);
        // Extract ids
        final ids = sorted.map((e) => e.id).toList();
        // 預期：preOrder(p3) -> discount(p5) -> 今日售出一般(依時間新->舊: p1 比 p2 晚) -> 其它一般依庫存: p4(40) p6(18)
        expect(ids, ['3', '5', '1', '2', '4', '6']);
      },
    );
  });
}
