import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/utils/product_sorter.dart';
import 'package:cheemeow_pos/models/product.dart';

void main() {
  group('ProductSorter.sortDaily', () {
    test('排序規則：特殊(預購>折扣) → 今日售出 → 其它名稱', () {
      final now = DateTime(2025, 9, 10, 12, 0, 0);
      final yesterday = DateTime(2025, 9, 9, 10, 0, 0);

      final preOrder = Product(
        id: 'pre',
        barcode: '19920203',
        name: '預購',
        price: 0,
        lastCheckoutTime: yesterday,
      );
      final discount = Product(
        id: 'disc',
        barcode: '88888888',
        name: '折扣',
        price: 0,
        lastCheckoutTime: now,
      );
      final todaySoldA = Product(
        id: 'a',
        barcode: 'a',
        name: 'A商品',
        price: 100,
        lastCheckoutTime: DateTime(2025, 9, 10, 9, 0, 0),
      );
      final todaySoldB = Product(
        id: 'b',
        barcode: 'b',
        name: 'B商品',
        price: 100,
        lastCheckoutTime: DateTime(2025, 9, 10, 11, 0, 0),
      );
      final otherX = Product(
        id: 'x',
        barcode: 'x',
        name: 'X商品',
        price: 50,
        lastCheckoutTime: yesterday,
      );
      final otherC = Product(
        id: 'c',
        barcode: 'c',
        name: 'C商品',
        price: 50,
        lastCheckoutTime: yesterday,
      );

      final result = ProductSorter.sortDaily(
        [otherX, todaySoldA, discount, preOrder, otherC, todaySoldB],
        now: now,
        recencyDominatesSpecial: false,
      );

      final orderedIds = result.map((p) => p.id).toList();
      expect(orderedIds, ['pre', 'disc', 'b', 'a', 'c', 'x']);
    });

    test('新版排序：今日售出（含特殊）統一置頂依時間新→舊', () {
      final now = DateTime(2025, 9, 10, 12, 0, 0);
      final earlier = DateTime(2025, 9, 10, 9, 0, 0);
      final preOrderToday = Product(
        id: 'preT',
        barcode: '19920203',
        name: '預購',
        price: 0,
        lastCheckoutTime: DateTime(2025, 9, 10, 11, 30, 0),
      );
      final discountToday = Product(
        id: 'discT',
        barcode: '88888888',
        name: '折扣',
        price: 0,
        lastCheckoutTime: DateTime(2025, 9, 10, 11, 0, 0),
      );
      final normalNew = Product(
        id: 'nNew',
        barcode: 'nNew',
        name: 'N商品',
        price: 100,
        lastCheckoutTime: now,
      );
      final normalEarlier = Product(
        id: 'nOld',
        barcode: 'nOld',
        name: 'M商品',
        price: 80,
        lastCheckoutTime: earlier,
      );
      final unsoldPre = Product(
        id: 'preOld',
        barcode: '19920203',
        name: '預購舊',
        price: 0,
        lastCheckoutTime: DateTime(2025, 9, 9, 10, 0, 0),
      );
      final unsoldNormal = Product(
        id: 'uNorm',
        barcode: 'u',
        name: 'Z一般',
        price: 50,
        lastCheckoutTime: DateTime(2025, 9, 8, 10, 0, 0),
      );

      final result = ProductSorter.sortDaily(
        [
          unsoldNormal,
          normalEarlier,
          discountToday,
          preOrderToday,
          unsoldPre,
          normalNew,
        ],
        now: now,
        recencyDominatesSpecial: true,
      );

      final ordered = result.map((p) => p.id).toList();
      // 今日售出按時間新→舊: normalNew(now) > preOrderToday(11:30) > discountToday(11:00) > normalEarlier(9:00)
      // 然後未售出特殊 preOld，再未售出普通 uNorm
      expect(ordered, ['nNew', 'preT', 'discT', 'nOld', 'preOld', 'uNorm']);
    });
  });
}
