import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../services/local_database_service.dart';

/// 購物車管理器
class CartManager extends ChangeNotifier {
  final List<CartItem> _cartItems = [];

  List<CartItem> get cartItems => List.unmodifiable(_cartItems);
  
  bool get hasItems => _cartItems.isNotEmpty;
  
  int get totalAmount {
    return _cartItems.fold(0, (total, item) => total + item.subtotal);
  }

  int get totalQuantity {
    return _cartItems.fold(0, (total, item) => total + item.quantity);
  }

  /// 添加商品到購物車
  void addToCart(Product product, [int? customPrice]) {
    final existingIndex = _cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      // 商品已存在，增加數量
      _cartItems[existingIndex].increaseQuantity();
    } else {
      // 新商品，添加到購物車
      final productToAdd = customPrice != null 
          ? Product(
              id: product.id,
              name: product.name,
              barcode: product.barcode,
              price: customPrice,
              stock: product.stock,
              lastCheckoutTime: product.lastCheckoutTime,
            )
          : product;
      
      _cartItems.add(CartItem(product: productToAdd, quantity: 1));
    }
    
    notifyListeners();
    if (kDebugMode) {
      print('添加商品到購物車: ${product.name}, 當前購物車商品數: ${_cartItems.length}');
    }
  }

  /// 增加商品數量
  void increaseQuantity(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index].increaseQuantity();
      notifyListeners();
    }
  }

  /// 減少商品數量
  void decreaseQuantity(int index) {
    if (index >= 0 && index < _cartItems.length) {
      if (_cartItems[index].quantity > 1) {
        _cartItems[index].decreaseQuantity();
      } else {
        _cartItems.removeAt(index);
      }
      notifyListeners();
    }
  }

  /// 移除商品
  void removeFromCart(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
    }
  }

  /// 清空購物車
  void clearCart() {
    _cartItems.clear();
    notifyListeners();
    if (kDebugMode) {
      print('購物車已清空');
    }
  }

  /// 更新庫存
  Future<void> updateStock() async {
    try {
      for (final item in _cartItems) {
        final newStock = item.product.stock - item.quantity;
        await LocalDatabaseService.instance.updateProductStock(
          item.product.id,
          newStock,
        );
      }
      
      if (kDebugMode) {
        print('庫存更新完成');
      }
    } catch (e) {
      if (kDebugMode) {
        print('更新庫存失敗: $e');
      }
      rethrow;
    }
  }
}
