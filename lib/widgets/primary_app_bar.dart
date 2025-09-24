import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// 可重用的主要 AppBar：集中標題置中與顏色策略，方便後續換成圖示 Logo。
class PrimaryAppBar extends AppBar {
  PrimaryAppBar({
    super.key,
    String? titleText,
    Widget? titleWidget,
    super.actions,
    super.bottom,
  }) : super(
         title: titleWidget ?? (titleText != null ? Text(titleText) : null),
         centerTitle: true,
         backgroundColor: AppColors.success,
         foregroundColor: Colors.white,
       );
}
