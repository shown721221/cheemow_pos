import 'package:flutter/material.dart';
import '../models/product.dart';

/// 商品顯示樣式工具
class ProductStyleUtils {
  
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
    if (stock > 10) {
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
    if (stock > 10) {
      return Icons.check_circle;
    } else if (stock > 0) {
      return Icons.warning;
    } else if (stock == 0) {
      return Icons.error;
    } else {
      return Icons.dangerous;
    }
  }
}
