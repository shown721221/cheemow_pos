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

    return GestureDetector(
      onTap: () => _onFilterTap(label),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: .6)
                : AppColors.neutralBorder.withValues(alpha: .4),
            width: 1,
          ),
        ),
        child: Center(
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
        ),
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
