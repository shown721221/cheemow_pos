import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/services/sales_export_service.dart';
import 'package:cheemeow_pos/models/receipt.dart';
import 'package:cheemeow_pos/models/cart_item.dart';
import 'package:cheemeow_pos/models/product.dart';

void main() {
  test('buildCsvsForReceipts generates two CSVs with headers and rows', () {
    final normal = Product(
      id: '001',
      barcode: '000123',
      name: '普通商品',
      price: 100,
      category: '一般',
    );
    final preorder = Product(
      id: 'sp1',
      barcode: '19920203',
      name: '🎁 預約奇妙',
      price: 0,
      category: '特殊商品',
    );
    final discount = Product(
      id: 'sp2',
      barcode: '88888888',
      name: '💸 祝您有奇妙的一天',
      price: -50,
      category: '特殊商品',
    );

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
      items: [CartItem(product: discount, quantity: 1)],
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

    // 商品代碼、條碼皆以 ="..." 文字形式（外層整欄被雙引號包住，內部雙引號成對）
    // 第一欄 商品代碼："=""001"""
    expect(salesRows[1].startsWith('"=""001"""'), isTrue);
    // 第三欄 條碼：,"=""000123"""
    expect(salesRows[1].contains(',"=""000123"""'), isTrue);

    // 付款方式代碼：現金=1 轉帳=2
    expect(
      bundle.salesCsv.contains(',1-001'),
      isTrue,
    ); // receipt id still present
    // 找到現金那行應包含 ,1, 付款方式代號欄位
    final cashLine = salesRows.firstWhere(
      (l) => l.contains('1-001'),
      orElse: () => '',
    );
    expect(cashLine.contains(',現金,'), isTrue);
    expect(cashLine.contains(',1,'), isTrue);

    // 特殊 CSV 僅含特殊商品名稱，且不含普通商品名稱
    expect(bundle.specialCsv.contains('普通商品'), isFalse);
    expect(bundle.specialCsv.contains('預約奇妙'), isTrue);
    expect(bundle.specialCsv.contains('祝您有奇妙的一天'), isTrue);
  });

  test('barcode exported as Excel-safe text for very long numbers', () {
    final p = Product(
      id: 'A1',
      barcode: '4011600135879000300123',
      name: '超長碼',
      price: 1,
    );
    final r = Receipt(
      id: '9-001',
      timestamp: DateTime(2025, 9, 10, 12, 0, 0),
      items: [CartItem(product: p, quantity: 1)],
      totalAmount: 1,
      totalQuantity: 1,
      paymentMethod: '現金',
    );
    final bundle = SalesExportService.instance.buildCsvsForReceipts([r]);
    final salesRows = bundle.salesCsv.trim().split('\n');
    expect(salesRows.length, 2);
    // 應包含 ="<條碼>"（CSV 內部雙引號轉義）
    expect(salesRows[1].contains(',"=""4011600135879000300123"""'), isTrue);
  });

  test('skips refunded items', () {
    final normal = Product(
      id: '001',
      barcode: '000123',
      name: '普通商品',
      price: 100,
    );
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
