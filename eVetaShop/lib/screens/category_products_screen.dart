import 'package:flutter/material.dart';
import 'package:eveta/common_widget/product_card_skeleton.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/eveta_product_card_modern.dart';
import 'package:eveta/utils/catalog_cache_service.dart';

/// Lista en grid de productos de una categoría (desde “Ver todo”).
class CategoryProductsScreen extends StatefulWidget {
  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.title,
    this.onProductTap,
  });

  final String categoryId;
  final String title;
  final void Function(String productId)? onProductTap;

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = CatalogCacheService.getProductsByCategory(widget.categoryId);
  }

  Future<void> _refresh() async {
    final f = CatalogCacheService.getProductsByCategory(widget.categoryId, forceRefresh: true);
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: scheme.primary,
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return GridView.builder(
                padding: const EdgeInsets.all(EvetaShopDimens.spaceLg),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: EvetaShopDimens.spaceMd,
                  crossAxisSpacing: EvetaShopDimens.spaceMd,
                  childAspectRatio: 0.68,
                ),
                itemCount: 6,
                itemBuilder: (_, __) => const ProductCardSkeleton(),
              );
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                  Center(
                    child: Text(
                      snapshot.hasError ? 'No se pudieron cargar los productos' : 'Sin productos en esta categoría',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              );
            }
            final list = snapshot.data!;
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                EvetaShopDimens.spaceLg,
                EvetaShopDimens.spaceSm,
                EvetaShopDimens.spaceLg,
                100,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: EvetaShopDimens.spaceMd,
                crossAxisSpacing: EvetaShopDimens.spaceMd,
                childAspectRatio: 0.68,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final p = list[i];
                return EvetaProductCardModern(
                  product: p,
                  onTap: widget.onProductTap != null
                      ? () => widget.onProductTap!(p['id'].toString())
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
