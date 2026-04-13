import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eveta/common_widget/product_card_skeleton.dart';
import 'package:eveta/common_widget/promo_carousel_widget.dart';
import 'package:eveta/screens/add_location_screen.dart';
import 'package:eveta/screens/category_products_screen.dart';
import 'package:eveta/screens/search_screen.dart';
import 'package:eveta/screens/seller_store_screen.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/eveta_category_chip.dart';
import 'package:eveta/ui/shop/eveta_promo_banner.dart';
import 'package:eveta/ui/shop/eveta_search_bar.dart';
import 'package:eveta/ui/shop/eveta_section_header.dart';
import 'package:eveta/ui/shop/premium/brand_card.dart';
import 'package:eveta/ui/shop/premium/eveta_new_arrival_card.dart';
import 'package:eveta/ui/shop/premium/horizontal_new_arrivals_list.dart';
import 'package:eveta/ui/shop/sticky_category_header.dart';
import 'package:eveta/utils/catalog_cache_service.dart';
import 'package:eveta/utils/supabase_service.dart';
import 'package:eveta/ui/shop/product_map_ui.dart';

class _HomeData {
  const _HomeData({
    required this.products,
    required this.categories,
    required this.sellers,
  });

  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> sellers;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onProductTap,
    this.onOpenCart,
    this.onOpenWishlist,
  });

  final void Function(String productId)? onProductTap;
  final VoidCallback? onOpenCart;
  final VoidCallback? onOpenWishlist;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late Future<_HomeData> _homeFuture;
  final ScrollController _homeScrollController = ScrollController();
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeFuture = _load();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _homeScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _homeFuture = _load());
    }
  }

  Future<_HomeData> _load() async {
    final products = await CatalogCacheService.getProducts();
    final categories = await CatalogCacheService.getCategories();
    final sellers = await SupabaseService.getFeaturedSellers();
    return _HomeData(products: products, categories: categories, sellers: sellers);
  }

  void _showLocationSheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainerHighest,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(EvetaShopDimens.radiusXl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
                child: Icon(Icons.add_location_alt_rounded, color: scheme.primary),
              ),
              title: const Text('Agregar o cambiar ubicación', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AddLocationScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _topCategories(List<Map<String, dynamic>> all) {
    return all.where((c) {
      final pid = c['parent_id'];
      return pid == null || pid.toString().trim().isEmpty;
    }).toList();
  }

  String _resolveUserFirstName() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 'Usuario';
    final meta = user.userMetadata;
    final full = (meta?['full_name'] ?? meta?['name'])?.toString().trim();
    if (full != null && full.isNotEmpty) {
      return full.split(RegExp(r'\s+')).first;
    }
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Usuario';
  }

  void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
    );
  }

  /// Iconos del saludo compactos: fondo tonal circular (no píldora ovalada).
  ButtonStyle _homeHeaderCircleIconStyle() {
    return IconButton.styleFrom(
      shape: const CircleBorder(),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      minimumSize: const Size(44, 44),
      fixedSize: const Size(44, 44),
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildHomeStickyHeader(BuildContext context, double t) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final firstName = _resolveUserFirstName();
    final expandedOpacity = (1.0 - t).clamp(0.0, 1.0);
    final compactOpacity = t.clamp(0.0, 1.0);
    final searchPhase = Curves.easeInOutCubic.transform((t / 0.42).clamp(0.0, 1.0));
    final belowPt = (lerpDouble(236, 56, t) ?? (236 - 180 * t));

    return SizedBox(
      height: belowPt,
      width: double.infinity,
      child: ClipRect(
        clipBehavior: Clip.hardEdge,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: expandedOpacity,
                  child: IgnorePointer(
                    ignoring: t > 0.58,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      clipBehavior: Clip.hardEdge,
                      primary: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(EvetaShopDimens.spaceLg, 6, EvetaShopDimens.spaceLg, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Hola, $firstName',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '¿Qué compramos hoy?',
                                          style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    style: _homeHeaderCircleIconStyle(),
                                    onPressed: widget.onOpenWishlist,
                                    icon: const Icon(Icons.favorite_outline_rounded, size: 22),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton.filledTonal(
                                    style: _homeHeaderCircleIconStyle(),
                                    onPressed: widget.onOpenCart,
                                    icon: const Icon(Icons.shopping_bag_outlined, size: 22),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Opacity(
                                opacity: (1.0 - t * 1.25).clamp(0.0, 1.0),
                                child: InkWell(
                                  onTap: () => _showLocationSheet(context),
                                  borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.location_on_rounded, size: 18, color: scheme.primary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Entrega en La Paz, Bolivia',
                                            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface),
                                          ),
                                        ),
                                        Icon(Icons.keyboard_arrow_down_rounded, color: scheme.onSurfaceVariant),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: lerpDouble(10, 0, searchPhase)!),
                              SizedBox(
                                height: lerpDouble(58, 0, searchPhase)!,
                                child: ClipRect(
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    heightFactor: 1.0,
                                    child: Transform.translate(
                                      offset: Offset(0, -14 * searchPhase),
                                      child: Opacity(
                                        opacity: (1.0 - searchPhase).clamp(0.0, 1.0),
                                        child: Transform.scale(
                                          scale: lerpDouble(1.0, 0.82, searchPhase)!,
                                          alignment: Alignment.topCenter,
                                          child: EvetaSearchBar(
                                            onTap: () => _openSearch(context),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: compactOpacity,
                  child: IgnorePointer(
                    ignoring: t < 0.4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(EvetaShopDimens.spaceLg, 4, EvetaShopDimens.spaceSm, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Hola, $firstName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.35),
                            ),
                          ),
                          IconButton.filledTonal(
                            style: _homeHeaderCircleIconStyle(),
                            onPressed: () => _openSearch(context),
                            icon: const Icon(Icons.search_rounded, size: 22),
                          ),
                          IconButton.filledTonal(
                            style: _homeHeaderCircleIconStyle(),
                            onPressed: widget.onOpenWishlist,
                            icon: const Icon(Icons.favorite_outline_rounded, size: 22),
                          ),
                          IconButton.filledTonal(
                            style: _homeHeaderCircleIconStyle(),
                            onPressed: widget.onOpenCart,
                            icon: const Icon(Icons.shopping_bag_outlined, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: scheme.primary,
          onRefresh: () async {
            final f = _load();
            setState(() => _homeFuture = f);
            await CatalogCacheService.getProducts(forceRefresh: true);
            await f;
          },
          child: FutureBuilder<_HomeData>(
            future: _homeFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return CustomScrollView(
                  controller: _homeScrollController,
                  cacheExtent: 280,
                  physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: StickyCategoryHeader(
                        minHeight: 236,
                        maxHeight: 236,
                        backgroundColor: scheme.surface,
                        borderColor: scheme.outline.withValues(alpha: 0.25),
                        builder: (ctx, _) => _HeaderSkeleton(loading: true),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(EvetaShopDimens.spaceLg),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: EvetaShopDimens.spaceMd,
                          crossAxisSpacing: EvetaShopDimens.spaceMd,
                          childAspectRatio: 0.68,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, __) => const ProductCardSkeleton(),
                          childCount: 6,
                        ),
                      ),
                    ),
                  ],
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                    Icon(Icons.wifi_off_rounded, size: 48, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'No pudimos cargar el inicio',
                        style: tt.titleMedium,
                      ),
                    ),
                  ],
                );
              }

              final data = snapshot.data!;
              final products = data.products;
              final topCats = _topCategories(data.categories);
              final featured = products.where((p) => p['is_featured'] == true).toList();
              final popular = List<Map<String, dynamic>>.from(products)
                ..sort((a, b) => productRating(b).compareTo(productRating(a)));
              final recommended = featured.isNotEmpty ? featured : products;

              return CustomScrollView(
                controller: _homeScrollController,
                cacheExtent: 280,
                physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: StickyCategoryHeader(
                      minHeight: 56,
                      maxHeight: 236,
                      backgroundColor: scheme.surface,
                      borderColor: scheme.outline.withValues(alpha: 0.28),
                      builder: (ctx, progress) => _buildHomeStickyHeader(
                        ctx,
                        Curves.easeInOutCubic.transform(progress),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: EvetaPromoBannerShell(
                      child: const PromoCarouselWidget(),
                    ),
                  ),
                  if (topCats.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: EvetaSectionHeader(
                        title: 'Explorar',
                        subtitle: 'Categorías rápidas',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 48,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceLg),
                            itemCount: topCats.length,
                            itemBuilder: (context, i) {
                              final c = topCats[i];
                              final id = c['id']?.toString() ?? '';
                              final name = c['name']?.toString() ?? '';
                              return EvetaCategoryChip(
                                label: name,
                                selected: false,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => CategoryProductsScreen(
                                        categoryId: id,
                                        title: name,
                                        onProductTap: widget.onProductTap,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (products.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: EvetaSectionHeader(
                        title: 'Nuevas llegadas',
                        subtitle: 'Recién en la tienda',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: HorizontalNewArrivalsList(
                        products: products,
                        maxItems: 12,
                        onProductTap: widget.onProductTap,
                      ),
                    ),
                  ],
                  if (popular.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: EvetaSectionHeader(
                        title: 'Populares',
                        subtitle: 'Los más valorados',
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceLg),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: EvetaShopDimens.spaceMd,
                        crossAxisSpacing: EvetaShopDimens.spaceMd,
                        childCount: popular.length.clamp(0, 6),
                        itemBuilder: (context, i) {
                          final p = popular[i];
                          return LayoutBuilder(
                            builder: (context, c) {
                              return EvetaNewArrivalCard(
                                width: c.maxWidth,
                                product: p,
                                showNewBadge: false,
                                adaptProductImageFraming: true,
                                flexibleImageSlot: true,
                                onTap: widget.onProductTap != null
                                    ? () => widget.onProductTap!(p['id'].toString())
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  if (recommended.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: EvetaSectionHeader(
                        title: 'Recomendado para ti',
                        subtitle: 'Seleccionado para tu estilo',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: HorizontalNewArrivalsList(
                        products: recommended,
                        maxItems: 10,
                        showNewBadge: false,
                        onProductTap: widget.onProductTap,
                      ),
                    ),
                  ],
                  if (data.sellers.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: EvetaSectionHeader(
                        title: 'Marcas y tiendas',
                        subtitle: 'Vendedores destacados',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 108,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceLg),
                            itemCount: data.sellers.length,
                            itemBuilder: (context, i) {
                              final s = data.sellers[i];
                              final name = s['shop_name']?.toString() ?? '';
                              final logo = s['shop_logo_url']?.toString().trim() ?? '';
                              final avatar = s['avatar_url']?.toString().trim() ?? '';
                              final url = logo.isNotEmpty ? logo : avatar;
                              final sellerId = s['id']?.toString();
                              return BrandCard(
                                name: name,
                                imageUrl: url.isNotEmpty ? url : null,
                                width: 96,
                                cardHeight: 108,
                                onTap: () {
                                  if (sellerId == null || sellerId.isEmpty) return;
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => SellerStoreScreen(sellerId: sellerId),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton({this.loading = false});

  /// Si es true, shimmer acorde al tema (carga inicial dentro del header sticky).
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final base = dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerHighest;
    final hi = dark ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh;

    Widget blocks() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: 56,
                      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(6)),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 22,
                      width: 220,
                      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 44, height: 44, decoration: BoxDecoration(color: scheme.surfaceContainerHigh, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Container(width: 44, height: 44, decoration: BoxDecoration(color: scheme.surfaceContainerHigh, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 20,
            width: double.infinity,
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(height: 12),
          Container(
            height: 50,
            width: double.infinity,
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(26)),
          ),
        ],
      );
    }

    final inner = Padding(
      padding: const EdgeInsets.fromLTRB(EvetaShopDimens.spaceLg, 8, EvetaShopDimens.spaceLg, 12),
      child: loading
          ? Shimmer.fromColors(
              baseColor: base,
              highlightColor: hi,
              child: blocks(),
            )
          : blocks(),
    );

    return inner;
  }
}
