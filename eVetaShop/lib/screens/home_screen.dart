import 'dart:async';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eveta/common_widget/product_card_skeleton.dart';
import 'package:eveta/common_widget/promo_carousel_widget.dart';
import 'package:eveta/screens/location_onboarding_screen.dart';
import 'package:eveta/screens/events_screen.dart';
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
import 'package:eveta/utils/delivery_location_prefs.dart';
import 'package:eveta/utils/feature_flags.dart';
import 'package:eveta/utils/catalog_cache_service.dart';
import 'package:eveta/utils/supabase_service.dart';
import 'package:eveta/ui/shop/product_map_ui.dart';
import 'package:eveta/screens/wallet_screen.dart';
import 'package:eveta/utils/wallet_service.dart';

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
    this.onOpenSearch,
  });

  final void Function(String productId)? onProductTap;
  final VoidCallback? onOpenCart;
  final VoidCallback? onOpenWishlist;
  /// Si no es null (p. ej. [MyHomePage]), el buscador se muestra encima sin ocultar la barra inferior.
  final VoidCallback? onOpenSearch;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late Future<_HomeData> _homeFuture;
  final ScrollController _homeScrollController = ScrollController();
  StreamSubscription<AuthState>? _authSub;
  String _locationLine = 'Entrega en La Paz, Bolivia';
  double _headerT = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeFuture = _load();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
    _refreshLocationLine();
    _homeScrollController.addListener(_onScroll);
  }

  Future<void> _refreshLocationLine() async {
    final loc = await DeliveryLocationPrefs.load();
    if (!mounted) return;
    setState(() {
      if (loc.lat != null && loc.lng != null && loc.displayLabel.trim().isNotEmpty) {
        _locationLine = loc.displayLabel.trim();
      } else {
        _locationLine = 'Elige tu destino';
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _homeScrollController.removeListener(_onScroll);
    _homeScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    // Header se anima de ~236px -> ~56px (sin contar statusTop).
    const maxH = 236.0;
    const minH = 56.0;
    final t = (_homeScrollController.offset / (maxH - minH)).clamp(0.0, 1.0);
    if ((t - _headerT).abs() > 0.01) {
      setState(() => _headerT = t);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _homeFuture = _load();
      });
      _refreshLocationLine();
    }
  }

  Future<_HomeData> _load() async {
    final products = await CatalogCacheService.getProducts();
    // Las categorías cambian desde el panel admin; refresh más frecuente.
    final categories = await CatalogCacheService.getCategories(forceRefresh: true);
    final sellers = await SupabaseService.getFeaturedSellers();
    return _HomeData(products: products, categories: categories, sellers: sellers);
  }

  Future<void> _showLocationSheet(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final saved = await DeliveryLocationPrefs.loadSaved();
    if (!context.mounted) return;

    if (saved.isEmpty) {
      await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const LocationOnboardingScreen()));
      await _refreshLocationLine();
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainerHighest,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(EvetaShopDimens.radiusXl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tus ubicaciones', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                SizedBox(
                  height: (MediaQuery.sizeOf(ctx).height * 0.36).clamp(160.0, 340.0),
                  child: ListView.separated(
                    itemCount: saved.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final loc = saved[i];
                      return Material(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
                        child: ListTile(
                          leading: Icon(Icons.place_outlined, color: scheme.onSurface),
                          title: Text(loc.displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await DeliveryLocationPrefs.selectSaved(loc.id);
                            await _refreshLocationLine();
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const LocationOnboardingScreen()));
                    await _refreshLocationLine();
                  },
                  icon: const Icon(Icons.add_location_alt_outlined, size: 20),
                  label: const Text('Agregar nueva ubicación'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _topCategories(List<Map<String, dynamic>> all) {
    return all.where((c) {
      final pid = c['parent_id'];
      return pid == null || pid.toString().trim().isEmpty;
    }).toList();
  }

  static String? _parentCategoryId(Map<String, dynamic> c) {
    final v = c['parent_id'];
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  /// Categorías raíz con al menos un producto (propia o en alguna subcategoría).
  List<Map<String, dynamic>> _topCategoriesWithStock(
    List<Map<String, dynamic>> allCategories,
    List<Map<String, dynamic>> products,
  ) {
    final counts = <String, int>{};
    for (final p in products) {
      final id = p['category_id']?.toString();
      if (id == null || id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    bool hasUnder(String topId) {
      if ((counts[topId] ?? 0) > 0) return true;
      for (final c in allCategories) {
        if (_parentCategoryId(c) == topId && (counts[c['id'].toString()] ?? 0) > 0) {
          return true;
        }
      }
      return false;
    }
    return _topCategories(allCategories).where((c) => hasUnder(c['id'].toString())).toList();
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
    if (widget.onOpenSearch != null) {
      widget.onOpenSearch!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
    );
  }

  /// Iconos del saludo compactos: fondo tonal circular (no píldora ovalada).
  Widget _buildHomeStickyHeader(BuildContext context, double t) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final statusTop = MediaQuery.paddingOf(context).top;
    final firstName = _resolveUserFirstName();
    final expandedOpacity = (1.0 - t).clamp(0.0, 1.0);
    final compactOpacity = t.clamp(0.0, 1.0);
    final searchPhase = Curves.easeInOutCubic.transform((t / 0.42).clamp(0.0, 1.0));
    final belowPt =
        (lerpDouble(236, 56, t) ?? (236 - 180 * t)) + statusTop;

    return SizedBox(
      height: belowPt,
      width: double.infinity,
      child: ClipRect(
        clipBehavior: Clip.hardEdge,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: [
            if (t < 0.05)
              Positioned.fill(child: ColoredBox(color: scheme.surface)),
            if (t >= 0.05)
              Positioned.fill(
                child: Builder(
                  builder: (context) {
                    // Misma intensidad que la barra de detalle de producto (sigma 16 + velo).
                    final isDarkBar = Theme.of(context).brightness == Brightness.dark;
                    const sigma = 16.0;
                    final baseA = isDarkBar ? 0.42 : 0.55;
                    final scrim = isDarkBar ? Colors.black : Colors.white;
                    return BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              scrim.withValues(alpha: baseA),
                              scrim.withValues(alpha: baseA * 0.88),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
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
                        padding: EdgeInsets.fromLTRB(
                          EvetaShopDimens.spaceLg,
                          6 + statusTop,
                          EvetaShopDimens.spaceLg,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Transform.translate(
                                      offset: Offset(0, lerpDouble(0, -10, t.clamp(0.0, 1.0))!),
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
                                  ),
                                  Transform.translate(
                                    offset: Offset(lerpDouble(0, 10, t.clamp(0.0, 1.0))!, 0),
                                    child: _BalancePill(
                                      onTap: () {
                                        Navigator.push<void>(
                                          context,
                                          MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
                                        );
                                      },
                                    ),
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
                                        Icon(
                                          Icons.location_on_rounded,
                                          size: 18,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _locationLine,
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
                              _MorphingSearchBar(
                                t: searchPhase,
                                onTap: () => _openSearch(context),
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
                      padding: EdgeInsets.fromLTRB(
                        EvetaShopDimens.spaceLg,
                        4 + statusTop,
                        EvetaShopDimens.spaceSm,
                        6,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Transform.translate(
                              offset: Offset(0, lerpDouble(10, 0, (t - 0.35).clamp(0.0, 1.0))!),
                              child: Text(
                                'Hola, $firstName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.35),
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: lerpDouble(0.95, 1.0, (t - 0.35).clamp(0.0, 1.0))!,
                            child: _BalancePill(
                              compact: true,
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
                                );
                              },
                            ),
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
          top: false,
          bottom: false,
          child: Stack(
            children: [
              RefreshIndicator(
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
                final statusTop = MediaQuery.paddingOf(context).top;
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return CustomScrollView(
                  controller: _homeScrollController,
                  cacheExtent: 280,
                  physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: StickyCategoryHeader(
                        minHeight: 236 + statusTop,
                        maxHeight: 236 + statusTop,
                        backgroundColor: scheme.surface,
                        borderColor: scheme.outline.withValues(alpha: 0.25),
                        builder: (ctx, _) => _HeaderSkeleton(loading: true),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          EvetaShopDimens.spaceLg,
                          EvetaShopDimens.spaceMd,
                          EvetaShopDimens.spaceLg,
                          0,
                        ),
                        child: Shimmer.fromColors(
                          baseColor: Theme.of(context).brightness == Brightness.dark
                              ? scheme.surfaceContainerHighest
                              : Colors.grey[300]!,
                          highlightColor: Theme.of(context).brightness == Brightness.dark
                              ? scheme.surfaceBright
                              : Colors.grey[100]!,
                          child: Container(
                            height: 152,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(EvetaShopDimens.radiusXl),
                            ),
                          ),
                        ),
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
                    padding: EdgeInsets.only(top: statusTop),
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
                final topCats = _topCategoriesWithStock(data.categories, products);
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
                      minHeight: 56 + statusTop,
                      maxHeight: 236 + statusTop,
                      backgroundColor: Colors.transparent,
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
                  if (FeatureFlags.eventsModuleEnabled)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          EvetaShopDimens.spaceLg,
                          EvetaShopDimens.spaceMd,
                          EvetaShopDimens.spaceLg,
                          0,
                        ),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: scheme.primary.withValues(alpha: 0.14),
                              child: Icon(Icons.confirmation_number_outlined, color: scheme.primary),
                            ),
                            title: const Text(
                              'Eventos',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text('Entradas digitales con QR disponibles'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(builder: (_) => const EventsScreen()),
                              );
                            },
                          ),
                        ),
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
              // Cuando el header ya está compacto, mantenemos el botón de búsqueda por encima,
              // pero más abajo (no encima del saldo).
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                right: 16,
                top: MediaQuery.paddingOf(context).top + lerpDouble(140, 90, _headerT.clamp(0.0, 1.0))!,
                child: IgnorePointer(
                  ignoring: _headerT < 0.66,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    opacity: _headerT < 0.66 ? 0.0 : 1.0,
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
                      elevation: 10,
                      shadowColor: Colors.black.withValues(alpha: 0.22),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _openSearch(context),
                        child: const SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(Icons.search_rounded),
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
}

class _BalancePill extends StatelessWidget {
  const _BalancePill({required this.onTap, this.compact = false});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return FutureBuilder<double>(
      future: WalletService.getBalance(),
      builder: (context, snap) {
        final bal = snap.data ?? 0;
        return Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 8 : 10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Bs ${bal.toStringAsFixed(2)}',
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MorphingSearchBar extends StatelessWidget {
  const _MorphingSearchBar({
    required this.t,
    required this.onTap,
  });

  final double t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // t: 0 => barra completa, t: 1 => botón circular a la derecha.
    final w = MediaQuery.sizeOf(context).width;
    final fullW = w - (EvetaShopDimens.spaceLg * 2);
    const circle = 46.0;
    final targetW = lerpDouble(fullW, circle, t) ?? fullW;
    final radius = lerpDouble(26, 23, t) ?? 26;

    return SizedBox(
      height: 58,
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 0),
          width: targetW,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.82 : 0.95),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: scheme.outline.withValues(alpha: isDark ? 0.32 : 0.18)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Barra completa visible cuando t ~ 0
                  Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: IgnorePointer(
                      ignoring: t > 0.05,
                      child: Transform.scale(
                        scale: lerpDouble(1.0, 0.82, t) ?? 1.0,
                        alignment: Alignment.centerLeft,
                        child: EvetaSearchBar(onTap: onTap),
                      ),
                    ),
                  ),
                  // Botón circular visible cuando t ~ 1
                  Opacity(
                    // Cuando ya está bien compacto, el circular vive arriba (overlay).
                    opacity: (t < 0.92 ? t : 0.0).clamp(0.0, 1.0),
                    child: Align(
                      alignment: Alignment.center,
                      child: Icon(Icons.search_rounded, color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
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
              Container(
                width: 140,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
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

    final statusTop = MediaQuery.paddingOf(context).top;
    final inner = Padding(
      padding: EdgeInsets.fromLTRB(EvetaShopDimens.spaceLg, 8 + statusTop, EvetaShopDimens.spaceLg, 12),
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
