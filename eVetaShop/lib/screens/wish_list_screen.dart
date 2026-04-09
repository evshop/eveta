import 'package:flutter/material.dart';
import 'package:eveta/common_widget/eveta_blur_confirm_sheet.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/common_widget/eveta_swipe_reveal_delete.dart';
import 'package:eveta/screens/product_detail_screen.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/eveta_empty_state.dart';
import 'package:eveta/ui/shop/eveta_product_card_modern.dart';
import 'package:eveta/utils/cart_service.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';
import 'package:eveta/utils/favorites_service.dart';
class WishListScreen extends StatefulWidget {
  const WishListScreen({super.key});

  @override
  State<WishListScreen> createState() => _WishListScreenState();
}

class _WishListScreenState extends State<WishListScreen> {
  List<FavoriteItem> _items = [];
  bool _loading = true;
  String? _openSwipeProductId;

  @override
  void initState() {
    super.initState();
    FavoritesService.favoritesCountNotifier.addListener(_onFavoritesChanged);
    _load();
  }

  void _onFavoritesChanged() {
    _load();
  }

  Future<void> _load() async {
    final list = await FavoritesService.getFavorites();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
      if (_openSwipeProductId != null && !list.any((e) => e.productId == _openSwipeProductId)) {
        _openSwipeProductId = null;
      }
    });
  }

  @override
  void dispose() {
    FavoritesService.favoritesCountNotifier.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onSwipeOpened(String productId) {
    setState(() => _openSwipeProductId = productId);
  }

  void _onSwipeClosed(String productId) {
    if (_openSwipeProductId == productId) {
      setState(() => _openSwipeProductId = null);
    }
  }

  Future<void> _remove(FavoriteItem item) async {
    setState(() => _openSwipeProductId = null);
    await FavoritesService.removeFavorite(item.productId);
    await _load();
  }

  Future<void> _confirmRemoveFavorite(FavoriteItem item) async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showEvetaBlurConfirmSheet(
      context,
      title: '¿Quitar de favoritos?',
      preview: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
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
                  : ColoredBox(color: scheme.surfaceContainerHigh, child: Icon(Icons.image, color: scheme.onSurfaceVariant)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  _formatPrice(item.price),
                  style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      await _remove(item);
    } else {
      _onSwipeClosed(item.productId);
    }
  }

  String _formatPrice(String price) {
    final n = double.tryParse(price);
    if (n == null) return 'Bs $price';
    return 'Bs ${n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2)}';
  }

  Map<String, dynamic> _favoriteToProductMap(FavoriteItem item) {
    return {
      'id': item.productId,
      'name': item.name,
      'price': item.price,
      'original_price': item.originalPrice,
      'images': item.imageUrl.isNotEmpty ? [item.imageUrl] : [],
      'stock': item.stock,
      'rating': item.rating,
      'review_count': item.reviewCount,
      'is_featured': false,
    };
  }

  void _quickAddToCart(FavoriteItem item) {
    CartService.addToCart(CartItem(
      productId: item.productId,
      name: item.name,
      price: item.price,
      imageUrl: item.imageUrl,
      quantity: 1,
      stock: item.stock > 0 ? item.stock : 999,
    ));
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Agregado al carrito'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text('Favoritos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : _items.isEmpty
              ? EvetaEmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'Aún no tienes favoritos',
                  subtitle: 'Toca el corazón en un producto para guardarlo aquí',
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(EvetaShopDimens.spaceLg, EvetaShopDimens.spaceSm, EvetaShopDimens.spaceLg, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: EvetaShopDimens.spaceMd,
                    crossAxisSpacing: EvetaShopDimens.spaceMd,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final map = _favoriteToProductMap(item);
                    final w = MediaQuery.sizeOf(context).width;
                    final isOpen = _openSwipeProductId == item.productId;
                    return EvetaSwipeRevealDelete(
                      key: ValueKey(item.productId),
                      screenWidth: w,
                      isOpen: isOpen,
                      onOpen: () => _onSwipeOpened(item.productId),
                      onClose: () => _onSwipeClosed(item.productId),
                      onDelete: () => _confirmRemoveFavorite(item),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          EvetaProductCardModern(
                            product: map,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(builder: (_) => ProductDetailScreen(productId: item.productId)),
                              );
                            },
                          ),
                          Positioned(
                            right: 6,
                            bottom: 52,
                            child: Material(
                              color: scheme.secondaryContainer,
                              shape: const CircleBorder(),
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.shopping_bag_outlined, size: 20, color: scheme.primary),
                                onPressed: () => _quickAddToCart(item),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
