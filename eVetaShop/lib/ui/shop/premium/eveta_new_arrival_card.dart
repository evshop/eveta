import 'package:flutter/material.dart';
import 'package:eveta/common_widget/bottom_nav_bar_widget.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/product_map_ui.dart';
import 'package:eveta/utils/cart_animation_helper.dart';
import 'package:eveta/utils/cart_service.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';
import 'package:eveta/utils/favorites_service.dart';

/// Tarjeta horizontal para la sección «Nuevas llegadas»: imagen protagonista, badge Nuevo, precio claro.
class EvetaNewArrivalCard extends StatefulWidget {
  const EvetaNewArrivalCard({
    super.key,
    required this.product,
    this.width = 168,
    this.onTap,
    this.showNewBadge = true,
  });

  final Map<String, dynamic> product;
  final double width;
  final VoidCallback? onTap;
  /// En «Recomendado para ti» va en false para mismo layout sin chip «Nuevo».
  final bool showNewBadge;

  @override
  State<EvetaNewArrivalCard> createState() => _EvetaNewArrivalCardState();
}

class _EvetaNewArrivalCardState extends State<EvetaNewArrivalCard> {
  final GlobalKey _imageKey = GlobalKey();
  bool _favorite = false;
  bool _favLoaded = false;

  static const double _imgHeight = 132;
  static const double _radius = 20;

  @override
  void initState() {
    super.initState();
    _loadFav();
  }

  @override
  void didUpdateWidget(covariant EvetaNewArrivalCard oldWidget) {
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
    final isLight = scheme.brightness == Brightness.light;

    final borderColor = scheme.outline.withValues(alpha: isLight ? 0.14 : 0.38);
    final cardBg = scheme.surfaceContainerHighest;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(_radius),
        child: Ink(
          width: widget.width,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: borderColor),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.055),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  key: _imageKey,
                  height: _imgHeight,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                scheme.surfaceContainerHigh,
                                scheme.surfaceContainer.withValues(alpha: 0.92),
                              ],
                            ),
                          ),
                          child: url.isNotEmpty
                              ? EvetaCachedImage(
                                  imageUrl: url,
                                  delivery: EvetaImageDelivery.card,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 480,
                                )
                              : Center(
                                  child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant, size: 42),
                                ),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.02),
                                Colors.black.withValues(alpha: 0.12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (widget.showNewBadge || featured)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.showNewBadge)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: EvetaShopColors.brand,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: EvetaShopColors.brand.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.white),
                                      SizedBox(width: 5),
                                      Text(
                                        'Nuevo',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (widget.showNewBadge && featured) const SizedBox(width: 6),
                            if (featured)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'TOP',
                                  style: TextStyle(
                                    color: scheme.onPrimaryContainer,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (discount != null && discount > 0)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: scheme.error,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '-$discount%',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: isLight
                            ? Colors.white.withValues(alpha: 0.94)
                            : scheme.surfaceContainerHigh.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        elevation: isLight ? 1 : 0,
                        shadowColor: Colors.black26,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          onPressed: _favLoaded ? _toggleFavorite : null,
                          icon: Icon(
                            _favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 20,
                            color: _favorite ? EvetaShopColors.brand : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ColoredBox(
                color: cardBg,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.28,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatBs(price),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary,
                                    letterSpacing: -0.3,
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
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: stock > 0 ? () => _addToCart(context) : null,
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
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
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
