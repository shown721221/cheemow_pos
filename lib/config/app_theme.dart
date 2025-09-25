import 'package:flutter/material.dart';

/// 集中色彩。後續若需要新增，請：
/// 1. 先檢查是否已有語意相近常數。
/// 2. 避免加純視覺命名，例如 pink1，改用語意：discountBadge, preorderBadge。
/// 3. 未涵蓋的場景先在元件內沿用 Colors.xxx，等重複出現再抽出。
class AppColors {
  AppColors._();
  // 品牌 / 主色 (中性基底，可微調)
  static const primary = Color(0xFF2563EB); // blue-600
  static const primaryContainer = Color(0xFFDBEAFE); // blue-100

  // 商品狀態 / 類型
  static const preorder = Color(0xFF6D28D9); // 紫色 (預購)
  static const discount = Color(0xFFEA580C); // 橘色 (折扣)
  static const normalText = Color(0xFF374151); // gray-700
  static const stockPositive = Color(0xFF15803D); // green-700
  static const stockZero = Color(0xFFDD6B20); // orange-600

  // 警示 / 錯誤
  static const error = Color(0xFFDC2626);

  // 背景 / 區塊
  static const subtleBg = Color(0xFFF8FAFC);
  static const highlightBg = Color(0xFFFFF7ED); // 淡橘背景

  // 深色模式專用文字/背景
  static const darkScaffold = Color(0xFF000000);
  static const darkSurface = Color(0xFF121212);
  static const darkCard = Color(0xFF1E1E1E);
  static const onDarkPrimary = Colors.white; // 主要文字
  static const onDarkSecondary = Color(0xFFB3B3B3); // 次要文字

  // 通用語意 (供後續元件逐步遷移) —— 先集中避免散落：
  static const success = Color(0xFF059669); // green-600
  static const warning = Color(0xFFF59E0B); // amber-500
  static const info = Color(0xFF0EA5E9); // sky-500
  static const neutralBg = Color(0xFF1F1F1F); // 深色次級底 (比 card 更深或作分層)
  static const neutralBgAlt = Color(0xFF262626); // 替代底色 (list/hover)
  static const neutralBorder = Color(0xFF2F2F2F);
  static const neutralTextSecondary = Color(0xFF9CA3AF); // gray-400
  static const neutralTextFaint = Color(0xFF6B7280); // gray-500

  // 自訂：櫻花粉 (tab 選中用)
  static const sakuraPink = Color(0xFFFFB7C5);
}

/// 提供給 MaterialApp 使用的主題；如尚未需要可先不套用，或依需求在 main.dart 合併。
class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryContainer,
        error: AppColors.error,
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkScaffold,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        surface: AppColors.darkSurface,
        error: AppColors.error,
        brightness: Brightness.dark,
      ),
      cardColor: AppColors.darkCard,
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkCard,
        contentTextStyle: const TextStyle(color: AppColors.onDarkPrimary),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.onDarkPrimary,
        displayColor: AppColors.onDarkPrimary,
      ),
    );
  }
}
