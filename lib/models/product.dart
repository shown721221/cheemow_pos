/// 商品模型類別
class Product {
  final String id;
  final String barcode;
  final String name;
  final int price; // 台幣整數元
  final String category;
  final int stock;
  final bool isActive;

  Product({
    required this.id,
    required this.barcode,
    required this.name,
    required this.price,
    this.category = '',
    this.stock = 0,
    this.isActive = true,
  });

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
    };
  }
}
