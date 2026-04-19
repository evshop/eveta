import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:eveta/common_widget/bottom_nav_bar_widget.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/common_widget/eveta_circular_back_button.dart';
import 'package:eveta/common_widget/product_card_skeleton.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/eveta_category_chip.dart';
import 'package:eveta/ui/shop/premium/eveta_new_arrival_card.dart';
import 'package:eveta/utils/catalog_cache_service.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';

/// Productos de una categoría: cabecera tipo tienda (banner + degradado), buscador flotante, subcategorías y grid estilo inicio.
class CategoryProductsScreen extends StatefulWidget {
  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.title,
    this.onProductTap,
    this.onBottomNavTap,
  });

  final String categoryId;
  final String title;
  final void Function(String productId)? onProductTap;
  final void Function(int index)? onBottomNavTap;

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  bool _bootLoading = true;
  String? _error;
  List<Map<String, dynamic>> _subcategories = [];
  Map<String, dynamic>? _categoryRow;
  List<Map<String, dynamic>> _products = [];
  String? _selectedSubCategoryId;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  bool _pinnedTitle = false;

  static String? _parentIdOf(Map<String, dynamic> c) {
    final v = c['parent_id'];
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final w = MediaQuery.sizeOf(context).width;
    // Cuando el título grande del banner sube ~fuera de vista (similar al inicio con cabecera fija).
    final threshold = 168 * (w / 375);
    final show = _scrollController.hasClients && _scrollController.offset >= threshold;
    if (show != _pinnedTitle) setState(() => _pinnedTitle = show);
  }

  Future<void> _bootstrap() async {
    setState(() {
      _bootLoading = true;
      _error = null;
    });
    try {
      final cats = await CatalogCacheService.getCategories();
      if (!mounted) return;
      Map<String, dynamic>? row;
      for (final c in cats) {
        if (c['id']?.toString() == widget.categoryId) {
          row = c;
          break;
        }
      }
      final subs = cats.where((c) => _parentIdOf(c) == widget.categoryId).toList();
      setState(() {
        _categoryRow = row;
        _subcategories = subs;
      });
      await _loadProducts(forceRefresh: false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _bootLoading = false);
    }
  }

  Future<void> _loadProducts({required bool forceRefresh}) async {
    try {
      List<Map<String, dynamic>> list;
      if (_selectedSubCategoryId != null) {
        list = await CatalogCacheService.getProductsByCategory(
          _selectedSubCategoryId!,
          forceRefresh: forceRefresh,
        );
      } else if (_subcategories.isEmpty) {
        list = await CatalogCacheService.getProductsByCategory(
          widget.categoryId,
          forceRefresh: forceRefresh,
        );
      } else {
        final ids = [
          widget.categoryId,
          ..._subcategories.map((s) => s['id'].toString()),
        ];
        list = await CatalogCacheService.getProductsByCategoryIds(
          ids,
          forceRefresh: forceRefresh,
        );
      }
      if (!mounted) return;
      setState(() {
        _products = list;
        final vis = _subcategoriesWithProducts();
        if (_selectedSubCategoryId != null &&
            !vis.any((s) => s['id'].toString() == _selectedSubCategoryId)) {
          _selectedSubCategoryId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _products = [];
        _error ??= e.toString();
      });
    }
  }

  Future<void> _refresh() async {
    await CatalogCacheService.getCategories(forceRefresh: true);
    await _loadProducts(forceRefresh: true);
  }

  Future<void> _onSelectSubcategory(String? subId) async {
    if (_selectedSubCategoryId == subId) return;
    setState(() => _selectedSubCategoryId = subId);
    await _loadProducts(forceRefresh: false);
    if (!mounted) return;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
      setState(() => _pinnedTitle = false);
    }
  }

  String? _categoryImageUrl() {
    final u = _categoryRow?['image_url']?.toString().trim();
    return (u == null || u.isEmpty) ? null : u;
  }

  String _headerSubtitle(List<Map<String, dynamic>> filtered) {
    final desc = _categoryRow?['description']?.toString().trim();
    if (desc != null && desc.isNotEmpty) return desc;
    if (filtered.isEmpty) return 'Sin productos';
    if (filtered.length == 1) return '1 producto';
    return '${filtered.length} productos';
  }

  /// Subcategorías con al menos un producto (no se muestran vacías).
  List<Map<String, dynamic>> _subcategoriesWithProducts() {
    if (_subcategories.isEmpty || _products.isEmpty) return [];
    final counts = <String, int>{};
    for (final p in _products) {
      final id = p['category_id']?.toString();
      if (id == null || id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return _subcategories
        .where((s) => (counts[s['id'].toString()] ?? 0) > 0)
        .toList();
  }

  List<Map<String, dynamic>> _filterProducts(List<Map<String, dynamic>> all, String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return all;

    int scoreFor(Map<String, dynamic> p) {
      final name = p['name']?.toString().toLowerCase() ?? '';
      final cat = (p['categories'] is Map) ? (p['categories']['name']?.toString().toLowerCase() ?? '') : '';
      final tags = (p['tags'] is List)
          ? (p['tags'] as List).map((e) => e.toString().toLowerCase()).toList()
          : <String>[];

      var score = 0;
      if (name.startsWith(q)) score += 120;
      if (name.contains(q)) score += 80;
      if (cat.startsWith(q)) score += 60;
      if (cat.contains(q)) score += 40;
      for (final t in tags) {
        if (t == q) score += 70;
        if (t.contains(q)) score += 30;
      }
      return score;
    }

    final scored = <({Map<String, dynamic> row, int score})>[];
    for (final p in all) {
      final s = scoreFor(p);
      if (s > 0) scored.add((row: p, score: s));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((x) => x.row).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scale = MediaQuery.sizeOf(context).width / 375;

    if (_bootLoading) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(EvetaShopDimens.spaceLg),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: EvetaShopDimens.spaceMd,
                crossAxisSpacing: EvetaShopDimens.spaceMd,
                childAspectRatio: 0.68,
              ),
              itemCount: 6,
              itemBuilder: (_, __) => const ProductCardSkeleton(),
            ),
          ),
        ),
        bottomNavigationBar: _categoryProductsBottomNav(context),
      );
    }

    if (_error != null && _categoryRow == null && _products.isEmpty) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(EvetaShopDimens.spaceLg),
            child: Text(
              'No se pudieron cargar los datos',
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        bottomNavigationBar: _categoryProductsBottomNav(context),
      );
    }

    final filtered = _filterProducts(_products, _query);
    final subsWithProducts = _subcategoriesWithProducts();
    final banner = _categoryImageUrl();
    final logo = _categoryImageUrl();
    final tt = Theme.of(context).textTheme;
    final barVariant = scheme.brightness == Brightness.dark
        ? EvetaCircularBackVariant.tonalSurface
        : EvetaCircularBackVariant.onLightBackground;

    final bottomPad = BottomNavBarWidget.totalHeight(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      extendBody: true,
      bottomNavigationBar: _categoryProductsBottomNav(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(0, 2 * scale, 12 * scale, 2 * scale),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  EvetaCircularBackButton(
                    variant: barVariant,
                    diameter: (40 * scale).clamp(36.0, 46.0),
                    iconSize: 18 * scale,
                    borderWidth: (1 * scale).clamp(1.0, 1.2),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  SizedBox(width: 2 * scale),
                  Expanded(
                    child: _CategorySearchField(
                      scale: scale,
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
            Visibility(
              visible: _pinnedTitle,
              maintainSize: false,
              maintainState: false,
              child: Material(
                color: scheme.surface,
                elevation: 0.5,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16 * scale, 6 * scale, 16 * scale, 8 * scale),
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: scheme.primary,
                onRefresh: _refresh,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _CategoryScrollHeader(
                        bannerUrl: banner,
                        logoUrl: logo,
                        title: widget.title,
                        subtitle: _headerSubtitle(filtered),
                        scale: scale,
                      ),
                    ),
                    if (subsWithProducts.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(12 * scale, 0, 12 * scale, 2 * scale),
                          child: SizedBox(
                            height: 34 * scale,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: 1 + subsWithProducts.length,
                                separatorBuilder: (_, __) => SizedBox(width: 8 * scale),
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return SubcategoryChip(
                                      dense: true,
                                      label: 'Todos',
                                      selected: _selectedSubCategoryId == null,
                                      onTap: () => _onSelectSubcategory(null),
                                    );
                                  }
                                  final c = subsWithProducts[index - 1];
                                  final id = c['id'].toString();
                                  final name = c['name']?.toString() ?? '';
                                  return SubcategoryChip(
                                    dense: true,
                                    label: name,
                                    selected: _selectedSubCategoryId == id,
                                    onTap: () => _onSelectSubcategory(id),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(12 * scale, 8 * scale, 12 * scale, bottomPad + 12 * scale),
                      sliver: filtered.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Text(
                                  _query.trim().isEmpty
                                      ? 'Sin productos en esta categoría'
                                      : 'No hay resultados',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14 * scale),
                                ),
                              ),
                            )
                          : SliverMasonryGrid.count(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10 * scale,
                              crossAxisSpacing: 10 * scale,
                              childCount: filtered.length,
                              itemBuilder: (context, i) {
                                final p = filtered[i];
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _categoryProductsBottomNav(BuildContext context) {
    if (widget.onBottomNavTap == null) return null;
    return BottomNavBarWidget(
      currentIndex: 1,
      useCartFlyTargetKey: false,
      onTap: (index) {
        Navigator.of(context).pop();
        widget.onBottomNavTap!(index);
      },
    );
  }
}

/// Campo de búsqueda alineado con [EvetaSearchBar] de la pantalla Categorías (cápsula, no círculo).
class _CategorySearchField extends StatelessWidget {
  const _CategorySearchField({
    required this.scale,
    required this.controller,
    required this.onChanged,
  });

  final double scale;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = EvetaShopDimens.radiusXl + 4;
    final hPad = (EvetaShopDimens.spaceMd * scale).clamp(12.0, 16.0);
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(r),
      child: Container(
        constraints: BoxConstraints(minHeight: 38 * scale, maxHeight: 42 * scale),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: scheme.outline.withValues(alpha: isDark ? 0.35 : 0.5)),
        ),
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 2 * scale),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: scheme.onSurfaceVariant, size: 20 * scale),
            SizedBox(width: (8 * scale).clamp(6.0, 10.0)),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textAlign: TextAlign.left,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(
                  fontSize: 14 * scale,
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar en esta categoría',
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                    fontSize: 14 * scale,
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6 * scale),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cabecera con scroll: banner ancho + degradado a [surface] + fila logo / título (misma composición que la tienda).
class _CategoryScrollHeader extends StatelessWidget {
  const _CategoryScrollHeader({
    required this.bannerUrl,
    required this.logoUrl,
    required this.title,
    required this.subtitle,
    required this.scale,
  });

  final String? bannerUrl;
  final String? logoUrl;
  final String title;
  final String subtitle;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bannerH = 196.0 * scale;
    final headerH = 292.0 * scale;
    final surface = scheme.surface;
    final b = bannerUrl?.trim() ?? '';
    final l = logoUrl?.trim() ?? '';

    return SizedBox(
      height: headerH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: bannerH,
            child: b.isNotEmpty
                ? EvetaCachedImage(
                    imageUrl: b,
                    delivery: EvetaImageDelivery.detail,
                    fit: BoxFit.cover,
                    memCacheWidth: 1280,
                  )
                : ColoredBox(color: scheme.surfaceContainerHigh),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: bannerH,
            bottom: 0,
            child: ColoredBox(color: surface),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: bannerH,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      surface.withValues(alpha: 0.12),
                      surface.withValues(alpha: 0.55),
                      surface,
                    ],
                    stops: const [0.0, 0.38, 0.62, 0.88, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16 * scale,
            right: 16 * scale,
            top: 188 * scale,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (l.isNotEmpty)
                  Container(
                    width: 62 * scale,
                    height: 62 * scale,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surfaceContainerHighest,
                      border: Border.all(color: scheme.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: EvetaCachedImage(
                        imageUrl: l,
                        delivery: EvetaImageDelivery.card,
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 62 * scale,
                    height: 62 * scale,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.primary, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        title.isNotEmpty ? title[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                          fontSize: 22 * scale,
                        ),
                      ),
                    ),
                  ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18 * scale,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        SizedBox(height: 4 * scale),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12 * scale,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
