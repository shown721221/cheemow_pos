import 'package:flutter/material.dart';
import 'package:cheemeow_pos/utils/money_formatter.dart';

/// 價格顯示元件，使用鈔票圖示替代 NT$ 文字
class PriceDisplay extends StatelessWidget {
  final int amount;
  final double iconSize;
  final double fontSize;
  final Color? color;
  final FontWeight? fontWeight;
  final bool thousands; // 是否以千分位顯示數字

  const PriceDisplay({
    super.key,
    required this.amount,
    this.iconSize = 20.0,
    this.fontSize = 16.0,
    this.color,
    this.fontWeight,
  this.thousands = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
  Text('💵', style: TextStyle(fontSize: iconSize)),
  SizedBox(width: 6.0),
        Text(
          thousands ? MoneyFormatter.thousands(amount) : amount.toString(),
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }
}

/// 大型價格顯示元件（用於總金額等重要顯示）
class LargePriceDisplay extends StatelessWidget {
  final int amount;

  const LargePriceDisplay({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    return PriceDisplay(
      amount: amount,
      iconSize: 28.0,
  fontSize: 24.0,
      fontWeight: FontWeight.bold,
      color: Colors.green[700],
  thousands: true,
    );
  }
}

/// 小型價格顯示元件（用於商品列表等）
class SmallPriceDisplay extends StatelessWidget {
  final int amount;

  const SmallPriceDisplay({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    return PriceDisplay(amount: amount, iconSize: 16.0, fontSize: 14.0);
  }
}
