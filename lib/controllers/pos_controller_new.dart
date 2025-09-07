import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/receipt.dart';
import '../services/receipt_service.dart';
import '../managers/product_manager.dart';
import '../managers/cart_manager.dart';
import '../managers/barcode_manager.dart';

/// 簡化版 POS 控制器
/// 協調各個管理器的工作
class PosControllerNew extends ChangeNotifier {
  late final ProductManager _productManager;
  late final CartManager _cartManager;
  late final BarcodeManager _barcodeManager;

  PosControllerNew() {
    _productManager = ProductManager();
    _cartManager = CartManager();
    _barcodeManager = BarcodeManager();
    
    // 監聽子管理器的變化
    _productManager.addListener(_onManagerUpdate);
    _cartManager.addListener(_onManagerUpdate);
    
    // 設置條碼掃描回調
    _barcodeManager.initialize(
      onBarcodeComplete: _handleBarcodeScanned,
    );
  }

  // === Getters - 委派給對應的管理器 ===
  
  List<Product> get products => _productManager.products;
  List<CartItem> get cartItems => _cartManager.cartItems;
  int get totalAmount => _cartManager.totalAmount;
  int get totalQuantity => _cartManager.totalQuantity;
  bool get hasItems => _cartManager.hasItems;
  String get lastScannedBarcode => _productManager.lastScannedBarcode;
  bool get hasUnfoundProduct => _productManager.hasUnfoundProduct;

  // === 初始化 ===
  
  Future<void> initialize() async {
    await _productManager.initialize();
  }

  // === 商品操作 ===
  
  Future<void> refreshProducts() async {
    await _productManager.refreshProducts();
  }

  void clearUnfoundProduct() {
    _productManager.clearUnfoundProduct();
  }

  // === 購物車操作 ===
  
  void addToCart(Product product) {
    _cartManager.addToCart(product);
  }

  void addProductToCart(Product product, int customPrice) {
    _cartManager.addToCart(product, customPrice);
  }

  void increaseQuantity(int index) {
    _cartManager.increaseQuantity(index);
  }

  void decreaseQuantity(int index) {
    _cartManager.decreaseQuantity(index);
  }

  void removeFromCart(int index) {
    _cartManager.removeFromCart(index);
  }

  void clearCart() {
    _cartManager.clearCart();
  }

  // === 條碼掃描 ===
  
  void handleBarcodeInput(String character) {
    _barcodeManager.handleCharacterInput(character);
  }

  void processBarcodeScanned(String barcode) {
    _productManager.processBarcodeScanned(barcode);
    
    // 如果找到商品，自動添加到購物車
    final product = _productManager.findProductByBarcode(barcode);
    if (product != null) {
      if (product.price == 0) {
        // 特殊商品需要手動處理價格輸入
        if (kDebugMode) {
          print('特殊商品需要手動輸入價格: ${product.name}');
        }
      } else {
        // 普通商品直接添加到購物車
        addToCart(product);
      }
    }
  }

  // === 結帳流程 ===
  
  Future<Receipt?> processCheckout() async {
    if (!hasItems) return null;

    try {
      // 創建收據
      final receipt = Receipt(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        items: List.from(cartItems),
        totalAmount: totalAmount,
        totalQuantity: totalQuantity,
      );

      // 保存收據
      await ReceiptService.instance.saveReceipt(receipt);
      
      // 更新庫存
      await _cartManager.updateStock();
      
      // 清空購物車
      clearCart();
      
      // 重新載入商品（更新庫存顯示）
      await refreshProducts();
      
      if (kDebugMode) {
        print('結帳完成，收據編號: ${receipt.id}');
      }
      
      return receipt;
    } catch (e) {
      if (kDebugMode) {
        print('結帳失敗: $e');
      }
      return null;
    }
  }

  // === 私有方法 ===
  
  void _onManagerUpdate() {
    notifyListeners();
  }

  void _handleBarcodeScanned(String barcode) {
    processBarcodeScanned(barcode);
  }

  // === 清理資源 ===
  
  @override
  void dispose() {
    _productManager.removeListener(_onManagerUpdate);
    _cartManager.removeListener(_onManagerUpdate);
    _productManager.dispose();
    _cartManager.dispose();
    _barcodeManager.dispose();
    super.dispose();
  }
}
