import '../models/receipt.dart';
import '../config/constants.dart';

class SalesCsvBundle {
  final String salesCsv;
  final String specialCsv;
  const SalesCsvBundle({required this.salesCsv, required this.specialCsv});
}

class SalesExportService {
  SalesExportService._();
  static final SalesExportService instance = SalesExportService._();

  /// 由收據列表產生兩份 CSV（一般銷售/特殊商品）。
  /// - 排除退貨項目（以 receipt.refundedProductIds 內的 product.id 判定）
  /// - 一般銷售不含特殊商品；特殊商品專表只含特殊商品
  SalesCsvBundle buildCsvsForReceipts(List<Receipt> receipts) {
    // 準備銷售 CSV（排除特殊商品：預購 / 折扣 / 特殊商品類別）
    final salesBuffer = StringBuffer();
    salesBuffer.writeln([
      '商品代碼',
      '商品名稱',
      '條碼',
      '售出數量',
      '收據單號',
      '日期時間',
      '付款方式',
      '付款方式代號',
      '單價',
      '總價',
      '類別',
    ].join(','));

    // 準備特殊商品 CSV（僅預購/折扣或標記為特殊商品）
    final specialBuffer = StringBuffer();
    specialBuffer.writeln([
      '收據單號',
      '日期時間',
      '付款方式',
      '付款方式代號',
      '商品名稱',
      '銷售數量',
      '單價',
      '總價',
    ].join(','));

  String methodCode(String method) {
      switch (method) {
    case PaymentMethods.cash:
          return '1';
        case '轉帳':
          return '2';
        case 'LinePay':
          return '3';
        default:
          return '9';
      }
    }

    String formatDateTime(DateTime ts) {
      return '${ts.year.toString().padLeft(4, '0')}/'
          '${ts.month.toString().padLeft(2, '0')}/'
          '${ts.day.toString().padLeft(2, '0')} '
          '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
    }

    String esc(String v) {
      if (v.contains(',') || v.contains('"') || v.contains('\n')) {
        final escaped = v.replaceAll('"', '""');
        return '"$escaped"';
      }
      return v;
    }

    String preserveLeadingZeros(String v) {
      if (RegExp(r'^0\d+$').hasMatch(v)) {
        return "'$v";
      }
      return v;
    }

    for (final r in receipts) {
      final refunded = r.refundedProductIds.toSet();
      for (final it in r.items) {
        final p = it.product;
        if (refunded.contains(p.id)) continue; // 排除已退貨項目
        final qty = it.quantity;
        final unitPrice = p.price; // 折扣品可能為負
        final lineTotal = unitPrice * qty;
        final ts = r.timestamp;
        final dateTimeStr = formatDateTime(ts);

        if (!p.isSpecialProduct) {
          salesBuffer.writeln([
            esc(preserveLeadingZeros(p.id)),
            esc(p.name),
            esc(preserveLeadingZeros(p.barcode)),
            qty.toString(),
            esc(r.id),
            esc(dateTimeStr),
            esc(r.paymentMethod),
            methodCode(r.paymentMethod),
            unitPrice.toString(),
            lineTotal.toString(),
            esc(p.category.isEmpty ? '未分類' : p.category),
          ].join(','));
        }

        if (p.isSpecialProduct) {
          specialBuffer.writeln([
            esc(r.id),
            esc(dateTimeStr),
            esc(r.paymentMethod),
            methodCode(r.paymentMethod),
            esc(p.name),
            qty.toString(),
            unitPrice.toString(),
            lineTotal.toString(),
          ].join(','));
        }
      }
    }

    return SalesCsvBundle(
      salesCsv: salesBuffer.toString(),
      specialCsv: specialBuffer.toString(),
    );
  }
}
