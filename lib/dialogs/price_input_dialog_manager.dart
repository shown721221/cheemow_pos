import 'package:flutter/material.dart';
import '../models/product.dart';

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
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    
                    // 商品類型說明
                    if (product.isPreOrderProduct)
                      Text(
                        '這是預購商品，請輸入實際價格',
                        style: TextStyle(color: Colors.purple[700], fontSize: 12),
                      )
                    else if (product.isDiscountProduct)
                      Text(
                        '這是折扣商品，輸入金額會自動轉為負數',
                        style: TextStyle(color: Colors.orange[700], fontSize: 12),
                      ),
                    SizedBox(height: 16),
                    
                    // 價格顯示區域
                    _buildPriceDisplay(currentPrice, product.isDiscountProduct),
                    
                    SizedBox(height: 16),
                    
                    // 數字鍵盤（透過回呼直接更新外層 currentPrice）
                    _buildNumberKeypad(
                      onAppend: (d) => setState(() => currentPrice += d),
                      onClear: () => setState(() => currentPrice = ''),
                      onDelete: () => setState(() {
                        if (currentPrice.isNotEmpty) {
                          currentPrice = currentPrice.substring(0, currentPrice.length - 1);
                        }
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('取消'),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
                ElevatedButton(
                  child: Text('確定'),
                  onPressed: currentPrice.isEmpty ? null : () {
                    final price = int.tryParse(currentPrice);
                    if (price != null && price > 0) {
                      // 驗證折扣商品
                      if (product.isDiscountProduct) {
                        if (price > currentCartTotal) {
                          _showDiscountError(context, price, currentCartTotal);
                          return;
                        }
                        Navigator.of(context).pop(-price);
                      } else {
                        Navigator.of(context).pop(price);
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 構建價格顯示區域
  static Widget _buildPriceDisplay(String currentPrice, bool isDiscount) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Text(
        'NT\$ ${currentPrice.isEmpty ? "0" : currentPrice}',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: isDiscount ? Colors.orange[700] : Colors.black,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 構建數字鍵盤
  static Widget _buildNumberKeypad({
    required void Function(String digit) onAppend,
    required VoidCallback onClear,
    required VoidCallback onDelete,
  }) {
    return Column(
      children: [
        // 第一排：1, 2, 3
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumKey('1', () => onAppend('1')),
            _buildNumKey('2', () => onAppend('2')),
            _buildNumKey('3', () => onAppend('3')),
          ],
        ),
        SizedBox(height: 8),
        // 第二排：4, 5, 6
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumKey('4', () => onAppend('4')),
            _buildNumKey('5', () => onAppend('5')),
            _buildNumKey('6', () => onAppend('6')),
          ],
        ),
        SizedBox(height: 8),
        // 第三排：7, 8, 9
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumKey('7', () => onAppend('7')),
            _buildNumKey('8', () => onAppend('8')),
            _buildNumKey('9', () => onAppend('9')),
          ],
        ),
        SizedBox(height: 8),
        // 第四排：清除, 0, 刪除
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionKey('清除', onClear),
            _buildNumKey('0', () => onAppend('0')),
            _buildActionKey('刪除', onDelete),
          ],
        ),
      ],
    );
  }

  /// 構建數字按鈕
  static Widget _buildNumKey(String number, VoidCallback onPressed) {
    return SizedBox(
      width: 60,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[50],
          foregroundColor: Colors.blue[700],
        ),
        child: Text(
          number,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// 構建功能按鈕
  static Widget _buildActionKey(String label, VoidCallback onPressed) {
    return SizedBox(
      width: 60,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[50],
          foregroundColor: Colors.orange[700],
        ),
        child: Text(label, style: TextStyle(fontSize: 12)),
      ),
    );
  }

  /// 顯示折扣錯誤訊息
  static void _showDiscountError(
    BuildContext context, 
    int discountAmount, 
    int currentTotal
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '折扣金額 ($discountAmount 元) 不能大於目前購物車總金額 ($currentTotal 元)'
        ),
        backgroundColor: Colors.orange[600],
      ),
    );
  }
}
