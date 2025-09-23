import 'package:flutter/material.dart';
import 'package:cheemeow_pos/config/style_config.dart';

/// 共用匯出面板外框：統一寬 / 高 / 陰影 / 漸層 / 圓角 / padding。
/// child 內容本身可再決定是否使用 Scroll / LayoutBuilder。
class ExportPanel extends StatelessWidget {
  final Widget child;
  final Key? repaintBoundaryKey;
  final bool constrainMinHeight; // 若 true 會以 ConstrainedBox 撐滿高度
  const ExportPanel({
    super.key,
    required this.child,
    this.repaintBoundaryKey,
    this.constrainMinHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final core = Container(
      width: StyleConfig.exportPanelWidth,
      height: StyleConfig.exportPanelHeight,
      padding: StyleConfig.exportPanelPadding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: constrainMinHeight
          ? LayoutBuilder(
              builder: (ctx, cons) => SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: cons.maxHeight),
                  child: child,
                ),
              ),
            )
          : child,
    );

    return RepaintBoundary(key: repaintBoundaryKey, child: core);
  }
}
