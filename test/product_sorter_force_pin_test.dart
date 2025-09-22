import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/utils/product_sorter.dart';
import 'package:cheemeow_pos/models/product.dart';

void main() {
  group('ProductSorter.sortDaily forcePinSpecial', () {
    final now = DateTime(2025, 9, 10, 12, 0, 0);
    Product p({
      required String id,
      required String barcode,
      required String name,
      int price = 10,
      DateTime? last,
    }) => Product(
      id: id,
      barcode: barcode,
      name: name,
      price: price,
      lastCheckoutTime: last,
    );

    test(
      'Unsold specials pinned before today-sold normals when forcePinSpecial',
      () {
        final todayEarly = DateTime(2025, 9, 10, 9, 0, 0);
        final soldA = p(id: 'A', barcode: 'a', name: 'A', last: todayEarly);
        final soldB = p(id: 'B', barcode: 'b', name: 'B', last: now);
        final preOrderUnsold = p(id: 'PRE', barcode: '19920203', name: '預購');
        final discountUnsold = p(id: 'DISC', barcode: '88888888', name: '折扣');

        final result = ProductSorter.sortDaily(
          [soldA, discountUnsold, soldB, preOrderUnsold],
          now: now,
          forcePinSpecial: true,
        );

        final ids = result.map((e) => e.id).toList();
        expect(ids.take(2), ['PRE', 'DISC']);
      },
    );

    test('Preorder unsold stays ahead of discount that was sold today', () {
      final discountSold = p(
        id: 'DISC',
        barcode: '88888888',
        name: '折扣',
        last: DateTime(2025, 9, 10, 11, 0, 0),
      );
      final preOrderUnsold = p(id: 'PRE', barcode: '19920203', name: '預購');
      final normalSold = p(id: 'N', barcode: 'n', name: 'Normal', last: now);

      final result = ProductSorter.sortDaily(
        [normalSold, discountSold, preOrderUnsold],
        now: now,
        forcePinSpecial: true,
      );

      final ids = result.map((e) => e.id).toList();
      expect(ids.first, 'PRE');
      expect(ids[1], 'DISC');
    });

    test(
      'Control: forcePinSpecial=false keeps recency first (today sold discount ahead of unsold preorder)',
      () {
        final discountSold = p(
          id: 'DISC',
          barcode: '88888888',
          name: '折扣',
          last: DateTime(2025, 9, 10, 11, 0, 0),
        );
        final preOrderUnsold = p(id: 'PRE', barcode: '19920203', name: '預購');

        final result = ProductSorter.sortDaily(
          [discountSold, preOrderUnsold],
          now: now,
          forcePinSpecial: false,
        );

        final ids = result.map((e) => e.id).toList();
        // recencyDominatesSpecial 預設 true，discountSold(今日售出) 應在 unsold preorder 前
        expect(ids.first, 'DISC');
      },
    );
  });
}
