import 'package:flutter/foundation.dart';
import 'package:cheemeow_pos/utils/app_logger.dart';
import '../models/product.dart';
import '../services/local_database_service.dart';

/// 商品管理器
class ProductManager extends ChangeNotifier {
  List<Product> _products = [];
  String _lastScannedBarcode = '';
  bool _hasUnfoundProduct = false;

  // Getters
  List<Product> get products => List.unmodifiable(_products);
  String get lastScannedBarcode => _lastScannedBarcode;
  bool get hasUnfoundProduct => _hasUnfoundProduct;

  /// 初始化商品管理器
  Future<void> initialize() async {
    await _loadProducts();
  }

  /// 載入商品資料
  Future<void> _loadProducts() async {
    try {
      await LocalDatabaseService.instance.ensureSpecialProducts();
      final loadedProducts = await LocalDatabaseService.instance.getProducts();

      // 對商品進行排序：特殊商品在最前面
      _sortProducts(loadedProducts);

      _products = loadedProducts;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        AppLogger.w('載入商品失敗', e);
      }
    }
  }

  /// 重新載入商品資料
  Future<void> refreshProducts() async {
    await _loadProducts();
  }

  /// 對商品進行排序
  void _sortProducts(List<Product> products) {
    products.sort((a, b) {
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
  }

  /// 處理條碼掃描
  void processBarcodeScanned(String barcode) {
    _lastScannedBarcode = barcode;

    // 尋找對應的商品
    final product = _findProductByBarcode(barcode);

    if (product != null) {
      // 找到商品，觸發添加到購物車的回調
      if (kDebugMode) {
        AppLogger.d('找到商品: ${product.name}');
      }
      _hasUnfoundProduct = false;
      notifyListeners();
    } else {
      // 沒找到商品
      if (kDebugMode) {
        AppLogger.d('找不到條碼對應的商品: $barcode');
      }
      _hasUnfoundProduct = true;
      notifyListeners();
    }
  }

  /// 根據條碼查找商品
  Product? _findProductByBarcode(String barcode) {
    try {
      return _products.firstWhere((product) => product.barcode == barcode);
    } catch (e) {
      return null;
    }
  }

  /// 清除未找到商品的狀態
  void clearUnfoundProduct() {
    _hasUnfoundProduct = false;
    notifyListeners();
  }

  /// 根據條碼查找商品（公開方法）
  Product? findProductByBarcode(String barcode) {
    return _findProductByBarcode(barcode);
  }
}
