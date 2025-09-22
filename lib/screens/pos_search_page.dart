import 'package:flutter/material.dart';
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
    return Column(
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
              fillColor: Colors.grey[50],
            ),
            onChanged: (q) => searchController.updateQuery(q),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SearchFilterBar(
              buildFilterButton: (label, {bool isSpecial = false}) =>
                  _buildFilterButton(context, label, isSpecial: isSpecial),
            ),
          ),
        ),
      ],
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
      if (label == '重選') {
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[700]!;
      } else {
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[700]!;
      }
    } else {
      backgroundColor = isSelected ? Colors.blue[100]! : Colors.grey[100]!;
      textColor = isSelected ? Colors.blue[700]! : Colors.grey[700]!;
    }

    return GestureDetector(
      onTap: () => _onFilterTap(label),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
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
