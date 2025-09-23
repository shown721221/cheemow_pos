import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../widgets/price_display.dart';
import '../config/app_messages.dart';
import '../config/app_theme.dart';
import 'empty_state.dart';
import '../config/ui_tokens.dart';

class ShoppingCartWidget extends StatelessWidget {
  final List<CartItem> cartItems;
  final Function(int) onRemoveItem;
  final Function() onClearCart;
  final Function() onCheckout;
  final List<CartItem>? lastCheckedOutCart; // 結帳後保留顯示
  final String? lastCheckoutPaymentMethod;
  final VoidCallback? onAnyInteraction; // 任何互動時通知外層清除預覽

  const ShoppingCartWidget({
    super.key,
    required this.cartItems,
    required this.onRemoveItem,
    required this.onClearCart,
    required this.onCheckout,
    this.lastCheckedOutCart,
    this.lastCheckoutPaymentMethod,
    this.onAnyInteraction,
  });

  int get totalAmount {
    return cartItems.fold(0, (total, item) => total + item.subtotal);
  }

  int get totalQuantity {
    // 結帳頁商品數量「不含特殊商品」（預約/折扣）
    return cartItems
        .where((item) => !item.product.isSpecialProduct)
        .fold(0, (total, item) => total + item.quantity);
  }

  @override
  Widget build(BuildContext context) {
    final bool showingPostCheckout =
        (lastCheckedOutCart != null && lastCheckedOutCart!.isNotEmpty);
    final displayItems = showingPostCheckout ? lastCheckedOutCart! : cartItems;
    final int postCheckoutTotal = showingPostCheckout
        ? lastCheckedOutCart!.fold(0, (sum, item) => sum + item.subtotal)
        : 0;

    return GestureDetector(
      // 任何點擊都視為互動
      onTap: () => onAnyInteraction?.call(),
      behavior: HitTestBehavior.translucent,
      child: Container(
        padding: EdgeInsets.all(16),
        color: AppColors.darkCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!showingPostCheckout && cartItems.isNotEmpty)
                  IconButton(
                    icon: Text(
                      '🗑️',
                      style: TextStyle(
                        fontSize: 22,
                        color: AppColors.onDarkSecondary,
                      ),
                    ),
                    onPressed: onClearCart,
                    tooltip: AppMessages.clearCartTooltip,
                    color: AppColors.onDarkSecondary,
                  ),
              ],
            ),
            SizedBox(height: 8),

            // 購物車項目
            if (showingPostCheckout) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  AppMessages.checkoutDone(
                    postCheckoutTotal,
                    lastCheckoutPaymentMethod ??
                        AppMessages.unknownPaymentMethod,
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            Expanded(
              child: displayItems.isEmpty
                  ? Center(
                      child: EmptyState(
                        emoji: UiTokens.cartEmptyEmoji,
                        title: AppMessages.cartEmptyTitle,
                        titleSize: 26,
                        titleColor:
                            AppColors.discount.withValues(alpha: 0.75),
                        message: null,
                      ),
                    )
                  : ListView.builder(
                      itemCount: displayItems.length,
                      itemBuilder: (context, index) {
                        final item = displayItems[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: Dismissible(
                            key: Key('${item.product.id}_$index'),
                            direction: showingPostCheckout
                                ? DismissDirection.none
                                : DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.only(right: 16),
                              color: AppColors.error,
                              child: Text(
                                '🗑️',
                                style: TextStyle(
                                  fontSize: 22,
                                  color: AppColors.onDarkPrimary,
                                ),
                              ),
                            ),
                            onDismissed: (direction) {
                              if (!showingPostCheckout) {
                                onRemoveItem(index);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppMessages.removedItem(
                                        item.product.name,
                                      ),
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
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
                                                ? (item
                                                          .product
                                                          .isPreOrderProduct
                                                      ? AppColors.preorder
                                                      : AppColors.discount)
                                                : AppColors.onDarkPrimary,
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
                                  SizedBox(
                                    width: 80,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          AppMessages.qtyLabel,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.onDarkSecondary,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          '${item.quantity}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        // 使用簡單的 Text 來避免溢出問題
                                        Text(
                                          '${AppMessages.subtotalLabel}: ${item.subtotal}',
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
            if (!showingPostCheckout && cartItems.isNotEmpty) ...[
              Divider(thickness: 2),
              Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppMessages.cartItemsCountLabel,
                          style: TextStyle(fontSize: 16),
                        ),
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
                          AppMessages.totalAmountLabel,
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
                        icon: Icon(Icons.shopping_bag_outlined, size: 22),
                        label: Text(
                          AppMessages.checkoutLabel,
                          style: TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.onDarkPrimary,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
