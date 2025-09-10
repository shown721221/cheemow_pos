import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/models/product.dart';
import 'package:cheemeow_pos/services/barcode_scan_helper.dart';

void main() {
  group('BarcodeScanHelper.decideFromProducts', () {
    final products = [
      Product(id: 'A', barcode: '111', name: '普通A', price: 100, stock: 10),
      Product(id: 'B', barcode: '19920203', name: '🎁 預約奇妙', price: 0, category: '特殊商品', stock: 99),
      Product(id: 'C', barcode: '88888888', name: '💸 祝您有奇妙的一天', price: 0, category: '特殊商品', stock: 99),
    ];

    test('returns foundNormal when normal product exists', () {
      final d = BarcodeScanHelper.decideFromProducts('111', products);
      expect(d.result, ScanAddResult.foundNormal);
      expect(d.product?.id, 'A');
    });

    test('returns foundSpecialNeedsPrice for special or price=0', () {
      final d1 = BarcodeScanHelper.decideFromProducts('19920203', products);
      final d2 = BarcodeScanHelper.decideFromProducts('88888888', products);
      expect(d1.result, ScanAddResult.foundSpecialNeedsPrice);
      expect(d2.result, ScanAddResult.foundSpecialNeedsPrice);
    });

    test('returns notFound when product missing', () {
      final d = BarcodeScanHelper.decideFromProducts('999', products);
      expect(d.result, ScanAddResult.notFound);
    });
  });
}
