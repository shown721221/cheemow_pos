import 'package:flutter/material.dart';

/// 集中顏色 / 樣式，避免重複硬編。
class StyleConfig {
  static const preorderColor = Color(0xFF7E57C2); // 預購（紫）
  static const discountColor = Color(0xFFFB8C00); // 折扣（橘）
  static const normalTextColor = Color(0xFF37474F); // 一般字色（藍灰深）

  static TextStyle badgeText(Color c) =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c);

  static BoxDecoration tagBox(Color c) => BoxDecoration(
    color: c.withValues(alpha: .08),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: c.withValues(alpha: .5)),
  );
}
