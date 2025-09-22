import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cheemeow_pos/utils/app_logger.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/receipt.dart';
import '../services/local_database_service.dart';
import '../services/receipt_service.dart';

/// POS 系統核心業務邏輯控制器
/// 負責處理商品管理、購物車邏輯、結帳流程等核心業務
class PosController extends ChangeNotifier {
  // 核心資料
  List<Product> _products = [];
  final List<CartItem> _cartItems = [];
  String _lastScannedBarcode = '';

  // 掃描相關
  String _scanBuffer = '';
  Timer? _scanTimer;

  // Getters
  List<Product> get products => List.unmodifiable(_products);
  List<CartItem> get cartItems => List.unmodifiable(_cartItems);
  String get lastScannedBarcode => _lastScannedBarcode;

  int get totalAmount =>
      _cartItems.fold(0, (total, item) => total + item.subtotal);
  int get totalQuantity =>
      _cartItems.fold(0, (total, item) => total + item.quantity);
  bool get hasItems => _cartItems.isNotEmpty;

  /// 初始化控制器
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

  /// 商品排序邏輯
  void _sortProducts(List<Product> products) {
    products.sort((a, b) {
      // 1. 特殊商品始終在最前面
      if (a.isSpecialProduct && !b.isSpecialProduct) return -1;
      if (b.isSpecialProduct && !a.isSpecialProduct) return 1;

      // 2. 兩個都是特殊商品時，預約商品排在折扣商品前面
      if (a.isSpecialProduct && b.isSpecialProduct) {
        if (a.isPreOrderProduct && b.isDiscountProduct) return -1;
        if (a.isDiscountProduct && b.isPreOrderProduct) return 1;
        return 0;
      }

      // 3. 兩個都是普通商品時，按最後結帳時間排序
      if (a.lastCheckoutTime != null && b.lastCheckoutTime != null) {
        return b.lastCheckoutTime!.compareTo(a.lastCheckoutTime!);
      } else if (a.lastCheckoutTime != null) {
        return -1;
      } else if (b.lastCheckoutTime != null) {
        return 1;
      }

      // 4. 兩個都沒有結帳記錄，按商品名稱排序
      return a.name.compareTo(b.name);
    });
  }

  /// 處理條碼掃描輸入
  void handleBarcodeInput(String character) {
    _scanBuffer += character;

    // 重置計時器
    _scanTimer?.cancel();
    _scanTimer = Timer(Duration(milliseconds: 100), () {
      if (_scanBuffer.isNotEmpty) {
        processBarcodeScanned(_scanBuffer.trim());
        _scanBuffer = '';
      }
    });
  }

  /// 處理完整條碼掃描
  void processBarcodeScanned(String barcode) async {
    try {
      final product = await LocalDatabaseService.instance.getProductByBarcode(
        barcode,
      );
      if (product != null) {
        addToCart(product);
        _lastScannedBarcode = barcode;
        notifyListeners();
      } else {
        // 產品未找到，需要在 UI 層處理
        _lastScannedBarcode = barcode;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.w('掃描條碼處理失敗', e);
      }
    }
  }

  /// 添加商品到購物車
  void addToCart(Product product) {
    // 如果是特殊商品（價格為0），需要在 UI 層處理價格輸入
    if (product.price == 0) {
      // 由 UI 層處理價格輸入對話框
      return;
    }

    addProductToCart(product, product.price);
  }

  /// 添加指定價格的商品到購物車
  void addProductToCart(Product product, int actualPrice) {
    final productToAdd = actualPrice != product.price
        ? Product(
            id: product.id,
            barcode: product.barcode,
            name: product.name,
            price: actualPrice,
            category: product.category,
            stock: product.stock,
            isActive: product.isActive,
            lastCheckoutTime: product.lastCheckoutTime,
          )
        : product;

    final existingItemIndex = _cartItems.indexWhere(
      (item) =>
          item.product.id == productToAdd.id &&
          item.product.price == actualPrice,
    );

    if (existingItemIndex >= 0) {
      // 如果商品已存在，增加數量並移到頂部
      final existingItem = _cartItems.removeAt(existingItemIndex);
      existingItem.increaseQuantity();
      _cartItems.insert(0, existingItem);
    } else {
      // 新商品插入到頂部（索引0）
      _cartItems.insert(0, CartItem(product: productToAdd));
    }

    notifyListeners();
  }

