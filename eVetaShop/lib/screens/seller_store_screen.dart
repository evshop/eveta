import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eveta/common_widget/bottom_nav_bar_widget.dart';
import 'package:eveta/common_widget/grid_tiles_products.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';
import 'package:eveta/utils/supabase_service.dart';
import 'package:eveta/screens/product_detail_screen.dart';
import 'package:eveta/screens/search_screen.dart';

class SellerStoreScreen extends StatefulWidget {
  const SellerStoreScreen({super.key, required this.sellerId});

  final String sellerId;

  @override
  State<SellerStoreScreen> createState() => _SellerStoreScreenState();
}

class _SellerStoreScreenState extends State<SellerStoreScreen> {
  Future<_StoreScreenData>? _storeFuture;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedProductId;

  /// Iconos oscuros sobre fondo claro (la barra del sistema ya no queda “blanco sobre blanco”).
  static const SystemUiOverlayStyle _storeStatusStyle = SystemUiOverlayStyle(
    statusBarColor: Color(0xE6F2F3F5),
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFFF5F6F7),
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static const SystemUiOverlayStyle _shellStatusStyle = SystemUiOverlayStyle(
    statusBarColor: Color(0xFF09CB6B),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFFFFFFF),
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  @override
  void initState() {
    super.initState();
    _storeFuture = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(_storeStatusStyle);
    });
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(_shellStatusStyle);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showProductDetail(String productId) {
    setState(() {
      _selectedProductId = productId;
    });
  }

  void _closeProductDetail() {
    setState(() {
      _selectedProductId = null;
    });
  }

  Future<_StoreScreenData> _load() async {
    final results = await Future.wait([
      SupabaseService.getShopBySellerId(widget.sellerId),
      SupabaseService.getProductsBySellerId(widget.sellerId),
    ]);
    return _StoreScreenData(
      shop: results[0] as Map<String, dynamic>?,
      products: results[1] as List<Map<String, dynamic>>,
    );
  }

  Future<void> _refreshStore() async {
    setState(() {
      _storeFuture = _load();
    });
    await _storeFuture;
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final scale = screenW / 375;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _storeStatusStyle,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: BottomNavBarWidget(
          currentIndex: 0,
          useCartFlyTargetKey: false,
          onTap: (_) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        body: SafeArea(
        child: FutureBuilder<_StoreScreenData>(
          future: _storeFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data;
            if (data == null || data.shop == null) {
              return const Center(child: Text('No se pudo cargar la tienda.'));
            }

            final shop = data.shop!;
            final shopName = shop['shop_name']?.toString().trim().isNotEmpty == true
                ? shop['shop_name'].toString().trim()
                : (shop['full_name']?.toString().trim().isNotEmpty == true ? shop['full_name'].toString().trim() : 'Tienda');
            final shopDescription = shop['shop_description']?.toString().trim() ?? '';
            final bannerUrl = shop['shop_banner_url']?.toString();
            final logoUrl = shop['shop_logo_url']?.toString();
            final filteredProducts = _filterProducts(data.products, _query);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                RefreshIndicator(
                  onRefresh: _refreshStore,
                  child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _StoreScrollHeader(
                        bannerUrl: bannerUrl,
                        logoUrl: logoUrl,
                        shopName: shopName,
                        shopDescription: shopDescription,
                        scale: scale,
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 10 * scale)),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                      sliver: filteredProducts.isEmpty
                          ? SliverFillRemaining(
                              child: Center(
                                child: Text(
                                  _query.trim().isEmpty
                                      ? 'Aún no hay productos en esta tienda'
                                      : 'No hay resultados en esta tienda',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14 * scale),
                                ),
                              ),
                            )
                          : SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.65,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final p = filteredProducts[index];
                                  final images = p['images'];
                                  String imageUrl = 'https://via.placeholder.com/150';
                                  if (images != null) {
                                    if (images is List && images.isNotEmpty) {
                                      imageUrl = images.first.toString();
                                    } else if (images is String && images.toString().isNotEmpty) {
                                      imageUrl = images.toString();
                                    }
                                  }

                                  final price = p['price']?.toString();
                                  final originalPrice = p['original_price']?.toString();
                                  final productId = p['id'].toString();

                                  return GridTilesProducts(
                                    name: p['name']?.toString() ?? 'Sin nombre',
                                    imageUrl: imageUrl,
                                    slug: productId,
                                    price: price,
                                    originalPrice: originalPrice,
                                    discount: null,
                                    isBestSeller: p['is_featured'] == true,
                                    stock: p['stock'] ?? 1,
                                    rating: (p['rating'] ?? 0).toDouble(),
                                    reviewCount: p['review_count'] ?? 0,
                                    isTwoLineMode: true,
                                    onTap: () => _showProductDetail(productId),
                                  );
                                },
                                childCount: filteredProducts.length,
                              ),
                            ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 24 * scale)),
                  ],
                ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16 * scale, 14 * scale, 16 * scale, 0),
                      child: Material(
                        color: Colors.transparent,
                        elevation: 8,
                        shadowColor: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        child: _StoreSearchField(
                          scale: scale,
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                    ),
                  ),
                ),

                if (_selectedProductId != null) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _closeProductDetail,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.zero,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: ProductDetailScreen(
                          productId: _selectedProductId!,
                          onClose: _closeProductDetail,
                          onTagTap: (tag) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SearchScreen(initialQuery: tag),
                              ),
                            );
                          },
                          onRelatedProductTap: _showProductDetail,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      ),
    );
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
}

