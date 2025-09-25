import 'package:flutter/material.dart';

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
          // 背景：指定 #7DB183 (柔和綠)
          backgroundColor: const Color(0xFF7DB183),
          foregroundColor: Colors.white,
        );
}
