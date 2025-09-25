import 'package:flutter/material.dart';
import 'package:cheemeow_pos/config/style_config.dart';

/// 共用匯出面板標頭：左側圖示(emoji) + 標題 + 右側日期
class ExportPanelHeader extends StatelessWidget {
  final String leadingEmoji;
  final String title;
  final String dateText;
  final TextStyle? titleStyle;
  final double emojiSize;
  const ExportPanelHeader({
    super.key,
    required this.leadingEmoji,
    required this.title,
    required this.dateText,
    this.titleStyle,
    this.emojiSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(leadingEmoji, style: TextStyle(fontSize: emojiSize)),
        const SizedBox(width: 8),
        Text(
          title,
          style: titleStyle ?? const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const Spacer(),
        Text(dateText, style: StyleConfig.revenueDateTextStyle),
      ],
    );
  }
}
