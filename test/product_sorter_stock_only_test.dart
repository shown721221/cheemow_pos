import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/models/product.dart';

void main() {
  test('stock only ordering when bypassing daily sort logic', () {
    final products = [
      Product(id: 'a', barcode: 'a', name: 'A', price: 10, stock: 5),
      Product(id: 'b', barcode: 'b', name: 'B', price: 10, stock: 30),
      Product(id: 'c', barcode: 'c', name: 'C', price: 10, stock: 30),
      Product(id: 'd', barcode: 'd', name: 'D', price: 10, stock: 1),
    ];

    // 模擬 widget.applyDailySort = false && sortByStock = true 的排序行為
    final clone = [...products];
    clone.sort((a, b) {
      final diff = b.stock.compareTo(a.stock);
      if (diff != 0) return diff;
      return a.name.compareTo(b.name);
    });
    expect(clone.map((e) => e.id).toList(), ['b', 'c', 'a', 'd']);
  });
}
