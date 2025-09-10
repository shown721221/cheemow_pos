import '../models/product.dart';
import 'local_database_service.dart';

/// 掃碼結果類型
enum ScanAddResult {
  /// 找到一般商品（可直接加入購物車）
  foundNormal,

  /// 找到特殊商品（價格為 0，需要輸入實際價格）
  foundSpecialNeedsPrice,

  /// 找不到商品
  notFound,
}

/// 掃碼決策結果
class ScanAddDecision {
  final ScanAddResult result;
  final Product? product; // 僅在 found* 時有值

  const ScanAddDecision(this.result, {this.product});

  bool get isFound => result == ScanAddResult.foundNormal || result == ScanAddResult.foundSpecialNeedsPrice;
}

/// 條碼掃描加入購物車的決策輔助（純邏輯，方便測試）
class BarcodeScanHelper {
  /// 由資料庫查詢做出決策（便捷方法）
  static Future<ScanAddDecision> decideFromDatabase(String barcode) async {
    final product = await LocalDatabaseService.instance.getProductByBarcode(barcode);
    return _decide(product);
  }

  /// 由既有商品清單做出決策（純計算，單元測試建議使用）
  static ScanAddDecision decideFromProducts(String barcode, List<Product> products) {
    try {
      final product = products.firstWhere((p) => p.barcode == barcode);
      return _decide(product);
    } catch (_) {
      return const ScanAddDecision(ScanAddResult.notFound);
    }
  }

  static ScanAddDecision _decide(Product? product) {
    if (product == null) return const ScanAddDecision(ScanAddResult.notFound);
    if (product.price == 0 || product.isSpecialProduct) {
      // 特殊商品（或價格為0）需要輸入價格
      return ScanAddDecision(ScanAddResult.foundSpecialNeedsPrice, product: product);
    }
    return ScanAddDecision(ScanAddResult.foundNormal, product: product);
  }
}
