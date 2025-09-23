import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// 通用空狀態元件：集中 icon / 主要文字 / 次要文字 / 附加操作。
/// 使用情境：清單無資料、搜尋無結果、尚未選擇、無統計、錯誤回退等。
class EmptyState extends StatelessWidget {
  /// 可傳入 Icons.xxx / 自訂 Icon
  final IconData? icon;

  /// 也可選擇用 emoji （若提供會優先生效）
  final String? emoji;

  /// 主要標題（必填）
  final String title;

  /// 次要描述（可選）
  final String? message;

  /// 可選：放行動按鈕 / chips / 其他自訂 widget (垂直往下擺)
  final List<Widget>? children;

  /// 圖示大小，預設 72 (emoji) / 64 (icon)
  final double? iconSize;

  /// 主字體大小，預設 20~22 視情境
  final double? titleSize;
  /// 可選：標題顏色（若未指定依原本語意顏色）
  final Color? titleColor;

  const EmptyState({
    super.key,
    this.icon,
    this.emoji,
    required this.title,
    this.message,
    this.children,
    this.iconSize,
  this.titleSize,
  this.titleColor,
  }) : assert(icon != null || emoji != null, 'icon 與 emoji 至少提供一種');

  @override
  Widget build(BuildContext context) {
    final bool useEmoji = emoji != null;
    final double resolvedIconSize = iconSize ?? (useEmoji ? 72 : 64);
    final double resolvedTitleSize = titleSize ?? 22;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (useEmoji)
          Text(emoji!, style: TextStyle(fontSize: resolvedIconSize))
        else
          Icon(
            icon,
            size: resolvedIconSize,
            color: AppColors.neutralTextFaint.withValues(alpha: 0.35),
          ),
        SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: resolvedTitleSize,
            fontWeight: FontWeight.w600,
            color: titleColor ?? AppColors.onDarkPrimary,
          ),
        ),
        if (message != null) ...[
          SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 320),
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.onDarkSecondary,
              ),
            ),
          ),
        ],
        if (children != null && children!.isNotEmpty) ...[
          SizedBox(height: 16),
          ...children!,
        ],
      ],
    );
  }
}
