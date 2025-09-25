import 'package:flutter/material.dart';

class StatMetricCard extends StatelessWidget {
  final String? icon; // emoji text
  final Widget? iconWidget; // custom widget (e.g., Image)
  final String? title;
  final String value;
  final Color background;
  final Color? valueColor;
  final bool largeValue;
  final TextStyle? titleStyleOverride;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  const StatMetricCard({
    super.key,
    this.icon,
    this.iconWidget,
    this.title,
    required this.value,
    required this.background,
    this.valueColor,
    this.largeValue = false,
    this.titleStyleOverride,
    this.iconSize = 22,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFB68600);
    final tsMetricValueLg = const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: gold,
    );
    final tsMetricValue = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: gold,
    );
    final valueText = Text(
      value,
      style: (largeValue ? tsMetricValueLg : tsMetricValue).copyWith(
        color: valueColor ?? gold,
      ),
      textAlign: TextAlign.center,
    );
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 24,
            child:
                iconWidget ??
                (icon != null
                    ? Text(icon!, style: TextStyle(fontSize: iconSize))
                    : const SizedBox.shrink()),
          ),
          if (title != null) ...[
            const SizedBox(height: 6),
            Text(
              title!,
              style:
                  titleStyleOverride ??
                  const TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
          ],
          valueText,
        ],
      ),
    );
  }
}
