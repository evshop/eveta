import 'package:flutter/material.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/eveta_quantity_stepper.dart';
import 'package:eveta/utils/cart_service.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';

class EvetaCartItemTile extends StatelessWidget {
  const EvetaCartItemTile({
    super.key,
    required this.item,
    required this.lineTotal,
    required this.onProductTap,
    required this.onDecrement,
    required this.onIncrement,
    required this.onDeleteTap,
  });

  final CartItem item;
  final double lineTotal;
  final VoidCallback onProductTap;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceMd, vertical: EvetaShopDimens.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onProductTap,
              child: SizedBox(
                width: 72,
                height: 72,
                child: item.imageUrl.isNotEmpty
                    ? EvetaCachedImage(
                        imageUrl: item.imageUrl,
                        delivery: EvetaImageDelivery.card,
                        fit: BoxFit.cover,
                        memCacheWidth: 240,
                      )
                    : Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: EvetaShopDimens.spaceMd),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onProductTap,
                borderRadius: BorderRadius.circular(EvetaShopDimens.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Bs ${lineTotal.toStringAsFixed(0)}',
                        style: tt.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: onDeleteTap,
                icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant, size: 22),
              ),
              EvetaQuantityStepper(
                quantity: item.quantity,
                min: 1,
                max: item.stock > 0 ? item.stock : 999,
                onDecrement: onDecrement,
                onIncrement: onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
