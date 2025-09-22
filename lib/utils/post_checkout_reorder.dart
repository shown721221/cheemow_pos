import '../models/product.dart';
import '../models/cart_item.dart';
import 'product_special_strategy.dart';

/// 將本次結帳所售出的「一般商品」置於預購/折扣後方並保留其餘順序。
/// 規則：
/// 1. 預購商品 (isPreOrderProduct) 永遠在最前
/// 2. 折扣商品 (isDiscountProduct) 接在預購後
/// 3. 本次售出的非特殊商品 (依購物車加入唯一順序 reversed -> 實際結果為目前控制器的順序) 接在特殊商品後
/// 4. 其餘非特殊商品保持原本相對順序
List<Product> reorderAfterCheckout({
  required List<Product> currentProducts,
  required List<CartItem> soldCartSnapshot,
  SpecialProductStrategy strategy = const PreOrderThenDiscountStrategy(),
}) {
  if (soldCartSnapshot.isEmpty) return currentProducts;

  // 取得購物車加入順序的唯一商品 id 列表
  final soldIdsInOrder = <String>[];
  for (final c in soldCartSnapshot) {
    final id = c.product.id;
    if (!soldIdsInOrder.contains(id)) {
      soldIdsInOrder.add(id);
    }
  }
  if (soldIdsInOrder.isEmpty) return currentProducts;

  final specials = strategy.sortSpecials(currentProducts);
  final specialsSet = specials.map((e) => e.id).toSet();
  final others = <Product>[];
  for (final p in currentProducts) {
    if (!specialsSet.contains(p.id)) others.add(p);
  }

  // Map 方便取出
  final byId = {for (final p in others) p.id: p};
  final soldNonSpecial = <Product>[];
  for (final id in soldIdsInOrder.reversed) {
    final p = byId[id];
    if (p != null) soldNonSpecial.add(p);
  }
  others.removeWhere((p) => soldNonSpecial.any((s) => s.id == p.id));

  return [...specials, ...soldNonSpecial, ...others];
}
