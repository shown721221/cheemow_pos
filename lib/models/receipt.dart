import 'cart_item.dart';
import '../config/constants.dart';

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
  // 部分退貨：記錄各商品已退貨數量（key=product.id, value=已退數量）。
  // 若同時存在舊欄位 refundedProductIds，代表該商品視為全退（相容舊資料）。
  final Map<String, int> refundedQuantities;

  Receipt({
    required this.id,
    required this.timestamp,
    required this.items,
    required this.totalAmount,
    required this.totalQuantity,
    this.paymentMethod = PaymentMethods.cash,
    List<String>? refundedProductIds,
    Map<String, int>? refundedQuantities,
  }) : refundedProductIds = refundedProductIds ?? const [],
       refundedQuantities = refundedQuantities ?? const {};

  /// 從 JSON 建立 Receipt 物件
  factory Receipt.fromJson(Map<String, dynamic> json) {
    final rawRefunded = json['refundedProductIds'];
    final refundedIds = rawRefunded is List
        ? rawRefunded.map((e) => e.toString()).toList()
        : <String>[];
    // 讀取部分退貨映射（若無則為空）
    final Map<String, int> refundedQtyMap = {};
    final rawRefundedMap = json['refundedQuantities'];
    if (rawRefundedMap is Map) {
      rawRefundedMap.forEach((k, v) {
        final key = k.toString();
        final val = int.tryParse(v.toString());
        if (val != null && val > 0) refundedQtyMap[key] = val;
      });
    }

    return Receipt(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      items: (json['items'] as List)
          .map((item) => CartItem.fromJson(item))
          .toList(),
      totalAmount: json['totalAmount'],
      totalQuantity: json['totalQuantity'],
      paymentMethod: json['paymentMethod'] ?? PaymentMethods.cash,
      refundedProductIds: refundedIds,
      refundedQuantities: refundedQtyMap,
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
      'refundedQuantities': refundedQuantities,
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
      paymentMethod: PaymentMethods.cash,
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
    Map<String, int>? refundedQuantities,
  }) {
    return Receipt(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      refundedProductIds: refundedProductIds ?? this.refundedProductIds,
      refundedQuantities: refundedQuantities ?? this.refundedQuantities,
    );
  }

  /// 回傳該商品已退貨數量（若舊欄位標示全退，視為退購買總數）。
  int refundedQtyFor(String productId, int purchasedQty) {
    final byMap = refundedQuantities[productId] ?? 0;
    if (refundedProductIds.contains(productId)) {
      return purchasedQty; // 舊資料：全退
    }
    return byMap.clamp(0, purchasedQty);
  }

  /// 是否已全數退貨
  bool isFullyRefunded(String productId, int purchasedQty) {
    return refundedQtyFor(productId, purchasedQty) >= purchasedQty;
  }
}
