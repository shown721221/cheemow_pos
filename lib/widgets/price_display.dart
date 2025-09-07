import 'package:flutter/material.dart';

/// 價格顯示元件，使用鈔票圖示替代 NT$ 文字
class PriceDisplay extends StatelessWidget {
  final int amount;
  final double iconSize;
  final double fontSize;
  final Color? color;
  final FontWeight? fontWeight;

  const PriceDisplay({
    super.key,
    required this.amount,
    this.iconSize = 20.0,
    this.fontSize = 16.0,
    this.color,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    // 新台幣1000元鈔票的藍綠色
    const Color ntd1000Color = Color(0xFF006B7A); // 深藍綠色，接近千元鈔票顏色

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.payments, // 鈔票/付款圖示
          size: iconSize,
          color: ntd1000Color, // 固定使用千元鈔票顏色
        ),
        SizedBox(width: 4.0),
        Text(
          amount.toString(),
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
