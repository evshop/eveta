import 'package:flutter/material.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/premium/eveta_new_arrival_card.dart';

/// Carrusel horizontal con [EvetaNewArrivalCard] para la sección «Nuevas llegadas».
class HorizontalNewArrivalsList extends StatelessWidget {
  const HorizontalNewArrivalsList({
    super.key,
    required this.products,
    this.onProductTap,
    this.cardWidth = 168,
    this.maxItems = 12,
    this.showNewBadge = true,
  });

  final List<Map<String, dynamic>> products;
  final void Function(String productId)? onProductTap;
  final double cardWidth;
  final int maxItems;
  final bool showNewBadge;

  @override
  Widget build(BuildContext context) {
    final n = products.length.clamp(0, maxItems);
    if (n == 0) return const SizedBox.shrink();

    const gap = EvetaShopDimens.spaceMd;
    // Padding vertical del ListView (4+12) + alto de fila alineado a [EvetaNewArrivalCard.gridMainAxisExtent].
    final listHeight = EvetaNewArrivalCard.gridMainAxisExtent + 22;

    return SizedBox(
      height: listHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(EvetaShopDimens.spaceLg, 4, EvetaShopDimens.spaceLg, 12),
        itemCount: n,
        separatorBuilder: (_, __) => const SizedBox(width: gap),
        itemBuilder: (context, i) {
          final p = products[i];
          return EvetaNewArrivalCard(
            width: cardWidth,
            product: p,
            showNewBadge: showNewBadge,
            onTap: onProductTap != null ? () => onProductTap!(p['id'].toString()) : null,
          );
        },
      ),
    );
  }
}
