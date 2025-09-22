import 'package:flutter/material.dart';
import '../config/app_messages.dart';

class PosTabBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onSalesTap;
  final VoidCallback onSearchTap;
  const PosTabBar({
    super.key,
    required this.currentIndex,
    required this.onSalesTap,
    required this.onSearchTap,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          _buildTab(
            context: context,
            selected: currentIndex == 0,
            icon: '🛒',
            label: AppMessages.salesTabLabel,
            onTap: onSalesTap,
          ),
          _buildTab(
            context: context,
            selected: currentIndex == 1,
            icon: '🔎',
            label: AppMessages.searchLabel,
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? Colors.blue[50] : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: selected ? Colors.blue : Colors.transparent,
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
                    color: selected ? Colors.blue : Colors.black54,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? Colors.blue : Colors.black54,
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
