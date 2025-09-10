import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/utils/product_sorter.dart';
import 'package:cheemeow_pos/models/product.dart';

void main() {
  group('ProductSorter.sortDaily edge cases', () {
    test('today items ordered by lastCheckoutTime desc', () {
      final now = DateTime(2025, 9, 10, 12, 0, 0);
      final p1 = Product(id: '1', barcode: 'b1', name: 'A', price: 10, lastCheckoutTime: now.subtract(const Duration(minutes: 5)));
      final p2 = Product(id: '2', barcode: 'b2', name: 'B', price: 10, lastCheckoutTime: now.subtract(const Duration(minutes: 1)));
      final p3 = Product(id: '3', barcode: 'b3', name: 'C', price: 10); // 未售出
      final sorted = ProductSorter.sortDaily([p3, p1, p2], now: now);
  // 期待順序: p2 (較新) 在 p1 前面，其後才是 p3
      expect(sorted[0].id, '2');
      expect(sorted[1].id, '1');
      expect(sorted[2].id, '3');
    });

    test('special products first (preorder > discount)', () {
      final now = DateTime(2025, 9, 10);
      final preorder = Product(id: 'p_po', barcode: '19920203', name: '預購', price: 0);
      final discount = Product(id: 'p_dc', barcode: '88888888', name: '折扣', price: -100);
      final normal = Product(id: 'p_n', barcode: 'n', name: '普通', price: 50);
      final sorted = ProductSorter.sortDaily([normal, discount, preorder], now: now);
      expect(sorted[0].id, 'p_po');
      expect(sorted[1].id, 'p_dc');
    });
  });
}
