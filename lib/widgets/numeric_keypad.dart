import 'package:flutter/material.dart';

/// 通用數字鍵盤元件
/// 透過 keys 參數自訂佈局，例如：
///  - 付款對話框：[['1','2','3'],['4','5','6'],['7','8','9'],['ESC','0','⌫']]
///  - 價格/折扣輸入：[['1','2','3'],['4','5','6'],['7','8','9'],['ESC','0','✅']]
class NumericKeypad extends StatelessWidget {
  final List<List<String>> keys;
  final void Function(String key) onKeyTap;
  final double buttonHeight;
  final EdgeInsetsGeometry rowPadding;
  final double rowSpacing;
  final double buttonSpacing;
  final TextStyle? textStyle;
  final Color? outlinedBorderColor;

  const NumericKeypad({
    super.key,
    required this.keys,
    required this.onKeyTap,
    this.buttonHeight = 60,
    this.rowPadding = const EdgeInsets.only(bottom: 8),
    this.rowSpacing = 8,
    this.buttonSpacing = 4,
    this.textStyle,
    this.outlinedBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    final style = textStyle ??
        const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        );
    return Column(
      children: [
        for (int r = 0; r < keys.length; r++) ...[
          Padding(
            padding: r == keys.length - 1 ? EdgeInsets.zero : rowPadding,
            child: Row(
              children: [
                for (int c = 0; c < keys[r].length; c++) ...[
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: buttonSpacing),
                      child: SizedBox(
                        height: buttonHeight,
                        child: OutlinedButton(
                          onPressed: () => onKeyTap(keys[r][c]),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 0,
                            ),
                          ),
                          child: Text(keys[r][c], style: style),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
