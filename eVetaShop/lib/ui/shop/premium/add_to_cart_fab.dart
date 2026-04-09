import 'package:flutter/material.dart';
import 'package:eveta/common_widget/bottom_nav_bar_widget.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/product_map_ui.dart';
import 'package:eveta/utils/cart_animation_helper.dart';
import 'package:eveta/utils/cart_service.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';

/// Botón circular “+” / agregar al carrito con animación al tab bar.
class AddToCartFab extends StatelessWidget {
  const AddToCartFab({
    super.key,
    required this.product,
    required this.flyFromKey,
    this.size = 40,
  });

  final Map<String, dynamic> product;
  final GlobalKey flyFromKey;
  final double size;

  void _add(BuildContext context) {
    final id = product['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final stock = productStock(product);
    if (stock <= 0) return;

    CartService.addToCart(CartItem(
      productId: id,
      name: product['name']?.toString() ?? '',
      price: product['price']?.toString() ?? '0',
      imageUrl: primaryProductImageUrl(product),
      quantity: 1,
      stock: stock,
    ));

    final scheme = Theme.of(context).colorScheme;
    final url = primaryProductImageUrl(product);
    final flyChild = SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
        child: url.isNotEmpty
            ? EvetaCachedImage(
                imageUrl: url,
                delivery: EvetaImageDelivery.thumb,
                fit: BoxFit.cover,
                memCacheWidth: 200,
              )
            : Icon(Icons.shopping_bag_outlined, color: scheme.primary),
      ),
    );

    CartAnimationHelper.runFlyToCartAnimation(
      context: context,
      sourceKey: flyFromKey,
      destKey: BottomNavBarWidget.cartKey,
      child: flyChild,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stock = productStock(product);
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
      child: InkWell(
        onTap: stock > 0 ? () => _add(context) : null,
        borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.add_rounded, size: 22, color: scheme.onPrimary),
        ),
      ),
    );
  }
}
