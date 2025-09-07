import '../models/product.dart';

/// 商品排序工具
class ProductSortUtils {
  
  /// 對商品進行排序：特殊商品在最前面，然後按結帳時間排序
  static List<Product> sortProducts(List<Product> products) {
    final sortedProducts = [...products];
    sortedProducts.sort((a, b) {
      // 預約商品排第一
      if (a.isPreOrderProduct && !b.isPreOrderProduct) return -1;
      if (!a.isPreOrderProduct && b.isPreOrderProduct) return 1;

      // 折扣商品排第二
      if (a.isDiscountProduct && !b.isDiscountProduct) return -1;
      if (!a.isDiscountProduct && b.isDiscountProduct) return 1;

      // 兩個都是特殊商品時，預約商品優先
      if (a.isSpecialProduct && b.isSpecialProduct) {
        if (a.isPreOrderProduct && b.isDiscountProduct) return -1;
        if (a.isDiscountProduct && b.isPreOrderProduct) return 1;
        return 0;
      }

      // 兩個都是普通商品時，按最後結帳時間排序
      if (a.lastCheckoutTime != null && b.lastCheckoutTime != null) {
        return b.lastCheckoutTime!.compareTo(a.lastCheckoutTime!);
      } else if (a.lastCheckoutTime != null) {
        return -1; // 有結帳記錄的在前
      } else if (b.lastCheckoutTime != null) {
        return 1; // 有結帳記錄的在前
      }

      // 其他商品按名稱排序
      return a.name.compareTo(b.name);
    });

    return sortedProducts;
  }

  /// 按名稱排序
  static List<Product> sortByName(List<Product> products) {
    final sorted = [...products];
    sorted.sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  /// 按價格排序
  static List<Product> sortByPrice(List<Product> products, {bool ascending = true}) {
    final sorted = [...products];
    if (ascending) {
      sorted.sort((a, b) => a.price.compareTo(b.price));
    } else {
      sorted.sort((a, b) => b.price.compareTo(a.price));
    }
    return sorted;
  }

  /// 按庫存排序
  static List<Product> sortByStock(List<Product> products, {bool ascending = true}) {
    final sorted = [...products];
    if (ascending) {
      sorted.sort((a, b) => a.stock.compareTo(b.stock));
    } else {
      sorted.sort((a, b) => b.stock.compareTo(a.stock));
    }
    return sorted;
  }

  /// 按條碼排序
  static List<Product> sortByBarcode(List<Product> products) {
    final sorted = [...products];
    sorted.sort((a, b) => a.barcode.compareTo(b.barcode));
    return sorted;
  }

  /// 過濾特殊商品
  static List<Product> filterSpecialProducts(List<Product> products) {
    return products.where((p) => p.isSpecialProduct).toList();
  }

  /// 過濾一般商品
  static List<Product> filterRegularProducts(List<Product> products) {
    return products.where((p) => !p.isSpecialProduct).toList();
  }

  /// 過濾有庫存的商品
  static List<Product> filterInStockProducts(List<Product> products) {
    return products.where((p) => p.stock > 0).toList();
  }

  /// 過濾缺貨商品
  static List<Product> filterOutOfStockProducts(List<Product> products) {
    return products.where((p) => p.stock <= 0).toList();
  }

  /// 過濾低庫存商品（庫存小於等於指定數量）
  static List<Product> filterLowStockProducts(List<Product> products, {int threshold = 10}) {
    return products.where((p) => p.stock <= threshold && p.stock > 0).toList();
  }
}
