import 'package:flutter/material.dart';
import '../models/product.dart';
import '../controllers/search_controller.dart' as pos_search;
import '../utils/app_logger.dart';
import 'product_list_widget.dart';
import '../screens/pos_search_page.dart';

/// POS 主畫面左側的商品/搜尋頁面區塊：
/// 1. 銷售頁 (商品列表) 時：根據搜尋/篩選判斷要顯示全部或搜尋結果，若結果為空回退全部並記錄日誌。
/// 2. 搜尋頁：顯示 `PosSearchPage`，確認後回到銷售頁。
class PosProductPanel extends StatelessWidget {
  final int pageIndex; // 0: 銷售, 1: 搜尋
  final List<Product> products; // 原始產品清單（保持同一引用）
  final pos_search.PosSearchController searchController;
  final bool manualOrderActive; // 若為 true 則不套每日排序
  final bool shouldScrollToTop; // 觸發列表回頂
  final ValueChanged<Product> onProductTap;
  final VoidCallback onSearchConfirmReturn; // 搜尋頁按下『返回』

  const PosProductPanel({
    super.key,
    required this.pageIndex,
    required this.products,
    required this.searchController,
    required this.manualOrderActive,
    required this.shouldScrollToTop,
    required this.onProductTap,
    required this.onSearchConfirmReturn,
  });

  @override
  Widget build(BuildContext context) {
    if (pageIndex == 1) {
      return PosSearchPage(
        searchController: searchController,
        onConfirmAndReturn: onSearchConfirmReturn,
      );
    }

    final inSearch =
        searchController.hasActiveFilters || searchController.hasQuery;
    final effectiveProducts = () {
      if (!inSearch) return products;
      if (searchController.results.isEmpty) {
        AppLogger.d('搜尋/篩選結果為空，回退顯示全部商品 (count=${products.length})');
        return products;
      }
      return searchController.results;
    }();

    return ProductListWidget(
      products: effectiveProducts,
      pinSpecial: true,
      onProductTap: onProductTap,
      shouldScrollToTop: shouldScrollToTop,
    );
  }
}
