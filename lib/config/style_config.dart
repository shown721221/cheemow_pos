import 'package:flutter/material.dart';

/// 集中顏色 / 樣式，避免重複硬編。
class StyleConfig {
  static const preorderColor = Color(0xFF7E57C2); // 預購（紫）
  static const discountColor = Color(0xFFFB8C00); // 折扣（橘）
  static const normalTextColor = Color(0xFF37474F); // 一般字色（藍灰深）

  // 常用間距（集中調整）
  static const double gap8 = 8;
  static const double gap12 = 12;
  static const double gap16 = 16;

  // 主動作按鈕顏色
  static const Color primaryActionColor = Color(0xFF2E7D32); // 綠
  static const Color primaryOnColor = Colors.white;

  // 常用按鈕樣式（供 Dialog/支付對話框共用）
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    minimumSize: const Size.fromHeight(44),
    backgroundColor: primaryActionColor,
    foregroundColor: primaryOnColor,
  );

  static ButtonStyle payOptionSelectedStyle = FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(44),
    backgroundColor: primaryActionColor,
    foregroundColor: primaryOnColor,
  );

  static ButtonStyle payOptionUnselectedStyle = OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(44),
  );

  // 營收卡顏色主題（集中管理）
  static const revenueBgPreorder = Color(0xFFFFF0F6); // 粉
  static const revenueBgLinePay = Color(0xFFE8F5FF); // 淡藍
  static const revenueBgCash = Color(0xFFEFFFF2); // 淡綠
  static const revenueBgTransfer = Color(0xFFFFF9E6); // 淡黃

  // 營收卡日期樣式（可在此統一調整）
  static const TextStyle revenueDateTextStyle = TextStyle(
    fontSize: 18,
    color: Colors.black54,
  );

  static TextStyle badgeText(Color c) =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c);

  static BoxDecoration tagBox(Color c) => BoxDecoration(
    color: c.withValues(alpha: .08),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: c.withValues(alpha: .5)),
  );
}
