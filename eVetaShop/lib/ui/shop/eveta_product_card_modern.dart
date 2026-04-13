import 'package:flutter/material.dart';
import 'package:eveta/common_widget/bottom_nav_bar_widget.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/product_map_ui.dart';
import 'package:eveta/utils/cart_animation_helper.dart';
import 'package:eveta/utils/cart_service.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';
import 'package:eveta/utils/favorites_service.dart';

/// Tarjeta de producto para grillas (inicio, favoritos).
class EvetaProductCardModern extends StatefulWidget {
  const EvetaProductCardModern({
    super.key,
    required this.product,
    this.onTap,
    this.compact = false,
  });

  final Map<String, dynamic> product;
  final VoidCallback? onTap;
  final bool compact;

  @override
  State<EvetaProductCardModern> createState() => _EvetaProductCardModernState();
}

class _EvetaProductCardModernState extends State<EvetaProductCardModern> {
  final GlobalKey _imageKey = GlobalKey();
  bool _favorite = false;
  bool _favLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadFav();
  }

  @override
  void didUpdateWidget(covariant EvetaProductCardModern oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product['id']?.toString() != widget.product['id']?.toString()) {
      _loadFav();
    }
  }

  Future<void> _loadFav() async {
    final id = widget.product['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final v = await FavoritesService.isFavorite(id);
    if (mounted) {
      setState(() {
        _favorite = v;
        _favLoaded = true;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final item = FavoriteItem.fromProductMap(widget.product);
    final now = await FavoritesService.toggleFavorite(item);
    if (mounted) setState(() => _favorite = now);
  }

  void _addToCart(BuildContext context) {
    final id = widget.product['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final name = widget.product['name']?.toString() ?? '';
    final price = widget.product['price']?.toString() ?? '0';
    final url = primaryProductImageUrl(widget.product);
    final stock = productStock(widget.product);

    CartService.addToCart(CartItem(
      productId: id,
      name: name,
      price: price,
      imageUrl: url,
      quantity: 1,
      stock: stock,
    ));

    final flyChild = SizedBox(
      width: 52,
      height: 52,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
        child: url.isNotEmpty
            ? EvetaCachedImage(
                imageUrl: url,
                delivery: EvetaImageDelivery.thumb,
                fit: BoxFit.cover,
                memCacheWidth: 200,
              )
            : Icon(Icons.shopping_cart_outlined, color: Theme.of(context).colorScheme.primary),
      ),
    );

    CartAnimationHelper.runFlyToCartAnimation(
      context: context,
      sourceKey: _imageKey,
      destKey: BottomNavBarWidget.cartKey,
      child: flyChild,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = widget.product['name']?.toString() ?? 'Producto';
    final price = widget.product['price']?.toString();
    final original = widget.product['original_price']?.toString();
    final discount = computeDiscountPercent(price, original);
    final url = primaryProductImageUrl(widget.product);
    final featured = widget.product['is_featured'] == true;
    final stock = productStock(widget.product);
    final imgHeight = widget.compact ? 104.0 : 138.0;

    final isLight = scheme.brightness == Brightness.light;
    final r = EvetaShopDimens.radiusLg;
    final rr = BorderRadius.circular(r);
    final borderColor = scheme.outline.withValues(alpha: isLight ? 0.2 : 0.32);

    return Material(
      color: scheme.surfaceBright,
      elevation: isLight ? 1.5 : 4,
      shadowColor: Colors.black.withValues(alpha: isLight ? 0.06 : 0.32),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: rr,
        side: BorderSide(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: rr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: _imageKey,
                height: imgHeight,
                width: double.infinity,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        border: Border(
                          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.85)),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: url.isNotEmpty
                            ? EvetaCachedImage(
                                imageUrl: url,
                                delivery: EvetaImageDelivery.card,
                                fit: BoxFit.contain,
                                memCacheWidth: 400,
                              )
                            : Center(
                                child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant, size: 40),
                              ),
                      ),
                    ),
                      if (featured)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(EvetaShopDimens.radiusSm),
                            ),
                            child: Text(
                              'TOP',
                              style: TextStyle(color: scheme.onPrimary, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      if (discount != null && discount > 0)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: scheme.error.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(EvetaShopDimens.radiusSm),
                            ),
                            child: Text(
                              '-$discount%',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Material(
                          color: scheme.surfaceBright.withValues(alpha: 0.96),
                          shape: const CircleBorder(),
                          shadowColor: Colors.black26,
                          elevation: 0.5,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                            onPressed: _favLoaded ? _toggleFavorite : null,
                            icon: Icon(
                              _favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 19,
                              color: _favorite ? scheme.primary : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(
                          fontSize: widget.compact ? 13 : 14,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatBs(price),
                                  style: TextStyle(
                                    fontSize: widget.compact ? 14 : 16,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary,
                                  ),
                                ),
                                if (original != null &&
                                    original.isNotEmpty &&
                                    discount != null &&
                                    discount > 0)
                                  Text(
                                    formatBs(original),
                                    style: TextStyle(
                                      fontSize: 11,
                                      decoration: TextDecoration.lineThrough,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Material(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: stock > 0 ? () => _addToCart(context) : null,
                              borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 20,
                                  color: scheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
