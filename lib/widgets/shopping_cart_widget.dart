import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../widgets/price_display.dart';

class ShoppingCartWidget extends StatelessWidget {
  final List<CartItem> cartItems;
  final Function(int) onIncreaseQuantity;
  final Function(int) onDecreaseQuantity;
  final Function(int) onRemoveItem;
  final Function() onClearCart;
  final Function() onCheckout;

  const ShoppingCartWidget({
    Key? key,
    required this.cartItems,
    required this.onIncreaseQuantity,
    required this.onDecreaseQuantity,
    required this.onRemoveItem,
    required this.onClearCart,
    required this.onCheckout,
  }) : super(key: key);

  int get totalAmount {
    return cartItems.fold(0, (total, item) => total + item.subtotal);
  }

  int get totalQuantity {
    return cartItems.fold(0, (total, item) => total + item.quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (cartItems.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.delete_sweep, size: 24),
                  onPressed: onClearCart,
                  tooltip: '清空購物車',
                  color: Colors.grey[600],
                ),
            ],
          ),
          SizedBox(height: 8),

          // 購物車項目
          Expanded(
            child: cartItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 大一點的購物車圖示，配合愛心主題
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite,
                              size: 28,
                              color: Colors.red[400],
                            ),
                            SizedBox(width: 10),
                            Text(
                              '帶寶寶回家吧',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(
                              Icons.favorite,
                              size: 28,
                              color: Colors.red[400],
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: Key('${item.product.id}_$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(right: 16),
                            color: Colors.red,
                            child: Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            onRemoveItem(index);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已移除 ${item.product.name}'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // 商品資訊區域 - 使用 Expanded 佔用剩餘空間
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: item.product.isSpecialProduct
                                              ? (item.product.isPreOrderProduct
                                                    ? Colors.purple[700]
                                                    : Colors.orange[700])
                                              : null,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 6),
                                      SmallPriceDisplay(
                                        amount: item.product.price,
                                      ),
                                    ],
                                  ),
                                ),
                                // 數量控制區域 - 固定寬度
                                Container(
                                  width: 80,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          InkWell(
                                            onTap: () =>
                                                onDecreaseQuantity(index),
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.remove,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${item.quantity}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () =>
                                                onIncreaseQuantity(index),
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              child: Icon(Icons.add, size: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      // 使用簡單的 Text 來避免溢出問題
                                      Text(
                                        '小計: ${item.subtotal}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 底部統計和結帳
          if (cartItems.isNotEmpty) ...[
            Divider(thickness: 2),
            Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('商品數量:', style: TextStyle(fontSize: 16)),
                      Text(
                        '$totalQuantity 件',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '總金額:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      LargePriceDisplay(amount: totalAmount),
                    ],
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: onCheckout,
                      icon: Icon(Icons.payment),
                      label: Text('結帳', style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
