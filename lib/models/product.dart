import '../config/constants.dart';

/// 商品模型類別
class Product {
  final String id;
  final String barcode;
  final String name;
  final int price; // 台幣整數元
  final String category;
  final int stock;
  final bool isActive;
  final DateTime? lastCheckoutTime; // 最後結帳時間

  Product({
    required this.id,
    required this.barcode,
    required this.name,
    required this.price,
    this.category = '',
    this.stock = 0,
    this.isActive = true,
    this.lastCheckoutTime,
  });

  // 檢查是否為特殊商品（預約商品或折扣商品）
  // 為了容忍僅持久化最小欄位（未保存 category），這裡同時以條碼判斷
  bool get isSpecialProduct =>
      isPreOrderProduct || isDiscountProduct || category == AppConstants.specialCategory;

  // 檢查是否為預約商品
  bool get isPreOrderProduct => barcode == AppConstants.barcodePreOrder;

  // 檢查是否為折扣商品 - 修正商品名稱為 "祝您有奇妙的一天"
  bool get isDiscountProduct => barcode == AppConstants.barcodeDiscount;

  // 格式化價格顯示（純文字版本，用於列印等場合）
  String get formattedPrice => 'NT\$ $price';

  // 取得價格數字（用於 UI 顯示搭配圖示）
  String get priceText => price.toString();

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      barcode: json['barcode'],
      name: json['name'],
      price: json['price'],
      category: json['category'] ?? '',
      stock: json['stock'] ?? 0,
      isActive: json['isActive'] ?? true,
      lastCheckoutTime: json['lastCheckoutTime'] != null
          ? DateTime.parse(json['lastCheckoutTime'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'price': price,
      'category': category,
      'stock': stock,
      'isActive': isActive,
      'lastCheckoutTime': lastCheckoutTime?.toIso8601String(),
    };
  }

  // 建立一個帶有新結帳時間的商品副本
  Product copyWithLastCheckoutTime(DateTime checkoutTime) {
    return Product(
      id: id,
      barcode: barcode,
      name: name,
      price: price,
      category: category,
      stock: stock,
      isActive: isActive,
      lastCheckoutTime: checkoutTime,
    );
  }
}
