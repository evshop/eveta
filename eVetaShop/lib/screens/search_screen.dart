import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/common_widget/eveta_circular_back_button.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';
import 'package:eveta/screens/product_detail_screen.dart';
import 'package:eveta/screens/seller_store_screen.dart';
import 'package:eveta/search/advanced_search_filters_sheet.dart';
import 'package:eveta/search/product_search_controller.dart';
import 'package:eveta/search/search_filter_bar.dart';
import 'package:eveta/utils/page_transitions.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final ProductSearchController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProductSearchController(initialQuery: widget.initialQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        _controller.ensureCategoriesLoaded(),
        _controller.ensurePriceSliderMax(),
      ]);
      if (!mounted) return;
      await _controller.refresh();
    });
    if (widget.initialQuery == null || widget.initialQuery!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_controller.focusNode);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    await Future.wait([
      _controller.ensureCategoriesLoaded(),
      _controller.ensurePriceSliderMax(),
    ]);
    if (!mounted) return;
    final next = await AdvancedSearchFiltersSheet.show(
      context,
      initial: _controller.filters,
      categories: _controller.categories,
      priceSliderMax: _controller.priceSliderMax,
    );
    if (next != null && mounted) {
      _controller.setFilters(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  EvetaCircularBackButton(
                    variant: Theme.of(context).brightness == Brightness.dark
                        ? EvetaCircularBackVariant.onDarkBackground
                        : EvetaCircularBackVariant.onLightBackground,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: SearchFilterBar(
                      controller: _controller,
                      onOpenFilters: _openFilters,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.showResultsPanel,
      builder: (context, showPanel, child) {
        if (!showPanel) {
          return const SizedBox.shrink();
        }
        return child!;
      },
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final scheme = Theme.of(context).colorScheme;
          final loading = _controller.isLoading;
          final products = _controller.productResults;
          final stores = _controller.storeResults;

          if (loading && products.isEmpty && stores.isEmpty) {
            return Center(
              child: CircularProgressIndicator(color: scheme.primary),
            );
          }

          if (!loading && products.isEmpty && stores.isEmpty) {
            return Center(
              child: Text(
                'No se encontraron resultados',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
            );
          }

          final storeCount = stores.length;
          final productCount = products.length;
          var listItemCount = 0;
          if (storeCount > 0) {
            listItemCount += 1 + storeCount;
          }
          if (productCount > 0) {
            if (storeCount > 0) {
              listItemCount += 1;
            }
            listItemCount += productCount;
          }

          return Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: listItemCount,
                itemBuilder: (context, index) {
                  var i = index;
                  if (storeCount > 0) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                        child: Text(
                          'Tiendas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    i -= 1;
                    if (i < storeCount) {
                      return _buildStoreTile(context, stores[i]);
                    }
                    i -= storeCount;
                  }
                  if (productCount > 0 && storeCount > 0) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Text(
                          'Productos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    i -= 1;
                  }
                  final product = products[i];
                  return _buildProductTile(context, product);
                },
              ),
              if (loading)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: scheme.primary,
                    backgroundColor: scheme.primary.withValues(alpha: 0.12),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductTile(BuildContext context, Map<String, dynamic> product) {
    final scheme = Theme.of(context).colorScheme;
    final images = product['images'];
    String imageUrl = '';
    if (images is List && images.isNotEmpty) {
      imageUrl = images.first.toString();
    } else if (images is String && images.isNotEmpty) {
      imageUrl = images;
    }

    final name = product['name']?.toString() ?? 'Sin nombre';
    final priceString = product['price']?.toString() ?? '0';
    final price = double.tryParse(priceString) ?? 0;
    final category = product['categories']?['name']?.toString() ?? '';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          SlideUpPageRoute(
            builder: (context) => ProductDetailScreen(
              productId: product['id'].toString(),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              color: scheme.surfaceContainerHigh,
              child: imageUrl.isEmpty
                  ? Icon(
                      Icons.image_not_supported,
                      color: scheme.onSurfaceVariant,
                    )
                  : EvetaCachedImage(
                      imageUrl: imageUrl,
                      delivery: EvetaImageDelivery.card,
                      fit: BoxFit.contain,
                      memCacheWidth: 200,
                      errorIconSize: 32,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bs ${price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreTile(BuildContext context, Map<String, dynamic> store) {
    final scheme = Theme.of(context).colorScheme;
    final shopName = store['shop_name']?.toString().trim() ?? '';
    final fullName = store['full_name']?.toString().trim() ?? '';
    final label = shopName.isNotEmpty
        ? shopName
        : (fullName.isNotEmpty ? fullName : 'Tienda');
    final logoRaw = store['shop_logo_url']?.toString().trim() ?? '';
    final avatarRaw = store['avatar_url']?.toString().trim() ?? '';
    final imageUrl = logoRaw.isNotEmpty ? logoRaw : avatarRaw;

    return InkWell(
      onTap: () {
        final id = store['id']?.toString();
        if (id == null || id.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => SellerStoreScreen(sellerId: id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 52,
                height: 52,
                color: scheme.surfaceContainerHigh,
                child: imageUrl.isEmpty
                    ? Icon(
                        Icons.storefront_outlined,
                        color: scheme.onSurfaceVariant,
                        size: 28,
                      )
                    : EvetaCachedImage(
                        imageUrl: imageUrl,
                        delivery: EvetaImageDelivery.card,
                        fit: BoxFit.cover,
                        memCacheWidth: 160,
                        errorIconSize: 28,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
