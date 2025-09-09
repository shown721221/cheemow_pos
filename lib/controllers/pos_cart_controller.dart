import '../models/product.dart';
import '../models/cart_item.dart';

/// 負責購物車邏輯的控制器（不含 UI / Scaffold 互動）
/// 目的：抽離 `pos_main_screen.dart` 中的業務操作，提升可維護與測試性。
class PosCartController {
  final List<CartItem> cartItems;
  PosCartController(this.cartItems);

  /// 新增商品到購物車。
  /// 若同商品同實際價格已存在，則數量+1並移到頂部；
  /// 否則建立（必要時複製一份覆寫價格）插入頂部。
  void addProduct(Product product, int actualPrice) {
    final existingIndex = cartItems.indexWhere(
      (item) => item.product.id == product.id && item.product.price == actualPrice,
    );

    if (existingIndex >= 0) {
      cartItems[existingIndex].increaseQuantity();
      final item = cartItems.removeAt(existingIndex);
      cartItems.insert(0, item);
      return;
    }

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

    cartItems.insert(0, CartItem(product: productToAdd, quantity: 1));
  }

  void removeAt(int index) {
    if (index >= 0 && index < cartItems.length) {
      cartItems.removeAt(index);
    }
  }

  void clear() => cartItems.clear();

  int get totalAmount => cartItems.fold(0, (t, i) => t + i.subtotal);

  int get totalQuantity => cartItems.fold(0, (t, i) => t + i.quantity);

  /// 非折扣金額總和（含預購與一般正向商品）
  int get nonDiscountTotal => cartItems
      .where((item) => !item.product.isDiscountProduct)
      .fold<int>(0, (sum, item) => sum + item.subtotal);

  /// 折扣絕對值總和（所有為負的項目取正相加）
  int get discountAbsTotal => cartItems
      .where((item) => item.product.isDiscountProduct)
      .fold<int>(0, (sum, item) => sum + (item.subtotal < 0 ? -item.subtotal : item.subtotal));
}
