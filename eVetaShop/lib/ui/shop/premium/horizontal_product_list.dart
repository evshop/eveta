import 'package:flutter/material.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/eveta_product_card_compact.dart';

/// Lista horizontal de productos con cards compactas y padding consistente.
class HorizontalProductList extends StatelessWidget {
  const HorizontalProductList({
    super.key,
    required this.products,
    this.onProductTap,
    this.cardWidth = 152,
    this.height = 268,
    this.maxItems,
  });

  final List<Map<String, dynamic>> products;
  final void Function(String productId)? onProductTap;
  final double cardWidth;
  final double height;
  final int? maxItems;

  @override
  Widget build(BuildContext context) {
    final n = maxItems != null ? products.length.clamp(0, maxItems!) : products.length;
    if (n == 0) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceLg),
        itemCount: n,
        separatorBuilder: (_, __) => const SizedBox(width: EvetaShopDimens.spaceMd),
        itemBuilder: (context, i) {
          final p = products[i];
          return SizedBox(
            width: cardWidth,
            child: EvetaProductCardCompact(
              width: cardWidth,
              product: p,
              onTap: onProductTap != null ? () => onProductTap!(p['id'].toString()) : null,
            ),
          );
        },
      ),
    );
  }
}
