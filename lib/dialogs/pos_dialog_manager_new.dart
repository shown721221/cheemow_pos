// 整合所有對話框的統一接口
export 'product_dialogs.dart';
export 'checkout_dialogs.dart';
export 'system_dialogs.dart';

import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/receipt.dart';
import 'product_dialogs.dart';
import 'checkout_dialogs.dart';
import 'system_dialogs.dart';

/// POS 對話框管理器 - 統一接口
/// 這個類別作為所有對話框的統一入口點，保持向後相容性
class PosDialogManager {
  
  // === 商品相關對話框 ===
  
  static Future<int?> showPriceInputDialog(
    BuildContext context,
    Product product,
  ) {
    return ProductDialogs.showPriceInputDialog(context, product);
  }

  static void showProductNotFoundDialog(
    BuildContext context,
    String barcode,
  ) {
    ProductDialogs.showProductNotFoundDialog(context, barcode);
  }

  // === 結帳相關對話框 ===
  
  static Future<bool> showCheckoutConfirmDialog(
    BuildContext context,
    int totalAmount,
    int totalQuantity,
  ) {
    return CheckoutDialogs.showCheckoutConfirmDialog(
      context, 
      totalAmount, 
      totalQuantity,
    );
  }

  static void showCheckoutSuccessDialog(
    BuildContext context,
    Receipt receipt, {
    VoidCallback? onDismiss,
  }) {
    CheckoutDialogs.showCheckoutSuccessDialog(
      context, 
      receipt, 
      onDismiss: onDismiss,
    );
  }

  // === 系統相關對話框 ===
  
  static void showLoadingDialog(BuildContext context, String message) {
    SystemDialogs.showLoadingDialog(context, message);
  }

  static void closeLoadingDialog(BuildContext context) {
    SystemDialogs.closeLoadingDialog(context);
  }

  static void showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    SystemDialogs.showErrorDialog(context, title, message);
  }

  static void showComingSoonDialog(BuildContext context, String feature) {
    SystemDialogs.showComingSoonDialog(context, feature);
  }
}
