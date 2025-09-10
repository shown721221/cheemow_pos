import 'package:flutter/material.dart';
import '../utils/money_formatter.dart';
import '../models/receipt.dart';
import '../widgets/price_display.dart';
import '../config/app_messages.dart';

/// 結帳相關對話框
class CheckoutDialogs {
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
              title: const Row(
                children: [
                  Icon(Icons.payment, color: Colors.green),
                  SizedBox(width: 8),
                  Text(AppMessages.checkoutConfirmTitle),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        AppMessages.cartItemsCountLabel,
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '$totalQuantity 件',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        AppMessages.totalAmountLabel,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      LargePriceDisplay(amount: totalAmount),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text(AppMessages.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(AppMessages.checkoutConfirmTitle),
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
              Text(AppMessages.checkoutFinishedTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${AppMessages.receiptIdLabel}: ${receipt.id}'),
              const SizedBox(height: 8),
              Text('${AppMessages.dateLabel}: ${receipt.formattedDateTime}'),
              const SizedBox(height: 8),
              Text('總數量: ${receipt.totalQuantity} 件'),
              const SizedBox(height: 8),
              Text(
                '${AppMessages.totalAmountLabel}: ${MoneyFormatter.symbol(receipt.totalAmount)}',
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
              child: const Text(AppMessages.confirm),
            ),
          ],
        );
      },
    );
  }
}
