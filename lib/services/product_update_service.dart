import '../models/product.dart';
import '../models/cart_item.dart';
import '../utils/product_sorter.dart';
import 'local_database_service.dart';
import 'time_service.dart';

/// 結帳後商品更新結果
class ProductUpdateOutcome {
  /// 已更新（含扣庫存與結帳時間）的商品清單（未排序，用於持久化）
  final List<Product> updatedProducts;

  /// 依每日排序規則重新排序後的清單（用於 UI 顯示）
  final List<Product> resortedProducts;

  /// 實際更新商品數
  final int updatedCount;

  /// 這次結帳各條碼數量統計
  final Map<String, int> quantityByBarcode;

  const ProductUpdateOutcome({
    required this.updatedProducts,
    required this.resortedProducts,
    required this.updatedCount,
    required this.quantityByBarcode,
  });
}

/// 專責處理「結帳後更新商品」的服務
class ProductUpdateService {
  ProductUpdateService._();
  static final ProductUpdateService instance = ProductUpdateService._();

  /// 純計算：依購物車更新商品的庫存與最後結帳時間，並回傳更新後與重新排序結果。
  /// 不做持久化，方便單元測試。
  ProductUpdateOutcome compute(
    List<Product> products,
    List<CartItem> cartItems, {
    DateTime? now,
    bool useMicroOffset = true,
  }) {
    final checkoutTime = now ?? TimeService.now();

    // 以條碼聚合數量
    final Map<String, int> quantityByBarcode = {};
    for (final item in cartItems) {
      quantityByBarcode.update(
        item.product.barcode,
        (prev) => prev + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }

    final updatedProducts = <Product>[];
    int updatedCount = 0;

    // 為同一筆結帳中有售出的商品提供微秒遞增，避免排序時時間完全相同導致位置不穩
    int microOffset = 0;
    for (final p in products) {
      final qty = quantityByBarcode[p.barcode] ?? 0;
      if (qty > 0) {
        final newStock = p.isSpecialProduct ? p.stock : (p.stock - qty);
        final adjustedTime = useMicroOffset
            ? checkoutTime.add(Duration(microseconds: microOffset++))
            : checkoutTime;
        updatedProducts.add(
          Product(
            id: p.id,
            barcode: p.barcode,
            name: p.name,
            price: p.price,
            category: p.category,
            stock: newStock,
            isActive: p.isActive,
            lastCheckoutTime: adjustedTime,
          ),
        );
        updatedCount++;
      } else {
        updatedProducts.add(p);
      }
    }

    final resorted = ProductSorter.sortDaily(
      updatedProducts,
      now: checkoutTime,
    );

    return ProductUpdateOutcome(
      updatedProducts: updatedProducts,
      resortedProducts: resorted,
      updatedCount: updatedCount,
      quantityByBarcode: quantityByBarcode,
    );
  }

  /// 封裝流程：計算 -> 儲存（未排序版本，避免覆蓋排序帶來副作用）-> 回傳結果
  Future<ProductUpdateOutcome> applyCheckout({
    required List<Product> products,
    required List<CartItem> cartItems,
    DateTime? now,
    bool useMicroOffset = true,
  }) async {
    final outcome = compute(
      products,
      cartItems,
      now: now,
      useMicroOffset: useMicroOffset,
    );
    await LocalDatabaseService.instance.saveProducts(outcome.updatedProducts);
    return outcome;
  }
}
