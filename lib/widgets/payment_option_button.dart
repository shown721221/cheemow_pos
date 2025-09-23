import 'package:flutter/material.dart';
import '../config/style_config.dart';

/// 單一付款方式按鈕：可顯示文字或圖片 (保留語意 label)。
class PaymentOptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? imageAsset;
  final double imageHeight;
  const PaymentOptionButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.imageAsset,
    this.imageHeight = 20,
  });

  @override
  Widget build(BuildContext context) {
    final ButtonStyle selectedStyle = StyleConfig.payOptionSelectedStyle;
    final ButtonStyle unselectedStyle = StyleConfig.payOptionUnselectedStyle;
    final Widget content;
    if (imageAsset == null) {
      content = Text(label);
    } else {
      content = Semantics(
        label: label,
        child: ExcludeSemantics(
          child: Image.asset(
            imageAsset!,
            height: imageHeight,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => Text(label),
          ),
        ),
      );
    }
    final buttonChild = SizedBox(height: 44, child: Center(child: content));
    return selected
        ? FilledButton(
            onPressed: onTap,
            style: selectedStyle,
            child: buttonChild,
          )
        : OutlinedButton(
            onPressed: onTap,
            style: unselectedStyle,
            child: buttonChild,
          );
  }
}
