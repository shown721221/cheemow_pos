import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/product.dart';
import '../widgets/price_display.dart';
import '../utils/product_sorter.dart';
import '../widgets/empty_state.dart';
import '../config/app_messages.dart';
import '../utils/product_style_utils.dart';

class ProductListWidget extends StatefulWidget {
  final List<Product> products;
  final Function(Product) onProductTap;
  final VoidCallback? onCheckoutCompleted; // 新增：結帳完成回調
  final bool shouldScrollToTop; // 新增：是否需要滾動到頂部
  final bool pinSpecial; // 是否強制預購/折扣永遠置頂
  final bool sortByStock; // 是否依庫存排序（預設開啟：在既有大類順序內 / 或純庫存）

  const ProductListWidget({
    super.key,
    required this.products,
    required this.onProductTap,
    this.onCheckoutCompleted,
    this.shouldScrollToTop = false,
    this.pinSpecial = true,
    this.sortByStock = true,
  });

  @override
  State<ProductListWidget> createState() => _ProductListWidgetState();
}

class _ProductListWidgetState extends State<ProductListWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 滾動到頂部的方法
  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void didUpdateWidget(ProductListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果標記為需要滾動到頂部，直接執行
    if (widget.shouldScrollToTop && !oldWidget.shouldScrollToTop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToTop();
      });
    }
  }

  // 根據商品類型取得商品名稱的顏色
  Color _getProductNameColor(Product product) {
    if (product.isPreOrderProduct) return AppColors.preorder;
    if (product.isDiscountProduct) return AppColors.discount;
    return AppColors.onDarkPrimary.withValues(alpha: .95);
  }

  // 根據商品類型取得卡片的邊框顏色
  Color? _getCardBorderColor(Product product) {
    if (product.isPreOrderProduct) {
      return AppColors.preorder.withValues(alpha: .35);
    }
    if (product.isDiscountProduct) {
      return AppColors.discount.withValues(alpha: .35);
    }
    return null;
  }

  // 根據庫存數量回傳對應的顏色（紅<0 / 黃=0 / 綠>0，類似紅綠燈）
  Color _getStockColor(int stock) {
    if (stock > 0) return AppColors.stockPositive;
    if (stock == 0) return AppColors.stockZero;
    return AppColors.error;
  }

  // 根據庫存數量回傳顯示文字
  String _getStockText(int stock) => AppMessages.stockLabel(stock);

  @override
  Widget build(BuildContext context) {
    // 使用集中排序工具，維持與首頁一致的「每日排序」規則
    final displayProducts = ProductSorter.sort(
      widget.products,
      recencyDominatesSpecial: true,
      forcePinSpecial: widget.pinSpecial,
      byStock: widget.sortByStock,
    );
    // 診斷列印已移除，避免噪音

    return Container(
      color: AppColors.darkScaffold,
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: displayProducts.isEmpty
                ? Center(
                    child: EmptyState(
                      icon: Icons.inventory_2,
                      title: AppMessages.productListEmptyTitle,
                      message: AppMessages.productListEmptyHint,
                      titleSize: 22,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController, // 添加滾動控制器
                    itemCount: displayProducts.length,
                    itemBuilder: (context, index) {
                      final product = displayProducts[index];
                      return Card(
                        color: AppColors.darkCard,
                        margin: EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: _getCardBorderColor(product) != null
                              ? BorderSide(
                                  color: _getCardBorderColor(product)!,
                                  width: 2,
                                )
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      ProductStyleUtils.formatProductNameForMainCard(
                                        product.name,
                                      ),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 18,
                                        color: _getProductNameColor(product),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      _getStockText(product.stock),
                                      style: TextStyle(
                                        color: _getStockColor(product.stock),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16),
                              PriceDisplay(
                                amount: product.price,
                                iconSize: 20,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.stockPositive,
                              ),
                            ],
                          ),
                          // 移除多餘的加入購物車圖示，整張卡片點擊即可加入
                          // trailing: Text('🛒', style: TextStyle(fontSize: 22, color: Colors.blue)),
                          onTap: () => widget.onProductTap(product),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