/// Campo de búsqueda (reutilizado en la barra flotante).
class _StoreSearchField extends StatelessWidget {
  const _StoreSearchField({
    required this.scale,
    required this.controller,
    required this.onChanged,
  });

  final double scale;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34 * scale,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF09CB6B),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textAlign: TextAlign.left,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(
            fontSize: 13.5 * scale,
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Buscar en esta tienda',
            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13 * scale),
            prefixIcon: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: Icon(Icons.search, color: Colors.grey.shade700, size: 16),
            ),
            prefixIconConstraints: BoxConstraints(
              minWidth: 34 * scale,
              minHeight: 34 * scale,
            ),
            isDense: false,
            contentPadding: EdgeInsets.symmetric(vertical: 8 * scale, horizontal: 0),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

/// Cabecera de tienda que hace scroll (banner + tienda). El buscador va aparte, fijo.
class _StoreScrollHeader extends StatelessWidget {
  const _StoreScrollHeader({
    required this.bannerUrl,
    required this.logoUrl,
    required this.shopName,
    required this.shopDescription,
    required this.scale,
  });

  final String? bannerUrl;
  final String? logoUrl;
  final String shopName;
  final String shopDescription;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final bannerH = 196.0 * scale;
    final headerH = 304.0 * scale;

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
            child: bannerUrl != null && bannerUrl!.isNotEmpty
                ? EvetaCachedImage(
                    imageUrl: bannerUrl!,
                    delivery: EvetaImageDelivery.detail,
                    fit: BoxFit.cover,
                    memCacheWidth: 1280,
                  )
                : ColoredBox(color: Colors.grey.shade200),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: bannerH,
            bottom: 0,
            child: const ColoredBox(color: Color(0xFFFFFFFF)),
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
                      Colors.white.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.72),
                      const Color(0xFFFFFFFF),
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
                if (logoUrl != null && logoUrl!.isNotEmpty)
                  Container(
                    width: 62 * scale,
                    height: 62 * scale,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF09CB6B), width: 2),
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
                        imageUrl: logoUrl!,
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
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF09CB6B), width: 2),
                    ),
                    child: const Icon(Icons.storefront_outlined, color: Colors.grey),
                  ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        shopName,
                        style: TextStyle(
                          fontSize: 18 * scale,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (shopDescription.isNotEmpty) ...[
                        SizedBox(height: 4 * scale),
                        Text(
                          shopDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12 * scale,
                            color: Colors.grey.shade700,
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

class _StoreScreenData {
  const _StoreScreenData({required this.shop, required this.products});

  final Map<String, dynamic>? shop;
  final List<Map<String, dynamic>> products;
}

