import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/services/sales_export_service.dart';
import 'package:cheemeow_pos/models/receipt.dart';
import 'package:cheemeow_pos/models/cart_item.dart';
import 'package:cheemeow_pos/models/product.dart';

void main() {
  test('buildCsvsForReceipts generates two CSVs with headers and rows', () {
    final normal = Product(id: '001', barcode: '000123', name: '普通商品', price: 100, category: '一般');
    final preorder = Product(id: 'sp1', barcode: '19920203', name: '🎁 預約奇妙', price: 0, category: '特殊商品');
    final discount = Product(id: 'sp2', barcode: '88888888', name: '💸 祝您有奇妙的一天', price: -50, category: '特殊商品');

    final r1 = Receipt(
      id: '1-001',
      timestamp: DateTime(2025, 9, 10, 12, 0, 0),
      items: [
        CartItem(product: normal, quantity: 2),
        CartItem(product: preorder, quantity: 1),
      ],
      totalAmount: 200, // 預購 0 不影響合計
      totalQuantity: 3,
      paymentMethod: '現金',
    );
    final r2 = Receipt(
      id: '2-002',
      timestamp: DateTime(2025, 9, 10, 13, 0, 0),
      items: [
        CartItem(product: discount, quantity: 1),
      ],
      totalAmount: -50,
      totalQuantity: 1,
      paymentMethod: '轉帳',
    );

    final bundle = SalesExportService.instance.buildCsvsForReceipts([r1, r2]);
    // headers
    expect(bundle.salesCsv.split('\n').first.contains('商品代碼'), isTrue);
    expect(bundle.specialCsv.split('\n').first.contains('收據單號'), isTrue);

    // rows count basic checks
    final salesRows = bundle.salesCsv.trim().split('\n');
    final specialRows = bundle.specialCsv.trim().split('\n');
    // sales: only normal product from r1 => header + 1 row
    expect(salesRows.length, 2);
    // special: preorder from r1 + discount from r2 => header + 2 rows
    expect(specialRows.length, 3);

    // leading zero preserved with prefix '
    expect(salesRows[1].contains("'000123"), isTrue);
  });

  test('skips refunded items', () {
    final normal = Product(id: '001', barcode: '000123', name: '普通商品', price: 100);
    final r = Receipt(
      id: '1-001',
      timestamp: DateTime(2025, 9, 10, 14, 0, 0),
      items: [CartItem(product: normal, quantity: 1)],
      totalAmount: 100,
      totalQuantity: 1,
      paymentMethod: '現金',
      refundedProductIds: const ['001'],
    );
    final bundle = SalesExportService.instance.buildCsvsForReceipts([r]);
    // only headers, no rows
    expect(bundle.salesCsv.trim().split('\n').length, 1);
    expect(bundle.specialCsv.trim().split('\n').length, 1);
  });
}
