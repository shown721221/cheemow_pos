import '../models/product.dart';
import '../services/time_service.dart';

/// 與商品排序相關的純函式工具。
class ProductSorter {
  /// 排序：
  /// recencyDominatesSpecial=false (舊)：特殊(預購>折扣)→今日售出(新→舊)→其它(名稱)
  /// recencyDominatesSpecial=true  (新)：今日售出(含特殊)新→舊→未售出特殊→其它
  static List<Product> sortDaily(
    List<Product> list, {
    DateTime? now,
    bool recencyDominatesSpecial = true,
    bool forcePinSpecial = false,
  }) {
    final current = now ?? TimeService.now();
    bool isToday(DateTime? dt) =>
        dt != null &&
        dt.year == current.year &&
        dt.month == current.month &&
        dt.day == current.day;

    if (!recencyDominatesSpecial) {
      final legacy = [...list];
      legacy.sort((a, b) {
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
      return legacy;
    }

    final todaySold = <Product>[];
    final unsoldSpecial = <Product>[];
    final unsoldOthers = <Product>[];

    for (final p in list) {
      if (isToday(p.lastCheckoutTime)) {
        todaySold.add(p);
      } else if (p.isSpecialProduct) {
        unsoldSpecial.add(p);
      } else {
        unsoldOthers.add(p);
      }
    }

    todaySold.sort(
      (a, b) => b.lastCheckoutTime!.compareTo(a.lastCheckoutTime!),
    );

    unsoldSpecial.sort((a, b) {
      if (a.isPreOrderProduct && !b.isPreOrderProduct) return -1;
      if (b.isPreOrderProduct && !a.isPreOrderProduct) return 1;
      if (a.isDiscountProduct && !b.isDiscountProduct) return -1;
      if (b.isDiscountProduct && !a.isDiscountProduct) return 1;
      return a.name.compareTo(b.name);
    });

    unsoldOthers.sort((a, b) => a.name.compareTo(b.name));

    final base = [...todaySold, ...unsoldSpecial, ...unsoldOthers];

    if (!forcePinSpecial) return base;

    // 強制將所有特殊商品（預購優先於折扣）置頂，不論是否今日售出
    final preOrders = <Product>[];
    final discounts = <Product>[];
    final others = <Product>[];
    for (final p in base) {
      if (p.isPreOrderProduct) {
        preOrders.add(p);
      } else if (p.isDiscountProduct) {
        discounts.add(p);
      } else {
        others.add(p);
      }
    }
    return [...preOrders, ...discounts, ...others];
  }
}
