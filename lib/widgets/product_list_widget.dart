import 'package:flutter/material.dart';
import '../models/product.dart';
import '../widgets/price_display.dart';
import '../utils/product_sorter.dart';
import '../config/style_config.dart';
import '../config/app_messages.dart';

class ProductListWidget extends StatefulWidget {
  final List<Product> products;
  final Function(Product) onProductTap;
  final VoidCallback? onCheckoutCompleted; // 新增：結帳完成回調
  final bool shouldScrollToTop; // 新增：是否需要滾動到頂部
  final bool applyDailySort; // 是否套用每日排序（可關閉以保留外部順序）
  final bool pinSpecial; // 是否強制預購/折扣永遠置頂

  const ProductListWidget({
    super.key,
    required this.products,
    required this.onProductTap,
    this.onCheckoutCompleted,
    this.shouldScrollToTop = false,
    this.applyDailySort = true,
    this.pinSpecial = true,
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
    if (product.isPreOrderProduct) return StyleConfig.preorderColor;
    if (product.isDiscountProduct) return StyleConfig.discountColor;
    return StyleConfig.normalTextColor;
  }

  // 根據商品類型取得卡片的邊框顏色
  Color? _getCardBorderColor(Product product) {
    if (product.isPreOrderProduct) {
      return StyleConfig.preorderColor.withValues(alpha: .35);
    }
    if (product.isDiscountProduct) {
      return StyleConfig.discountColor.withValues(alpha: .35);
    }
    return null;
  }

  // 根據庫存數量回傳對應的顏色
  Color _getStockColor(int stock) {
    if (stock > 0) return Colors.green[700]!;
    if (stock == 0) return Colors.orange[700]!;
    return Colors.red[700]!;
  }

  // 根據庫存數量回傳顯示文字
  String _getStockText(int stock) => AppMessages.stockLabel(stock);

  @override
  Widget build(BuildContext context) {
    // 使用集中排序工具，維持與首頁一致的「每日排序」規則
    final displayProducts = widget.applyDailySort
        ? ProductSorter.sortDaily(
            widget.products,
            recencyDominatesSpecial: true,
            forcePinSpecial: widget.pinSpecial,
          )
        : widget.products;
    // 診斷列印已移除，避免噪音

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: displayProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          AppMessages.productListEmptyTitle,
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          AppMessages.productListEmptyHint,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController, // 添加滾動控制器
                    itemCount: displayProducts.length,
                    itemBuilder: (context, index) {
                      final product = displayProducts[index];
                      return Card(
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
                                      product.name,
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
                                color: Colors.green[700],
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
