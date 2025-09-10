import '../models/product.dart';
import '../services/time_service.dart';

/// 與商品排序相關的純函式工具。
class ProductSorter {
  /// 依每日規則排序：
  /// 1. 特殊商品（預購優先於折扣）
  /// 2. 今日售出的普通商品（依最後結帳時間新→舊）
  /// 3. 其餘商品（名稱字典序）
  static List<Product> sortDaily(List<Product> list, {DateTime? now}) {
    final current = now ?? TimeService.now();
    bool isToday(DateTime? dt) => dt != null && dt.year == current.year && dt.month == current.month && dt.day == current.day;

    final sorted = [...list];
    sorted.sort((a, b) {
      final aSpecial = a.isSpecialProduct;
      final bSpecial = b.isSpecialProduct;
      if (aSpecial && !bSpecial) return -1;
      if (bSpecial && !aSpecial) return 1;
      if (aSpecial && bSpecial) {
        if (a.isPreOrderProduct && b.isDiscountProduct) return -1;
        if (a.isDiscountProduct && b.isPreOrderProduct) return 1;
        return a.name.compareTo(b.name);
      }
      final aToday = isToday(a.lastCheckoutTime);
      final bToday = isToday(b.lastCheckoutTime);
      if (aToday && !bToday) return -1;
      if (bToday && !aToday) return 1;
      if (aToday && bToday) {
        return b.lastCheckoutTime!.compareTo(a.lastCheckoutTime!);
      }
      return a.name.compareTo(b.name);
    });
    return sorted;
  }
}