  /// 從購物車移除商品
  void removeFromCart(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
    }
  }

  /// 增加商品數量
  void increaseQuantity(int index) {
    if (index >= 0 && index < _cartItems.length) {
      // 移除該項目，增加數量後插入到頂部
      final item = _cartItems.removeAt(index);
      item.increaseQuantity();
      _cartItems.insert(0, item);
      notifyListeners();
    }
  }

  /// 減少商品數量
  void decreaseQuantity(int index) {
    if (index >= 0 && index < _cartItems.length) {
      if (_cartItems[index].quantity > 1) {
        _cartItems[index].decreaseQuantity();
        notifyListeners();
      } else {
        removeFromCart(index);
      }
    }
  }

  /// 清空購物車
  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  /// 處理結帳流程
  Future<Receipt?> processCheckout() async {
    if (_cartItems.isEmpty) return null;

    try {
      // 結帳前最終把關：折扣不可大於非折扣商品總額（避免負總額）
      final int nonDiscountTotal = _cartItems
          .where((item) => !item.product.isDiscountProduct)
          .fold<int>(0, (sum, item) => sum + item.subtotal);
      final int discountAbsTotal = _cartItems
          .where((item) => item.product.isDiscountProduct)
          .fold<int>(
            0,
            (sum, item) =>
                sum + (item.subtotal < 0 ? -item.subtotal : item.subtotal),
          );

      if (discountAbsTotal > nonDiscountTotal) {
        if (kDebugMode) {
          AppLogger.w(
            '折扣金額 ($discountAbsTotal) 大於非折扣商品總額 ($nonDiscountTotal)，已阻止結帳',
          );
        }
        return null;
      }

      final checkoutTime = DateTime.now();

      // 1. 建立收據並儲存（優先級最高）
      final receipt = Receipt.fromCart(_cartItems);
      final receiptSaved = await ReceiptService.instance.saveReceipt(receipt);

      if (!receiptSaved) {
        throw Exception('收據儲存失敗');
      }

      if (kDebugMode) {
        AppLogger.i('收據已安全儲存: ${receipt.id}');
      }

      // 2. 更新商品的結帳時間
      await _updateProductCheckoutTime(checkoutTime);

      // 3. 清空購物車
      clearCart();

      return receipt;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.w('結帳處理失敗', e);
      }
      return null;
    }
  }

  /// 更新商品結帳時間
  Future<void> _updateProductCheckoutTime(DateTime checkoutTime) async {
    try {
      // 記錄結帳的商品條碼
      final checkedOutBarcodes = _cartItems
          .map((item) => item.product.barcode)
          .toSet();

      // 創建新的商品列表，更新結帳時間
      final updatedProducts = <Product>[];
      int updatedCount = 0;

      for (final product in _products) {
        if (checkedOutBarcodes.contains(product.barcode)) {
          final updatedProduct = product.copyWithLastCheckoutTime(checkoutTime);
          updatedProducts.add(updatedProduct);
          updatedCount++;
        } else {
          updatedProducts.add(product);
        }
      }

      // 重新排序商品
      _sortProducts(updatedProducts);

      // 更新商品列表
      _products = updatedProducts;

      // 保存到本地資料庫
      await LocalDatabaseService.instance.saveProducts(_products);

      notifyListeners();

      if (kDebugMode) {
        AppLogger.d('實際更新了 $updatedCount 個商品的結帳時間');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.w('更新商品結帳時間失敗', e);
      }
    }
  }

  /// 檢查是否有未找到的商品（用於 UI 顯示錯誤）
  bool get hasUnfoundProduct =>
      _lastScannedBarcode.isNotEmpty &&
      !_products.any((p) => p.barcode == _lastScannedBarcode);

  /// 清除未找到商品的狀態
  void clearUnfoundProduct() {
    _lastScannedBarcode = '';
    notifyListeners();
  }

  /// 刷新商品列表
  Future<void> refreshProducts() async {
    await _loadProducts();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }
}
