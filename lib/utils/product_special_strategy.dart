import '../models/product.dart';

/// 決定『特殊商品』的排序策略（例如：預購優先、或折扣優先）。
abstract class SpecialProductStrategy {
  /// 回傳排序後的特殊商品清單（輸入為所有產品，實作需自行過濾）。
  List<Product> sortSpecials(List<Product> allProducts);
}

/// 預設策略：預購 -> 折扣。
class PreOrderThenDiscountStrategy implements SpecialProductStrategy {
  const PreOrderThenDiscountStrategy();
  @override
  List<Product> sortSpecials(List<Product> allProducts) {
    final pre = allProducts.where((p) => p.isPreOrderProduct);
    final disc = allProducts.where((p) => p.isDiscountProduct);
    return [...pre, ...disc];
  }
}

/// 範例：折扣 -> 預購（僅供單元測試驗證策略可替換性）。
class DiscountThenPreOrderStrategy implements SpecialProductStrategy {
  const DiscountThenPreOrderStrategy();
  @override
  List<Product> sortSpecials(List<Product> allProducts) {
    final disc = allProducts.where((p) => p.isDiscountProduct);
    final pre = allProducts.where((p) => p.isPreOrderProduct);
    return [...disc, ...pre];
  }
}
