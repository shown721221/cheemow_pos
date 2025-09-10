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

      final result = ProductSorter.sortDaily([
        otherX,
        todaySoldA,
        discount,
        preOrder,
        otherC,
        todaySoldB,
      ], now: now);

  final orderedIds = result.map((p) => p.id).toList();
  expect(orderedIds, ['pre', 'disc', 'b', 'a', 'c', 'x']);
    });
  });
}
