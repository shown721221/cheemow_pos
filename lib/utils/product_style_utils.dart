import 'package:flutter/material.dart';
import '../models/product.dart';
import '../config/app_messages.dart';

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
    return AppMessages.stockLabel(stock);
  }

  /// 取得商品卡片的邊框樣式
  static BorderSide? getCardBorderSide(Product product) {
    final borderColor = getCardBorderColor(product);
    if (borderColor != null) {
      return BorderSide(color: borderColor, width: 2);
    }
    return null;
  }

  /// 取得商品 emoji 圖示（字串）
  static String getProductEmoji(Product product) {
    // 商品卡片一律使用購物袋 emoji
    return '🛍️';
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
      return AppMessages.stockOk;
    } else if (stock > 0) {
      return AppMessages.stockLow;
    } else if (stock == 0) {
      return AppMessages.stockOut;
    } else {
      return AppMessages.stockNegative;
    }
  }

  /// 取得庫存狀態 emoji
  static String getStockStatusEmoji(int stock) {
    if (stock > stockLowThreshold) {
      return '✅';
    } else if (stock > 0) {
      return '⚠️';
    } else if (stock == 0) {
      return '⛔️';
    } else {
      return '🚫';
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
      border: borderColor != null
          ? Border.all(color: borderColor, width: 2)
          : null,
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
    if (product.isPreOrderProduct) return AppMessages.chipPreorder;
    if (product.isDiscountProduct) return AppMessages.chipDiscount;
    return null;
  }

  /// 建立商品型態 Chip（預設不顯示一般商品）
  static Widget buildTypeChip(Product product, {bool showNormal = false}) {
    final label =
        getTypeBadgeLabel(product) ??
        (showNormal ? AppMessages.typeNormal : null);
    if (label == null) return const SizedBox.shrink();

    final color = getTypeBadgeColor(product) ?? Colors.grey[200]!;
    final textColor = product.isPreOrderProduct
        ? Colors.purple[800]
        : product.isDiscountProduct
        ? Colors.orange[800]
        : Colors.grey[800];

    return Chip(
      label: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  /// 建立庫存狀態 Chip（充足/偏低/缺貨/負庫存）
  static Widget buildStockChip(int stock) {
    final baseColor = getStockColor(stock);
    // 避免 withOpacity 的棄用警告，改為 withValues 近似 12% 透明度
    final bg = baseColor.withValues(alpha: 0.12);
    final icon = getStockStatusEmoji(stock);
    final text = getStockStatusDescription(stock);
    return Chip(
      avatar: Text(icon, style: const TextStyle(fontSize: 14)),
      label: Text(
        text,
        style: TextStyle(color: baseColor, fontWeight: FontWeight.w600),
      ),
      backgroundColor: bg,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
