import 'package:flutter/material.dart';
import '../models/product.dart';
import '../widgets/price_display.dart';

class ProductListWidget extends StatefulWidget {
  final List<Product> products;
  final Function(Product) onProductTap;
  final VoidCallback? onCheckoutCompleted; // 新增：結帳完成回調
  final bool shouldScrollToTop; // 新增：是否需要滾動到頂部

  const ProductListWidget({
    Key? key,
    required this.products,
    required this.onProductTap,
    this.onCheckoutCompleted,
    this.shouldScrollToTop = false,
  }) : super(key: key);

  @override
  _ProductListWidgetState createState() => _ProductListWidgetState();
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
    if (product.isPreOrderProduct) {
      return Colors.purple[700]!; // 預約商品：紫色
    } else if (product.isDiscountProduct) {
      return Colors.orange[700]!; // 折扣商品：橘色
    } else {
      return Colors.black87; // 一般商品：黑色
    }
  }

  // 根據商品類型取得卡片的邊框顏色
  Color? _getCardBorderColor(Product product) {
    if (product.isPreOrderProduct) {
      return Colors.purple[300]; // 預約商品：淺紫色邊框
    } else if (product.isDiscountProduct) {
      return Colors.orange[300]; // 折扣商品：淺橘色邊框
    }
    return null; // 一般商品：無特殊邊框
  }

  // 根據庫存數量回傳對應的顏色
  Color _getStockColor(int stock) {
    if (stock > 0) {
      return Colors.green[700]!; // 正數：綠色
    } else if (stock == 0) {
      return Colors.orange[700]!; // 零：橘色
    } else {
      return Colors.red[700]!; // 負數：紅色
    }
  }

  // 根據庫存數量回傳顯示文字
  String _getStockText(int stock) {
    if (stock > 0) {
      return '庫存: $stock';
    } else if (stock == 0) {
      return '庫存: $stock';
    } else {
      return '庫存: $stock'; // 負數也顯示實際數字
    }
  }

  @override
  Widget build(BuildContext context) {
    // 對產品進行排序：特殊商品在最前面，然後按結帳時間排序
    final sortedProducts = [...widget.products];
    sortedProducts.sort((a, b) {
      // 預約商品排第一
      if (a.isPreOrderProduct && !b.isPreOrderProduct) return -1;
      if (!a.isPreOrderProduct && b.isPreOrderProduct) return 1;

      // 折扣商品排第二
      if (a.isDiscountProduct && !b.isDiscountProduct) return -1;
      if (!a.isDiscountProduct && b.isDiscountProduct) return 1;

      // 兩個都是特殊商品時，預約商品優先
      if (a.isSpecialProduct && b.isSpecialProduct) {
        if (a.isPreOrderProduct && b.isDiscountProduct) return -1;
        if (a.isDiscountProduct && b.isPreOrderProduct) return 1;
        return 0;
      }

      // 兩個都是普通商品時，按最後結帳時間排序
      if (a.lastCheckoutTime != null && b.lastCheckoutTime != null) {
        return b.lastCheckoutTime!.compareTo(a.lastCheckoutTime!);
      } else if (a.lastCheckoutTime != null) {
        return -1; // 有結帳記錄的在前
      } else if (b.lastCheckoutTime != null) {
        return 1; // 有結帳記錄的在前
      }

      // 其他商品按名稱排序
      return a.name.compareTo(b.name);
    });

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: sortedProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('暫無商品資料', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 8),
                        Text(
                          '請匯入CSV檔案',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController, // 添加滾動控制器
                    itemCount: sortedProducts.length,
                    itemBuilder: (context, index) {
                      final product = sortedProducts[index];
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
                          trailing: Icon(
                            Icons.add_shopping_cart,
                            color: Colors.blue,
                            size: 24,
                          ),
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
