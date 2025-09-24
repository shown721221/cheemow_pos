import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../controllers/search_controller.dart' as pos_search;
import '../widgets/search_filter_bar.dart';
import '../config/app_messages.dart';

class PosSearchPage extends StatelessWidget {
  final pos_search.PosSearchController searchController;
  final VoidCallback onConfirmAndReturn;
  const PosSearchPage({
    super.key,
    required this.searchController,
    required this.onConfirmAndReturn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkScaffold,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: AppMessages.searchProductsHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: AppColors.darkCard,
              ),
              onChanged: (q) => searchController.updateQuery(q),
            ),
          ),
          Expanded(
            child: Container(
              color: AppColors.darkScaffold,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SearchFilterBar(
                buttonHeight: 80,
                buildFilterButton: (label, {bool isSpecial = false}) =>
                    _buildFilterButton(context, label, isSpecial: isSpecial),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context,
    String label, {
    bool isSpecial = false,
  }) {
    final isSelected = searchController.selectedFilters.contains(label);

    Color backgroundColor;
    Color textColor;

    if (isSpecial) {
      if (label == AppMessages.reset) {
        backgroundColor = AppColors.warning.withValues(alpha: .15);
        textColor = AppColors.warning;
      } else {
        backgroundColor = AppColors.success.withValues(alpha: .15);
        textColor = AppColors.success;
      }
    } else {
      backgroundColor = isSelected
          ? AppColors.primaryContainer.withValues(alpha: .18)
          : AppColors.darkCard;
      textColor = isSelected ? AppColors.primary : AppColors.onDarkSecondary;
    }

    // 原先左右小圖已改為背景圖，移除不再使用的建置函式。

    // 地區按鈕背景圖設定
    String? regionAsset;
    if (label == '東京') {
      regionAsset = 'assets/images/tokyo.png';
    } else if (label == '上海') {
      regionAsset = 'assets/images/shanghai.png';
    } else if (label == '香港') {
      regionAsset = 'assets/images/hongkong.png';
    }

    // 地區按鈕底色：未選取為淺粉 (rose-50)，選取時更深 (rose-200)
    final Color tileBgColor = regionAsset != null
        ? (isSelected ? const Color(0xFFFECDD3) : const Color(0xFFFFF1F2))
        : backgroundColor;

    final Widget content = (regionAsset != null)
        ? Stack(
            fit: StackFit.expand,
            children: [
              // 背景圖：置中顯示，使用 contain 避免裁切（選取時略為放大）
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: tileBgColor,
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: isSelected ? 0.95 : 0.9,
                      heightFactor: isSelected ? 0.95 : 0.9,
                      child: Image.asset(
                        regionAsset,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF43F5E), // rose-500
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          )
        : Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );

    return GestureDetector(
      onTap: () => _onFilterTap(label),
      child: Container(
        decoration: BoxDecoration(
          color: tileBgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: regionAsset != null && isSelected
                ? const Color(0xFFF43F5E) // rose-500 作為選取描邊
                : AppColors.neutralBorder.withValues(alpha: .4),
            width: regionAsset != null && isSelected ? 3 : 1,
          ),
          boxShadow: regionAsset != null && isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x66F43F5E), // 更明顯的粉色陰影
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: content,
      ),
    );
  }

  void _onFilterTap(String label) {
    if (label == AppMessages.reset) {
      searchController.clearFilters();
      searchController.clearQuery();
    } else if (label == AppMessages.confirm) {
      searchController.ensureResults();
      onConfirmAndReturn();
    } else {
      searchController.toggleFilter(label);
    }
  }
}
