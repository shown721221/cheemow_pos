import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../config/app_messages.dart';

/// 商品相關對話框
class ProductDialogs {
  /// 顯示特殊商品價格輸入對話框
  static Future<int?> showPriceInputDialog(
    BuildContext context,
    Product product,
  ) async {
    final TextEditingController priceController = TextEditingController();

    return showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
                decoration: InputDecoration(
                  labelText: '價格',
                  hintText: product.isPreOrderProduct
                      ? '輸入預購價格'
                      : product.isDiscountProduct
                      ? '輸入奇妙數字'
                      : '請輸入價格',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    int price = int.parse(value);
                    // 對於折扣商品，將輸入的數字轉為負數
                    if (product.isDiscountProduct) {
                      price = -price;
                    }
                    Navigator.of(context).pop(price);
                  }
                },
                autofocus: true,
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
                final text = priceController.text;
                if (text.isNotEmpty) {
                  try {
                    int price = int.parse(text);
                    // 對於折扣商品，將輸入的數字轉為負數
                    if (product.isDiscountProduct) {
                      price = -price;
                    }
                    Navigator.of(context).pop(price);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(AppMessages.invalidNumber),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(AppMessages.enterPrice),
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

  /// 顯示商品未找到對話框
  static void showProductNotFoundDialog(BuildContext context, String barcode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('商品未找到'),
          content: Text('條碼: $barcode\n\n此商品尚未在系統中註冊。'),
          actions: [
            TextButton(
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
}
