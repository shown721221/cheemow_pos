import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../models/receipt.dart';
import '../config/app_messages.dart';
import '../utils/money_formatter.dart';

/// 對話框管理器
/// 負責處理所有 POS 系統相關的對話框
class PosDialogManager {
  /// 顯示特殊商品價格輸入對話框
  static Future<int?> showPriceInputDialog(
    BuildContext context,
    Product product,
  ) async {
    final TextEditingController priceController = TextEditingController();
    int? finalPrice;

    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('輸入 ${product.name} 的價格'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product.isPreOrderProduct)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.schedule, color: Colors.purple, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '預約商品',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              if (product.isDiscountProduct)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.percent, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '特價商品',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '價格',
                  hintText: '請輸入價格',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                onChanged: (value) {
                  final price = int.tryParse(value);
                  finalPrice = price;
                },
                onSubmitted: (value) {
                  final price = int.tryParse(value);
                  if (price != null && price > 0) {
                    Navigator.of(context).pop(price);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (finalPrice != null && finalPrice! > 0) {
                  Navigator.of(context).pop(finalPrice);
                } else {
                  // 顯示錯誤提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(AppMessages.invalidPrice),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('確認'),
            ),
          ],
        );
      },
    );
  }

  /// 顯示結帳確認對話框
  static Future<bool> showCheckoutConfirmDialog(
    BuildContext context,
    int totalAmount,
    int totalQuantity,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('確認結帳'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('總數量: $totalQuantity 件'),
                  const SizedBox(height: 8),
                    Text(
                      '總金額: ${MoneyFormatter.symbol(totalAmount)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('確認結帳'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// 顯示結帳成功對話框
  static void showCheckoutSuccessDialog(
    BuildContext context,
    Receipt receipt, {
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('結帳完成'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('收據編號: ${receipt.id}'),
              const SizedBox(height: 8),
              Text('日期: ${receipt.formattedDateTime}'),
              const SizedBox(height: 8),
              Text('總數量: ${receipt.totalQuantity} 件'),
              const SizedBox(height: 8),
                Text(
                  '總金額: ${MoneyFormatter.symbol(receipt.totalAmount)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDismiss?.call();
              },
              child: const Text('確認'),
            ),
          ],
        );
      },
    );
  }

  /// 顯示錯誤對話框
  static void showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 28),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('確認'),
            ),
          ],
        );
      },
    );
  }

  /// 顯示商品未找到對話框
  static void showProductNotFoundDialog(BuildContext context, String barcode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.search_off, color: Colors.orange, size: 28),
              SizedBox(width: 8),
        Text(AppMessages.productNotFoundTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('條碼: $barcode'),
              const SizedBox(height: 8),
              const Text('找不到對應的商品，請檢查條碼是否正確。'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('確認'),
            ),
          ],
        );
      },
    );
  }

  /// 顯示載入中對話框
  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  /// 關閉載入對話框
  static void closeLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }
}
