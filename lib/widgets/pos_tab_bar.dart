import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/ui_tokens.dart';

class PosTabBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onSalesTap;
  final VoidCallback onSearchTap;
  final String productIcon;
  final String searchIcon;
  final String productLabel;
  final String searchLabel;
  const PosTabBar({
    super.key,
    required this.currentIndex,
    required this.onSalesTap,
    required this.onSearchTap,
    this.productIcon = UiTokens.productTabEmoji,
    this.searchIcon = UiTokens.searchTabEmoji,
    this.productLabel = 'product',
    this.searchLabel = 'search',
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.darkScaffold, // 黑色背景
        border: Border(
          bottom: BorderSide(
            color: AppColors.neutralBorder.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          _buildTab(
            context: context,
            selected: currentIndex == 0,
            icon: productIcon, // 預設玩偶，可替換
            label: productLabel,
            onTap: onSalesTap,
          ),
          _buildTab(
            context: context,
            selected: currentIndex == 1,
            icon: searchIcon,
            label: searchLabel,
            onTap: onSearchTap,
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required BuildContext context,
    required bool selected,
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    const double iconTextGap = 8; // 圖示與文字間距
    const Color activeColor = AppColors.sakuraPink; // 櫻花粉
    final Color inactiveColor = AppColors.onDarkSecondary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: selected ? activeColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  icon,
                  style: TextStyle(
                    fontSize: 18,
                    color: selected ? activeColor : inactiveColor,
                  ),
                ),
                const SizedBox(width: iconTextGap),
                Text(
                  // 在文字前後不手動加空格，改用 SizedBox 控制距離
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
