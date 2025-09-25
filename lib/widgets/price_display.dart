import 'package:flutter/material.dart';
import 'package:cheemeow_pos/utils/money_formatter.dart';
import '../config/app_theme.dart';

/// 價格顯示元件，使用鈔票圖示替代 NT$ 文字
class PriceDisplay extends StatelessWidget {
  final int amount;
  final double iconSize;
  final double fontSize;
  final Color? color; // 數字顏色（覆寫）
  final Color? symbolColor; // 符號顏色（覆寫）
  final FontWeight? fontWeight;
  final bool thousands; // 是否以千分位顯示數字

  const PriceDisplay({
    super.key,
    required this.amount,
    this.iconSize = 20.0,
    this.fontSize = 16.0,
    this.color,
  this.symbolColor,
    this.fontWeight,
    this.thousands = false,
  });

  @override
  Widget build(BuildContext context) {
  final numberColor = color ?? AppColors.priceNumber;
  final symColor = symbolColor ?? AppColors.priceSymbol;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '\$',
          style: TextStyle(
            fontSize: iconSize,
            color: symColor,
            fontWeight: fontWeight ?? FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4.0),
        Text(
          thousands ? MoneyFormatter.thousands(amount) : amount.toString(),
          style: TextStyle(
            fontSize: fontSize,
            color: numberColor,
            fontWeight: fontWeight ?? FontWeight.bold,
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
      iconSize: 30.0,
      fontSize: 26.0,
      thousands: true,
      color: AppColors.cartTotalNumber,
      fontWeight: FontWeight.bold,
    );
  }
}

/// 小型價格顯示元件（用於商品列表等）
class SmallPriceDisplay extends StatelessWidget {
  final int amount;

  const SmallPriceDisplay({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    return PriceDisplay(
      amount: amount,
      iconSize: 16.0,
      fontSize: 14.0,
    );
  }
}
