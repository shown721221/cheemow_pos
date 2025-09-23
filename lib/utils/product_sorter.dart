import '../models/product.dart';
import '../services/time_service.dart';

/// 與商品排序相關的純函式工具。
class ProductSorter {
  /// 排序模式
  /// daily: 既有規則
  /// dailyStock: 在既有規則大類順序（今日售出→未售出特殊→其它 或 強制特殊置頂後）中，對每一群再依庫存數量由高到低，最後以名稱當 tie-breaker。
  static const _nameComparator = _NameComparator();

  static List<Product> sort(
    List<Product> list, {
    DateTime? now,
    bool recencyDominatesSpecial = true,
    bool forcePinSpecial = false,
    bool byStock = false,
  }) {
    if (!byStock) {
      return sortDaily(
        list,
        now: now,
        recencyDominatesSpecial: recencyDominatesSpecial,
        forcePinSpecial: forcePinSpecial,
      );
    }
    // 需求（修正）：特殊商品永遠最上方（預購 > 折扣），其後「今日售出的一般商品」（依最新時間），最後其他一般商品按庫存高→低再名稱。
    final current = now ?? TimeService.now();
    bool isToday(DateTime? dt) =>
        dt != null &&
        dt.year == current.year &&
        dt.month == current.month &&
        dt.day == current.day;

    final preOrders = <Product>[]; // 置頂第一段
    final discounts = <Product>[]; // 置頂第二段
    final todayNormal = <Product>[]; // 今日售出(非特殊)
    final others = <Product>[]; // 其它一般商品

    for (final p in list) {
      if (p.isPreOrderProduct) {
        preOrders.add(p);
        continue;
      }
      if (p.isDiscountProduct) {
        discounts.add(p);
        continue;
      }
      if (isToday(p.lastCheckoutTime)) {
        todayNormal.add(p);
      } else {
        others.add(p);
      }
    }

    // 特殊區塊：維持原本名稱排序（或可依庫存，但需求為固定置頂不動，可保持名稱穩定）
    preOrders.sort(_nameComparator.call);
    discounts.sort(_nameComparator.call);

    // 今日售出一般：時間新->舊
    todayNormal.sort(
      (a, b) => b.lastCheckoutTime!.compareTo(a.lastCheckoutTime!),
    );

    // 其它一般：庫存高->低 再名稱
    others.sort((a, b) {
      final diff = b.stock.compareTo(a.stock);
      if (diff != 0) return diff;
      return _nameComparator.call(a, b);
    });

    return [...preOrders, ...discounts, ...todayNormal, ...others];
  }

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

class _NameComparator {
  const _NameComparator();
  int call(Product a, Product b) => a.name.compareTo(b.name);
}
