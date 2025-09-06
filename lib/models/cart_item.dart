import 'product.dart';

/// 購物車商品項目
class CartItem {
  final Product product;
  int quantity;
  final DateTime addedTime; // 加入購物車的時間

  CartItem({required this.product, this.quantity = 1, DateTime? addedTime})
    : addedTime = addedTime ?? DateTime.now();

  /// 單項小計（台幣整數元）
  int get subtotal => product.price * quantity;

  /// 格式化小計顯示（純文字版本）
  String get formattedSubtotal => 'NT\$ $subtotal';

  /// 取得小計數字（用於 UI 顯示搭配圖示）
  String get subtotalText => subtotal.toString();

  void increaseQuantity() {
    quantity++;
  }

  void decreaseQuantity() {
    if (quantity > 1) {
      quantity--;
    }
  }
}
