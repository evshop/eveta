import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:eveta/screens/product_detail_screen.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/eveta_empty_state.dart';
import 'package:eveta/ui/shop/premium/eveta_new_arrival_card.dart';
import 'package:eveta/utils/favorites_service.dart';

class WishListScreen extends StatefulWidget {
  const WishListScreen({super.key, this.onProductTap});

  /// Si viene de [MyHomePage], abre el detalle como overlay y mantiene la barra inferior.
  final ValueChanged<String>? onProductTap;

  @override
  State<WishListScreen> createState() => _WishListScreenState();
}

class _WishListScreenState extends State<WishListScreen> {
  List<FavoriteItem> _items = [];
  bool _loading = true;

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
    });
  }

  @override
  void dispose() {
    FavoritesService.favoritesCountNotifier.removeListener(_onFavoritesChanged);
    super.dispose();
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
              : MasonryGridView.count(
                  padding: const EdgeInsets.fromLTRB(EvetaShopDimens.spaceLg, EvetaShopDimens.spaceSm, EvetaShopDimens.spaceLg, 100),
                  crossAxisCount: 2,
                  mainAxisSpacing: EvetaShopDimens.spaceMd,
                  crossAxisSpacing: EvetaShopDimens.spaceMd,
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final map = _favoriteToProductMap(item);
                    return LayoutBuilder(
                      builder: (context, c) {
                        return EvetaNewArrivalCard(
                          width: c.maxWidth,
                          product: map,
                          showNewBadge: false,
                          adaptProductImageFraming: true,
                          flexibleImageSlot: true,
                          onTap: () {
                            if (widget.onProductTap != null) {
                              widget.onProductTap!(item.productId);
                            } else {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(builder: (_) => ProductDetailScreen(productId: item.productId)),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
    );
  }
}
