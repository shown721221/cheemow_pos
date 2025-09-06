import 'package:flutter/material.dart';
import '../models/product.dart';
import '../widgets/price_display.dart';

class ProductListWidget extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onProductTap;

  const ProductListWidget({
    Key? key,
    required this.products,
    required this.onProductTap,
  }) : super(key: key);

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
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '暫無商品資料',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '請匯入CSV檔案',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
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
                          onTap: () => onProductTap(product),
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
