import 'package:flutter/material.dart';
import '../config/app_messages.dart';
import '../models/product.dart';
import '../widgets/numeric_keypad.dart';
import '../widgets/price_display.dart';
import '../config/app_theme.dart';

/// 價格輸入對話框管理器
/// 負責處理特殊商品的價格輸入界面
class PriceInputDialogManager {
  /// 顯示自定義數字鍵盤輸入對話框
  static Future<int?> showCustomNumberInput(
    BuildContext context,
    Product product,
    int currentCartTotal,
  ) async {
    String currentPrice = '';

    return await showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 商品名稱（不含標籤）
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: product.isPreOrderProduct
                            ? AppColors.preorderMysterious
                            : product.isDiscountProduct
                                ? AppColors.wonderfulDay
                                : Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),

                    // 商品類型說明
                    if (product.isPreOrderProduct)
                      Text(
                        AppMessages.preorderInputNote,
                        style: const TextStyle(
                          color: AppColors.preorderMysterious,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      )
                    else if (product.isDiscountProduct)
                      Text(
                        AppMessages.discountInputNote,
                        style: const TextStyle(
                          color: AppColors.wonderfulDay,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    SizedBox(height: 12),

                    // 價格顯示區域
                    _buildPriceDisplay(
                      currentPrice,
                      isDiscount: product.isDiscountProduct,
                      isPreorder: product.isPreOrderProduct,
                    ),

                    SizedBox(height: 12),

                    NumericKeypad(
                      keys: const [
                        ['1', '2', '3'],
                        ['4', '5', '6'],
                        ['7', '8', '9'],
                        ['ESC', '0', '✅'],
                      ],
                      buttonHeight: 60,
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      onKeyTap: (k) {
                        if (k == 'ESC') {
                          setState(() => currentPrice = '');
                          return;
                        }
                        if (k == '✅') {
                          if (currentPrice.isEmpty) return;
                          final price = int.tryParse(currentPrice);
                          if (price == null || price <= 0) return;
                          if (product.isDiscountProduct) {
                            if (price > currentCartTotal) {
                              _showDiscountError(
                                context,
                                price,
                                currentCartTotal,
                              );
                              return;
                            }
                            Navigator.of(context).pop(-price);
                          } else {
                            Navigator.of(context).pop(price);
                          }
                          return;
                        }
                        // 數字輸入
                        setState(() => currentPrice += k);
                      },
                    ),
                  ],
                ),
              ),
              // 移除底部 actions，改由鍵盤上的確認鍵處理
            );
          },
        );
      },
    );
  }

  /// 構建價格顯示區域
  static Widget _buildPriceDisplay(
    String currentPrice, {
    required bool isDiscount,
    required bool isPreorder,
  }) {
    // 依商品類型覆寫數字顏色（符號顏色仍由 PriceDisplay 控制）
    Color? overrideNumberColor;
    if (isDiscount) {
      overrideNumberColor = AppColors.wonderfulDay;
    } else if (isPreorder) {
      overrideNumberColor = AppColors.preorderMysterious;
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Center(
        child: PriceDisplay(
          amount: int.tryParse(currentPrice.isEmpty ? '0' : currentPrice) ?? 0,
          iconSize: 24,
          fontSize: 24,
          color: overrideNumberColor, // 若為 null 則使用預設品牌色
        ),
      ),
    );
  }

  /// 顯示折扣錯誤訊息
  static void _showDiscountError(
    BuildContext context,
    int discountAmount,
    int currentTotal,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppMessages.discountExceed(discountAmount, currentTotal)),
        backgroundColor: Colors.orange[600],
      ),
    );
  }
}
