import 'package:flutter/material.dart';
import '../models/product.dart';
import '../widgets/price_display.dart';
import '../utils/product_style_utils.dart';
import '../config/font_config.dart';

/// 商品卡片組件
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final borderSide = ProductStyleUtils.getCardBorderSide(product);

    return Card(
      margin: margin ?? const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: borderSide ?? BorderSide.none,
      ),
      child: ListTile(
        contentPadding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Text(
              ProductStyleUtils.getProductEmoji(product),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontFamily: FontConfig.productFontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: ProductStyleUtils.getProductNameColor(product),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ProductStyleUtils.getStockText(product.stock),
                    style: TextStyle(
                      fontFamily: FontConfig.productFontFamily,
                      color: ProductStyleUtils.getStockColor(product.stock),
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            DefaultTextStyle.merge(
              style: const TextStyle(fontFamily: FontConfig.productFontFamily),
              child: PriceDisplay(
                amount: product.price,
                iconSize: 20,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// 商品網格卡片組件（用於網格顯示）
class ProductGridCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductGridCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderSide = ProductStyleUtils.getCardBorderSide(product);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderSide ?? BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    ProductStyleUtils.getProductEmoji(product),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const Spacer(),
                  Text(
                    ProductStyleUtils.getStockStatusEmoji(product.stock),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  product.name,
                  style: TextStyle(
                    fontFamily: FontConfig.productFontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: ProductStyleUtils.getProductNameColor(product),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ProductStyleUtils.getStockText(product.stock),
                style: TextStyle(
                  fontFamily: FontConfig.productFontFamily,
                  color: ProductStyleUtils.getStockColor(product.stock),
                  fontWeight: FontWeight.w400,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              DefaultTextStyle.merge(
                style: const TextStyle(
                  fontFamily: FontConfig.productFontFamily,
                ),
                child: PriceDisplay(
                  amount: product.price,
                  iconSize: 14,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
