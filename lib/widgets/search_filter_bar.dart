import 'package:flutter/material.dart';
import '../managers/search_filter_manager.dart';
import '../config/app_messages.dart';

/// 以固定佈局呈現搜尋篩選按鈕列（不含狀態，樣式與行為交由呼叫方提供）
class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({
    super.key,
    required this.buildFilterButton,
    this.buttonHeight = 70,
  });

  /// 由外部提供，負責建構單一按鈕（可含選取樣式與 onTap）
  final Widget Function(String label, {bool isSpecial}) buildFilterButton;

  /// 統一控制每個按鈕的高度
  final double buttonHeight;

  @override
  Widget build(BuildContext context) {
    // 角色第三列最後一格放入一個類型（娃娃），其餘類型排成一列
    final char = SearchFilterManager.characterGroup;
    final type = SearchFilterManager.typeGroup;

    return Column(
      children: [
        // 地區（互斥）
        _row([
          buildFilterButton('東京'),
          buildFilterButton('上海'),
          buildFilterButton('香港'),
        ]),
        const SizedBox(height: 4),
        // 角色（互斥）第一列
        _row([
          buildFilterButton(char[0]),
          buildFilterButton(char[1]),
          buildFilterButton(char[2]),
        ]),
        const SizedBox(height: 4),
        // 角色（互斥）第二列
        _row([
          buildFilterButton(char[3]),
          buildFilterButton(char[4]),
          buildFilterButton(char[5]),
        ]),
        const SizedBox(height: 4),
        // 角色（互斥）第三列 + 類型（娃娃）
        _row([
          buildFilterButton(char[6]),
          buildFilterButton(char[7]),
          buildFilterButton(type[0]), // 娃娃
        ]),
        const SizedBox(height: 4),
        // 類型（互斥）其餘
        _row([
          buildFilterButton(type[1]), // 站姿
          buildFilterButton(type[2]), // 坐姿
          buildFilterButton(type[3]), // 其他吊飾
        ]),
        const SizedBox(height: 4),
        // 其他功能
        _row([
          buildFilterButton(AppMessages.filterHasStock),
          buildFilterButton(AppMessages.reset, isSpecial: true),
          buildFilterButton(AppMessages.confirm, isSpecial: true),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> children) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(height: buttonHeight, child: children[0]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(height: buttonHeight, child: children[1]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(height: buttonHeight, child: children[2]),
        ),
      ],
    );
  }
}
