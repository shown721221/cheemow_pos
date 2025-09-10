import 'receipt_service.dart';
import '../config/constants.dart';

class RevenueSummary {
  final int total;
  final int preorder;
  final int discount;
  final int cash;
  final int transfer;
  final int linepay;
  final int receiptCount;
  const RevenueSummary({
    required this.total,
    required this.preorder,
    required this.discount,
    required this.cash,
    required this.transfer,
    required this.linepay,
    required this.receiptCount,
  });
}

class PopularityStats {
  final Map<String, int> categoryCount; // 類別→數量
  final int preorderQty;
  final int discountQty;
  final int normalQty;
  final int totalQty; // normal+preorder+discount
  final int receiptCount;
  const PopularityStats({
    required this.categoryCount,
    required this.preorderQty,
    required this.discountQty,
    required this.normalQty,
    required this.totalQty,
    required this.receiptCount,
  });
}

/// 提供報表相關的純邏輯彙總，便於測試與重用
class ReportService {
  ReportService._();

  /// 彙總今日營收（排除退貨項目）
  static Future<RevenueSummary> computeTodayRevenueSummary({DateTime? now}) async {
    // ReceiptService.getTodayReceipts 內已以 TimeService.now 計算區間
    final receipts = await ReceiptService.instance.getTodayReceipts();
    int total = 0;
    int preorder = 0;
    int discount = 0;
    int cash = 0;
    int transfer = 0;
    int linepay = 0;

    for (final r in receipts) {
      total += r.totalAmount; // 已排除退貨
      switch (r.paymentMethod) {
        case PaymentMethods.cash:
          cash += r.totalAmount;
          break;
        case '轉帳':
          transfer += r.totalAmount;
          break;
        case 'LinePay':
          linepay += r.totalAmount;
          break;
      }
      final refunded = r.refundedProductIds.toSet();
      for (final it in r.items) {
        if (refunded.contains(it.product.id)) continue;
        if (it.product.isPreOrderProduct) {
          preorder += it.subtotal;
        } else if (it.product.isDiscountProduct) {
          discount += it.subtotal;
        }
      }
    }

    return RevenueSummary(
      total: total,
      preorder: preorder,
      discount: discount,
      cash: cash,
      transfer: transfer,
      linepay: linepay,
      receiptCount: receipts.length,
    );
  }

  /// 彙總今日的人氣統計（依商品類別分類，並計算預購/折扣/一般數量）
  static Future<PopularityStats> computeTodayPopularityStats() async {
    final receipts = await ReceiptService.instance.getTodayReceipts();
    final Map<String, int> categoryCount = {};
    int preorderQty = 0, discountQty = 0, normalQty = 0;
    for (final r in receipts) {
      final refunded = r.refundedProductIds.toSet();
      for (final it in r.items) {
        if (refunded.contains(it.product.id)) continue;
        final p = it.product;
        if (p.isPreOrderProduct) {
          preorderQty += it.quantity;
        } else if (p.isDiscountProduct) {
          discountQty += it.quantity;
        } else {
          normalQty += it.quantity;
        }
        final cat = p.category.isEmpty ? '未分類' : p.category;
        categoryCount.update(cat, (v) => v + it.quantity, ifAbsent: () => it.quantity);
      }
    }
    final totalAll = normalQty + preorderQty + discountQty;
    return PopularityStats(
      categoryCount: categoryCount,
      preorderQty: preorderQty,
      discountQty: discountQty,
      normalQty: normalQty,
      totalQty: totalAll,
      receiptCount: receipts.length,
    );
  }
}
