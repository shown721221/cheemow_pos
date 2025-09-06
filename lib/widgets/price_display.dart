import 'package:flutter/material.dart';

/// 價格顯示元件，使用鈔票圖示替代 NT$ 文字
class PriceDisplay extends StatelessWidget {
  final int amount;
  final double iconSize;
  final double fontSize;
  final Color? color;
  final FontWeight? fontWeight;

  const PriceDisplay({
    Key? key,
    required this.amount,
    this.iconSize = 20.0,
    this.fontSize = 16.0,
    this.color,
    this.fontWeight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.payments, // 鈔票/付款圖示
          size: iconSize,
          color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
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

  const LargePriceDisplay({Key? key, required this.amount}) : super(key: key);

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

  const SmallPriceDisplay({Key? key, required this.amount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PriceDisplay(amount: amount, iconSize: 16.0, fontSize: 14.0);
  }
}
