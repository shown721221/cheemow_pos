import 'cart_item.dart';

/// 收據模型 - 記錄每筆交易的完整資訊
class Receipt {
  final String id;
  final DateTime timestamp;
  final List<CartItem> items;
  final int totalAmount;
  final int totalQuantity;
  final String paymentMethod;
  // 已退貨的品項（以 product.id 標記）。此清單中的品項僅保留於明細顯示，不計入合計與件數。
  final List<String> refundedProductIds;

  Receipt({
    required this.id,
    required this.timestamp,
    required this.items,
    required this.totalAmount,
    required this.totalQuantity,
    this.paymentMethod = '現金',
    List<String>? refundedProductIds,
  }) : refundedProductIds = refundedProductIds ?? const [];

  /// 從 JSON 建立 Receipt 物件
  factory Receipt.fromJson(Map<String, dynamic> json) {
    final rawRefunded = json['refundedProductIds'];
    final refundedIds = rawRefunded is List
        ? rawRefunded.map((e) => e.toString()).toList()
        : <String>[];

    return Receipt(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      items: (json['items'] as List)
          .map((item) => CartItem.fromJson(item))
          .toList(),
      totalAmount: json['totalAmount'],
      totalQuantity: json['totalQuantity'],
      paymentMethod: json['paymentMethod'] ?? '現金',
      refundedProductIds: refundedIds,
    );
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'totalQuantity': totalQuantity,
      'paymentMethod': paymentMethod,
      'refundedProductIds': refundedProductIds,
    };
  }

  /// 格式化時間顯示
  String get formattedDateTime {
    return '${timestamp.year}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化日期（用於按日統計）
  String get formattedDate {
    return '${timestamp.year}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.day.toString().padLeft(2, '0')}';
  }

  /// 從購物車建立收據
  factory Receipt.fromCart(List<CartItem> cartItems) {
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}'; // 使用時間戳作為 ID

    final totalAmount = cartItems.fold<int>(
      0,
      (sum, item) => sum + item.subtotal,
    );

    final totalQuantity = cartItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return Receipt(
      id: id,
      timestamp: now,
      items: List.from(cartItems), // 建立副本避免引用問題
      totalAmount: totalAmount,
      totalQuantity: totalQuantity,
      paymentMethod: '現金',
      refundedProductIds: const [],
    );
  }

  /// 複製 Receipt 並修改部分屬性
  Receipt copyWith({
    String? id,
    DateTime? timestamp,
    List<CartItem>? items,
    int? totalAmount,
    int? totalQuantity,
    String? paymentMethod,
    List<String>? refundedProductIds,
  }) {
    return Receipt(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      refundedProductIds: refundedProductIds ?? this.refundedProductIds,
    );
  }
}
