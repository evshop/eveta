import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:eveta/screens/category_products_screen.dart';
import 'package:eveta/screens/search_screen.dart';
import 'package:eveta/utils/catalog_cache_service.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/eveta_category_chip.dart';
import 'package:eveta/ui/shop/eveta_product_card_compact.dart';
import 'package:eveta/ui/shop/eveta_search_bar.dart';
import 'package:eveta/ui/shop/eveta_section_header.dart';
import 'package:eveta/ui/shop/sticky_category_header.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, this.onProductTap});

  final ValueChanged<String>? onProductTap;

  @override
  State<CategoriesScreen> createState() => CategoriesScreenState();
}

class CategoriesScreenState extends State<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _topLevelCategories = [];
  Map<String, List<Map<String, dynamic>>> _categoryProducts = {};
  bool _isLoading = true;
  String? _selectedTopCategoryId;
  String? _selectedSubCategoryId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> reloadFromServer() => _loadData(forceRefresh: true);

  /// Normaliza [parent_id] desde Supabase (UUID, int, null, etc.).
  static String? _parentIdOf(Map<String, dynamic> c) {
    final v = c['parent_id'];
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    try {
      final categories = await CatalogCacheService.getCategories(forceRefresh: forceRefresh);
      final productsByCategory = <String, List<Map<String, dynamic>>>{};

      for (var cat in categories) {
        final catId = cat['id'].toString();
        final products = await CatalogCacheService.getProductsByCategory(catId, forceRefresh: forceRefresh);
        productsByCategory[catId] = products.take(10).toList();
      }

      if (mounted) {
        setState(() {
          _categories = categories;
          _topLevelCategories = categories.where((c) => _parentIdOf(c) == null).toList();
          _categoryProducts = productsByCategory;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _subcategoriesForSelected {
    if (_selectedTopCategoryId == null) return [];
    final sel = _selectedTopCategoryId!;
    return _categories.where((c) => _parentIdOf(c) == sel).toList();
  }

  /// Altura fija del bloque pinned (safe area + título + buscador + chips + subchips opcional).
  double _pinnedHeaderExtent(BuildContext context) {
    final pt = MediaQuery.paddingOf(context).top;
    const titleBlock = 10.0 + 30.0 + 12.0 + 52.0 + 12.0;
    const mainChips = 48.0 + 10.0;
    var h = pt + titleBlock + mainChips;
    final subs = _subcategoriesForSelected;
    if (_selectedTopCategoryId != null && subs.isNotEmpty) {
      h += 1.0 + 6.0 + 32.0 + 6.0;
    }
    return h;
  }

  List<Map<String, dynamic>> get _categoriesToDisplay {
    if (_selectedTopCategoryId == null) {
      return _categories;
    }
    final pid = _selectedTopCategoryId!;
    final subcats = _categories.where((c) => _parentIdOf(c) == pid).toList();

    Map<String, dynamic>? parentRow;
    for (final c in _categories) {
      if (c['id'].toString() == pid) {
        parentRow = c;
        break;
      }
    }

    if (subcats.isEmpty) {
      if (parentRow != null) return [parentRow];
      return [];
    }

    if (_selectedSubCategoryId == null) {
      final out = <Map<String, dynamic>>[];
      if (parentRow != null) {
        final parentProds = _categoryProducts[pid] ?? [];
        if (parentProds.isNotEmpty) {
          out.add(parentRow);
        }
      }
      out.addAll(subcats);
      return out;
    }

    final selSub = _selectedSubCategoryId?.trim() ?? '';
    return subcats.where((c) => c['id'].toString().trim() == selSub).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        top: false,
        bottom: false,
        child: _isLoading
            ? _buildCategoriesSkeleton(context)
            : RefreshIndicator(
                color: scheme.primary,
                onRefresh: () => _loadData(forceRefresh: true),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: StickyCategoryHeader(
                        minHeight: _pinnedHeaderExtent(context),
                        maxHeight: _pinnedHeaderExtent(context),
                        backgroundColor: scheme.surface,
                        borderColor: scheme.outline.withValues(alpha: 0.35),
                        builder: (ctx, _) => _buildPinnedHeader(ctx),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final category = _categoriesToDisplay[index];
                            final products = _categoryProducts[category['id'].toString()] ?? [];
                            if (products.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return _buildCategorySection(category, products);
                          },
                          childCount: _categoriesToDisplay.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCategoriesSkeleton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final base = dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerHighest;
    final hi = dark ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(3, (sectionIndex) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 18,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: Row(
                      children: List.generate(3, (index) {
                        return Container(
                          width: 130,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPinnedHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subs = _subcategoriesForSelected;
    final showSubRow = _selectedTopCategoryId != null && subs.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: MediaQuery.paddingOf(context).top),
        Padding(
          padding: const EdgeInsets.fromLTRB(EvetaShopDimens.spaceLg, 10, EvetaShopDimens.spaceLg, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Categorías',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              EvetaSearchBar(
                controller: _searchController,
                hintText: 'Buscar en eVeta…',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const SearchScreen()));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceLg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                EvetaCategoryChip(
                  label: 'Todos',
                  selected: _selectedTopCategoryId == null,
                  onTap: () {
                    setState(() {
                      _selectedTopCategoryId = null;
                      _selectedSubCategoryId = null;
                    });
                  },
                ),
                ..._topLevelCategories.map((cat) {
                  final id = cat['id'].toString();
                  return EvetaCategoryChip(
                    label: cat['name']?.toString() ?? '',
                    selected: _selectedTopCategoryId == id,
                    onTap: () {
                      setState(() {
                        _selectedTopCategoryId = id;
                        _selectedSubCategoryId = null;
                      });
                    },
                  );
                }),
              ],
            ),
          ),
        ),
        if (showSubRow) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(EvetaShopDimens.spaceLg, 6, EvetaShopDimens.spaceLg, 0),
            child: Divider(height: 1, thickness: 1, color: scheme.outline.withValues(alpha: 0.35)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SubcategoryChip(
                    label: 'Todos',
                    selected: _selectedSubCategoryId == null,
                    onTap: () => setState(() => _selectedSubCategoryId = null),
                  ),
                  ...subs.map((cat) {
                    final id = cat['id'].toString();
                    return SubcategoryChip(
                      label: cat['name']?.toString() ?? '',
                      selected: _selectedSubCategoryId == id,
                      onTap: () => setState(() => _selectedSubCategoryId = id),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
        const Spacer(),
      ],
    );
  }

  void _openCategoryAll(Map<String, dynamic> category) {
    final id = category['id']?.toString() ?? '';
    final title = category['name']?.toString() ?? 'Categoría';
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CategoryProductsScreen(
          categoryId: id,
          title: title,
          onProductTap: widget.onProductTap,
        ),
      ),
    );
  }

  Widget _buildCategorySection(Map<String, dynamic> category, List<Map<String, dynamic>> products) {
    final catName = category['name']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EvetaSectionHeader(
          title: catName,
          subtitle: '${products.length} productos',
          actionLabel: 'Ver todo',
          onAction: () => _openCategoryAll(category),
        ),
        SizedBox(
          height: 272,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceLg),
            itemCount: products.length + 1,
            itemBuilder: (context, index) {
              if (index == products.length) {
                return Padding(
                  padding: const EdgeInsets.only(left: EvetaShopDimens.spaceSm),
                  child: Center(
                    child: IconButton.filled(
                      onPressed: () => _openCategoryAll(category),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                );
              }
              final p = products[index];
              return Padding(
                padding: const EdgeInsets.only(right: EvetaShopDimens.spaceMd),
                child: EvetaProductCardCompact(
                  width: 156,
                  product: p,
                  onTap: widget.onProductTap != null ? () => widget.onProductTap!(p['id'].toString()) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
