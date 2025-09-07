import 'package:flutter/material.dart';
import '../models/product.dart';

/// 商品顯示樣式工具
class ProductStyleUtils {
  // 閾值設定（可集中管理與後續調整）
  static const int stockLowThreshold = 10;
  
  /// 根據商品類型取得商品名稱的顏色
  static Color getProductNameColor(Product product) {
    if (product.isPreOrderProduct) {
      return Colors.purple[700]!; // 預約商品：紫色
    } else if (product.isDiscountProduct) {
      return Colors.orange[700]!; // 折扣商品：橘色
    } else {
      return Colors.black87; // 一般商品：黑色
    }
  }

  /// 根據商品類型取得卡片的邊框顏色
  static Color? getCardBorderColor(Product product) {
    if (product.isPreOrderProduct) {
      return Colors.purple[300]; // 預約商品：淺紫色邊框
    } else if (product.isDiscountProduct) {
      return Colors.orange[300]; // 折扣商品：淺橘色邊框
    }
    return null; // 一般商品：無特殊邊框
  }

  /// 根據庫存數量回傳對應的顏色
  static Color getStockColor(int stock) {
    if (stock > 0) {
      return Colors.green[700]!; // 正數：綠色
    } else if (stock == 0) {
      return Colors.orange[700]!; // 零：橘色
    } else {
      return Colors.red[700]!; // 負數：紅色
    }
  }

  /// 根據庫存數量回傳顯示文字
  static String getStockText(int stock) {
    return '庫存: $stock';
  }

  /// 取得商品卡片的邊框樣式
  static BorderSide? getCardBorderSide(Product product) {
    final borderColor = getCardBorderColor(product);
    if (borderColor != null) {
      return BorderSide(
        color: borderColor,
        width: 2,
      );
    }
    return null;
  }

  /// 取得商品圖標（根據商品類型）
  static IconData getProductIcon(Product product) {
    // 商品卡片一律使用購物袋圖標
    return Icons.shopping_bag;
  }

  /// 取得商品圖標顏色
  static Color getProductIconColor(Product product) {
    if (product.isPreOrderProduct) {
      return Colors.purple[600]!;
    } else if (product.isDiscountProduct) {
      return Colors.orange[600]!;
    } else {
      return Colors.grey[600]!;
    }
  }

  /// 取得庫存狀態描述
  static String getStockStatusDescription(int stock) {
  if (stock > stockLowThreshold) {
      return '充足';
    } else if (stock > 0) {
      return '偏低';
    } else if (stock == 0) {
      return '缺貨';
    } else {
      return '負庫存';
    }
  }

  /// 取得庫存狀態圖標
  static IconData getStockStatusIcon(int stock) {
    if (stock > stockLowThreshold) {
      return Icons.check_circle;
    } else if (stock > 0) {
      return Icons.warning;
    } else if (stock == 0) {
      return Icons.error;
    } else {
      return Icons.dangerous;
    }
  }

  /// 商品名稱的統一樣式（依商品型態給色，字重適中）
  static TextStyle productNameTextStyle(Product product) {
    return TextStyle(
      color: getProductNameColor(product),
      fontWeight: FontWeight.w600,
    );
  }

  /// 卡片外觀統一（含邊框與圓角），方便各商品卡片共用
  static BoxDecoration buildCardDecoration(Product product) {
    final borderColor = getCardBorderColor(product);
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: borderColor != null ? Border.all(color: borderColor, width: 2) : null,
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000), // 適度陰影（8% 不透明度）
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  /// 回傳商品型態徽章顏色（預購/折扣）
  static Color? getTypeBadgeColor(Product product) {
    if (product.isPreOrderProduct) return Colors.purple[200];
    if (product.isDiscountProduct) return Colors.orange[200];
    return null;
  }

  /// 回傳商品型態徽章標籤
  static String? getTypeBadgeLabel(Product product) {
    if (product.isPreOrderProduct) return '預購';
    if (product.isDiscountProduct) return '折扣';
    return null;
  }

  /// 建立商品型態 Chip（預設不顯示一般商品）
  static Widget buildTypeChip(Product product, {bool showNormal = false}) {
    final label = getTypeBadgeLabel(product) ?? (showNormal ? '一般' : null);
    if (label == null) return const SizedBox.shrink();

    final color = getTypeBadgeColor(product) ?? Colors.grey[200]!;
    final textColor = product.isPreOrderProduct
        ? Colors.purple[800]
        : product.isDiscountProduct
            ? Colors.orange[800]
            : Colors.grey[800];

    return Chip(
      label: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  /// 建立庫存狀態 Chip（充足/偏低/缺貨/負庫存）
  static Widget buildStockChip(int stock) {
    final baseColor = getStockColor(stock);
    final bg = baseColor.withOpacity(0.12); // Material 推薦的提示底色透明度
    final icon = getStockStatusIcon(stock);
    final text = getStockStatusDescription(stock);
    return Chip(
      avatar: Icon(icon, size: 16, color: baseColor),
      label: Text(text, style: TextStyle(color: baseColor, fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
