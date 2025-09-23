import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/utils/product_sorter.dart';
import 'package:cheemeow_pos/models/product.dart';
import 'package:cheemeow_pos/config/constants.dart';

void main() {
  test(
    'byStock keeps specials (pre>discount) pinned before today normals then others',
    () {
      final now = DateTime(2025, 9, 23, 15, 0, 0);

      Product mk(
        String id,
        int stock, {
        bool pre = false,
        bool discount = false,
        bool today = false,
      }) {
        final barcode = pre
            ? AppConstants.barcodePreOrder
            : discount
            ? AppConstants.barcodeDiscount
            : 'N$id';
        return Product(
          id: id,
          barcode: barcode,
          name: 'P$id',
          price: 10,
          stock: stock,
          lastCheckoutTime: today
              ? now.subtract(Duration(minutes: int.parse(id)))
              : null,
        );
      }

      final list = [
        mk('1', 5, pre: true, today: true), // 特殊 + 今日 (仍應在頂部特殊區)
        mk('2', 12, discount: true),
        mk('3', 30, today: true), // 今日一般
        mk('4', 25, today: true), // 今日一般 (較早售出)
        mk('5', 40), // 其它一般高庫存
        mk('6', 18), // 其它一般
      ];

      final sorted = ProductSorter.sort(list, now: now, byStock: true);
      final ids = sorted.map((e) => e.id).toList();

      // 預期：特殊 (預購1 > 折扣2) -> 今日一般 (3 新於 4) -> 其它一般 庫存排序 5(40) 6(18)
      expect(ids, ['1', '2', '3', '4', '5', '6']);
    },
  );
}
