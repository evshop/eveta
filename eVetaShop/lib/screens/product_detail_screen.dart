import 'dart:async';
import 'dart:math' show Random;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:eveta/common_widget/eveta_carousel_segment_indicator.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/common_widget/eveta_fullscreen_image_viewer.dart';
import 'package:eveta/common_widget/eveta_circular_back_button.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';
import 'package:eveta/utils/catalog_cache_service.dart';
import 'package:eveta/utils/product_share_helper.dart';
import 'package:eveta/utils/cart_service.dart';
import 'package:eveta/utils/favorites_service.dart';
import 'package:eveta/common_widget/product_card_skeleton.dart';
import 'package:eveta/ui/shop/premium/eveta_new_arrival_card.dart';
import 'package:eveta/utils/cart_animation_helper.dart';
import 'package:eveta/common_widget/bottom_nav_bar_widget.dart';
import 'package:eveta/screens/seller_store_screen.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/utils/supabase_service.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId, this.onClose, this.onTagTap, this.onRelatedProductTap});

  final String productId;
  final VoidCallback? onClose;
  final ValueChanged<String>? onTagTap;
  final ValueChanged<String>? onRelatedProductTap;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> with TickerProviderStateMixin {
  /// Fondo de pantalla detalle en oscuro: #1C1C1E (iOS) en lugar de negro puro.
  Color _detailCanvasColor(ColorScheme scheme) {
    return scheme.brightness == Brightness.dark ? EvetaShopColors.darkCard : scheme.surface;
  }

  int _selectedImageIndex = 0;
  int _quantity = 1;
  late Future<Map<String, dynamic>?> _productFuture;
  late Future<List<Map<String, dynamic>>> _relatedProductsFuture;
  bool _isAddingToCart = false;
  final GlobalKey _imageKey = GlobalKey();

  final PageController _pageController = PageController();
  final PageController _thumbnailController = PageController();
  bool _edgeSwipeEnabled = true;
  Timer? _autoPlayTimer;
  Timer? _resumeTimer;
  bool _isUserInteracting = false;
  bool _isFavorite = false;
  late AnimationController _progressController;
  final int _autoPlaySeconds = 8;
  int _currentImageCount = 0;
  /// Evita llamar `_startAutoPlay` desde `build`: cada `setState` reiniciaba el temporizador.
  String? _autoPlayPrimedForProductId;
  final ScrollController _detailScrollController = ScrollController();
  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _autoPlaySeconds),
    );
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!_isUserInteracting && _currentImageCount > 1) {
          final nextPage = (_selectedImageIndex + 1) % _currentImageCount;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    _loadData();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final v = await FavoritesService.isFavorite(widget.productId);
    if (mounted) setState(() => _isFavorite = v);
  }

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _autoPlayPrimedForProductId = null;
      _selectedImageIndex = 0;
      _quantity = 1;
      _descriptionExpanded = false;
      if (_detailScrollController.hasClients) {
        _detailScrollController.jumpTo(0);
      }
      _loadData();
      _loadFavoriteStatus();
    }
  }

  void _loadData() {
    // Siempre pedir el producto al servidor: el caché (TTL 6h) dejaba descripción,
    // apartados (specs_json) y categoría desactualizados tras editar en el admin.
    _productFuture = CatalogCacheService.getProductById(
      widget.productId,
      forceRefresh: true,
    );
    _relatedProductsFuture = _loadRelatedProducts();
  }

  List<String> _parseTagsField(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.split(RegExp(r'[\s,;]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  List<String> _keywordsFromName(String name) {
    final parts = name.toLowerCase().split(RegExp(r'\s+'));
    final out = <String>[];
    for (final p in parts) {
      final t = p.replaceAll(RegExp(r'[^a-záéíóúüñ0-9]'), '');
      if (t.length >= 2 && !out.contains(t)) out.add(t);
    }
    return out.take(10).toList();
  }

  int _nameRelatedScore(String candidateName, List<String> keywords, String originalLower) {
    if (candidateName.isEmpty) return 0;
    final n = candidateName.toLowerCase();
    var s = 0;
    for (final k in keywords) {
      if (k.length < 2) continue;
      if (n.contains(k)) s += 14;
    }
    for (final part in originalLower.split(RegExp(r'\s+'))) {
      final t = part.replaceAll(RegExp(r'[^a-záéíóúüñ0-9]'), '');
      if (t.length >= 3 && n.contains(t)) s += 9;
    }
    return s;
  }

  /// Orden: 1–3 por nombre, 4º por hashtags, 5–9 mezcla aleatoria (nombre/tienda/tags), 10º al azar.
  Future<List<Map<String, dynamic>>> _loadRelatedProducts() async {
    final product = await _productFuture;
    if (product == null) return [];
    final excludeId = widget.productId;
    final sellerId = product['seller_id']?.toString();
    final tags = _parseTagsField(product['tags']);
    final productName = product['name']?.toString() ?? '';
    final categoryId = product['category_id']?.toString();
    final rnd = Random();
    final nameLower = productName.toLowerCase();

    var keywords = _keywordsFromName(productName);
    if (keywords.isEmpty) {
      final raw = productName.trim().toLowerCase().replaceAll(RegExp(r'[^a-záéíóúüñ0-9]'), '');
      if (raw.length >= 2) {
        keywords = [raw.length >= 4 ? raw.substring(0, 4) : raw];
      }
    }

    final used = <String>{excludeId};
    final result = <Map<String, dynamic>>[];

    final namePool = <String, Map<String, dynamic>>{};
    for (final w in keywords) {
      final list = await SupabaseService.searchProductsByNameWord(
        w,
        excludeProductId: excludeId,
        limit: 24,
      );
      for (final p in list) {
        final id = p['id']?.toString();
        if (id == null || id.isEmpty) continue;
        namePool[id] = p;
      }
    }

    final byNameScore = namePool.values.toList()
      ..sort((a, b) {
        final sa = _nameRelatedScore(a['name']?.toString() ?? '', keywords, nameLower);
        final sb = _nameRelatedScore(b['name']?.toString() ?? '', keywords, nameLower);
        final c = sb.compareTo(sa);
        if (c != 0) return c;
        return (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? '');
      });
    for (final p in byNameScore) {
      if (result.length >= 3) break;
      final id = p['id']?.toString();
      if (id == null || used.contains(id)) continue;
      used.add(id);
      result.add(p);
    }

    if (result.length < 3 && categoryId != null && categoryId.isNotEmpty) {
      var cat = await CatalogCacheService.getProductsByCategory(categoryId);
      cat = cat.where((p) => p['id'].toString() != excludeId).toList();
      cat.sort((a, b) {
        final sa = _nameRelatedScore(a['name']?.toString() ?? '', keywords, nameLower);
        final sb = _nameRelatedScore(b['name']?.toString() ?? '', keywords, nameLower);
        final c = sb.compareTo(sa);
        if (c != 0) return c;
        return (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? '');
      });
      for (final p in cat) {
        if (result.length >= 3) break;
        final id = p['id']?.toString();
        if (id == null || used.contains(id)) continue;
        used.add(id);
        result.add(p);
      }
    }

    if (tags.isNotEmpty && result.length == 3) {
      final tagList = await SupabaseService.getProductsOverlappingTags(
        tags,
        excludeProductId: excludeId,
        limit: 36,
      );
      tagList.shuffle(rnd);
      for (final p in tagList) {
        final id = p['id']?.toString();
        if (id == null || used.contains(id)) continue;
        used.add(id);
        result.add(p);
        break;
      }
    }

    final mixBucket = <String, Map<String, dynamic>>{};
    void addMix(List<Map<String, dynamic>> list) {
      for (final p in list) {
        final id = p['id']?.toString();
        if (id == null || id.isEmpty || used.contains(id)) continue;
        mixBucket[id] = p;
      }
    }

    addMix(namePool.values.toList());
    if (sellerId != null && sellerId.isNotEmpty) {
      addMix(await SupabaseService.getProductsBySellerId(sellerId));
    }
    if (tags.isNotEmpty) {
      addMix(await SupabaseService.getProductsOverlappingTags(tags, excludeProductId: excludeId, limit: 48));
    }

    final mixList = mixBucket.values.toList()..shuffle(rnd);
    for (final p in mixList) {
      if (result.length >= 9) break;
      final id = p['id']?.toString();
      if (id == null || used.contains(id)) continue;
      used.add(id);
      result.add(p);
    }

    if (result.length < 10) {
      var broad = <Map<String, dynamic>>[];
      if (categoryId != null && categoryId.isNotEmpty) {
        broad = await CatalogCacheService.getProductsByCategory(categoryId);
      }
      if (broad.length < 8) {
        final home = await CatalogCacheService.getProducts();
        final seen = {...broad.map((e) => e['id']?.toString()).whereType<String>()};
        for (final p in home) {
          final id = p['id']?.toString();
          if (id != null && !seen.contains(id)) broad.add(p);
        }
      }
      broad.shuffle(rnd);
      for (final p in broad) {
        final id = p['id']?.toString();
        if (id == null || used.contains(id)) continue;
        used.add(id);
        result.add(p);
        break;
      }
    }

    while (result.length < 10) {
      var progressed = false;
      for (final p in mixList) {
        final id = p['id']?.toString();
        if (id == null || used.contains(id)) continue;
        used.add(id);
        result.add(p);
        progressed = true;
        break;
      }
      if (!progressed) break;
    }

    return result.take(10).toList();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _resumeTimer?.cancel();
    _pageController.dispose();
    _thumbnailController.dispose();
    _progressController.dispose();
    _detailScrollController.dispose();
    super.dispose();
  }

  int _imageCountFromProduct(Map<String, dynamic> product) {
    final images = product['images'];
    if (images is List) {
      return images.isEmpty ? 1 : images.length;
    }
    if (images is String && images.isNotEmpty) return 1;
    return 1;
  }

  void _scheduleInitialAutoPlayIfNeeded(Map<String, dynamic> product) {
    final pid = widget.productId;
    if (_autoPlayPrimedForProductId == pid) return;
    _autoPlayPrimedForProductId = pid;
    final n = _imageCountFromProduct(product);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.productId != pid) return;
      _startAutoPlay(n, resume: false);
    });
  }

  void _startAutoPlay(int imageCount, {bool resume = false}) {
    _currentImageCount = imageCount;
    if (imageCount <= 1 || _isUserInteracting) return;
    
    if (resume) {
      if (!_progressController.isAnimating) {
        _progressController.forward();
      }
    } else {
      _progressController.forward(from: 0.0);
    }
  }

  void _onUserInteractionStart() {
    _isUserInteracting = true;
    _autoPlayTimer?.cancel();
    _resumeTimer?.cancel();
    _progressController.stop();
  }

  void _onUserInteractionEnd(int imageCount) {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isUserInteracting = false);
        _startAutoPlay(imageCount, resume: true);
      }
    });
  }

  Future<void> _openFullscreenGallery(BuildContext context, List<String> imageUrls, int index) {
    _onUserInteractionStart();
    return Navigator.of(context).push<int>(
      PageRouteBuilder<int>(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return EvetaFullscreenImageViewer(
            imageUrls: imageUrls,
            initialIndex: index,
            heroTagPrefix: widget.productId,
            onExit: (i) {
              if (!mounted) return;
              setState(() => _selectedImageIndex = i);
              _pageController.jumpToPage(i);
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            child: child,
          );
        },
      ),
    ).then((_) {
      if (mounted) _onUserInteractionEnd(imageUrls.length);
    });
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    if (_isAddingToCart) return;

    final stock = product['stock'] ?? 0;
    if (stock == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Este producto está agotado'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    String imageUrl = '';
    final images = product['images'];
    if (images != null) {
      if (images is List && images.isNotEmpty) {
        imageUrl = images.first.toString();
      } else if (images is String && images.isNotEmpty) {
        imageUrl = images;
      }
    }

    setState(() => _isAddingToCart = true);

    // Animación de volar al carrito
    if (mounted) {
      CartAnimationHelper.runFlyToCartAnimation(
        context: context,
        sourceKey: _imageKey,
        destKey: BottomNavBarWidget.cartKey,
        child: SizedBox(
          width: 60,
          height: 60,
          child: imageUrl.isNotEmpty
              ? EvetaCachedImage(
                  imageUrl: imageUrl,
                  delivery: EvetaImageDelivery.thumb,
                  fit: BoxFit.cover,
                  memCacheWidth: 200,
                )
              : Icon(Icons.shopping_cart, color: Theme.of(context).colorScheme.primary),
        ),
        onAnimationComplete: () {
          // Opcional: algún efecto extra al terminar
        },
      );
    }

    try {
      await CartService.addToCart(CartItem(
        productId: product['id'].toString(),
        name: product['name']?.toString() ?? 'Sin nombre',
        price: product['price']?.toString() ?? '0',
        imageUrl: imageUrl,
        quantity: _quantity,
        stock: stock,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agregar: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> product) async {
    final item = FavoriteItem.fromProductMap(product);
    final now = await FavoritesService.toggleFavorite(item);
    if (mounted) setState(() => _isFavorite = now);
  }

  void _shareProduct(Map<String, dynamic> product) {
    showProductShareSheet(context, product);
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final scale = screenW / 375;

    final scaffoldScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: _detailCanvasColor(scaffoldScheme),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _productFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildProductDetailSkeleton(scale);
          }
          if (snapshot.hasError || !snapshot.hasData) {
            final errScheme = Theme.of(context).colorScheme;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: errScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.hasError ? 'Error al cargar' : 'Producto no encontrado',
                    style: TextStyle(color: errScheme.onSurfaceVariant, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          final product = snapshot.data!;
          _scheduleInitialAutoPlayIfNeeded(product);
          return _buildProductDetail(context, product, scale);
        },
      ),
    );
  }

  Widget _buildProductDetailSkeleton(double scale) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final base = dark ? scheme.surfaceContainerHighest : Colors.grey[300]!;
    final hi = dark ? scheme.surfaceBright : Colors.grey[100]!;
    final block = _detailCanvasColor(scheme);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.width,
                    color: block,
                  ),
                  SizedBox(height: 16 * scale),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 150 * scale, height: 24 * scale, color: block),
                        SizedBox(height: 8 * scale),
                        Container(width: double.infinity, height: 20 * scale, color: block),
                        SizedBox(height: 4 * scale),
                        Container(width: 200 * scale, height: 20 * scale, color: block),
                        SizedBox(height: 16 * scale),
                        Container(width: double.infinity, height: 150 * scale, color: block),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          Container(
            height: 80 * scale,
            color: block,
          )
        ],
      ),
    );
  }

  Widget _buildProductDetail(BuildContext context, Map<String, dynamic> product, double scale) {
    final images = product['images'];
    List<String> imageUrls = [];
    if (images != null) {
      if (images is List) {
        imageUrls = images.map((e) => e.toString()).toList();
      } else if (images is String && images.isNotEmpty) {
        imageUrls = [images];
      }
    }
    if (imageUrls.isEmpty) imageUrls = ['https://via.placeholder.com/400'];

    final price = product['price']?.toString() ?? '0';
    final name = product['name']?.toString() ?? 'Sin nombre';
    final description = product['description']?.toString() ?? '';
    final stock = product['stock'] ?? 0;
    final rating = (product['rating'] ?? 0).toDouble();
    final reviewCount = product['review_count'] ?? 0;
    final originalPrice = product['original_price']?.toString();
    final isOutOfStock = stock == 0;
    final unit = product['unit']?.toString() ?? 'unidad';
    final hasDiscount = originalPrice != null &&
        originalPrice != price &&
        double.tryParse(originalPrice) != null &&
        double.parse(originalPrice) > double.parse(price);
    final discountPercent = hasDiscount
        ? (((double.parse(originalPrice) - double.parse(price)) / double.parse(originalPrice)) * 100).round()
        : 0;

    final tags = <String>[];
    if (product['tags'] != null) {
      if (product['tags'] is List) {
        tags.addAll((product['tags'] as List).map((e) => e.toString()));
      }
    }
    if (tags.isEmpty) tags.addAll(['Producto', 'eVeta']);

    final scheme = Theme.of(context).colorScheme;
    final canvas = _detailCanvasColor(scheme);
    final barVariant = scheme.brightness == Brightness.dark
        ? EvetaCircularBackVariant.tonalSurface
        : EvetaCircularBackVariant.onLightBackground;

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
              controller: _detailScrollController,
              physics: const ClampingScrollPhysics(),
              slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                foregroundColor: scheme.onSurface,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                shadowColor: Colors.transparent,
                pinned: true,
                flexibleSpace: ClipRect(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Barra siempre tipo vidrio (blur fijo), sin depender del scroll.
                      final isDarkBar = scheme.brightness == Brightness.dark;
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
                leading: EvetaCircularBackButton(
                  variant: barVariant,
                  diameter: (40 * scale).clamp(36.0, 46.0),
                  iconSize: 18 * scale,
                  borderWidth: (1 * scale).clamp(1.0, 1.2),
                  onPressed: () {
                    if (widget.onClose != null) {
                      widget.onClose!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
                leadingWidth: 56,
                automaticallyImplyLeading: false,
                title: Text(
                  'Detalle del Producto',
                  style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                centerTitle: true,
                actions: [
                  EvetaCircularIconButton(
                    icon: Icons.share_outlined,
                    variant: barVariant,
                    diameter: (40 * scale).clamp(36.0, 46.0),
                    iconSize: 18 * scale,
                    borderWidth: (1 * scale).clamp(1.0, 1.2),
                    tooltip: 'Compartir',
                    onPressed: () => _shareProduct(product),
                  ),
                  EvetaCircularIconButton(
                    icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    variant: barVariant,
                    diameter: (40 * scale).clamp(36.0, 46.0),
                    iconSize: 18 * scale,
                    borderWidth: (1 * scale).clamp(1.0, 1.2),
                    selected: _isFavorite,
                    activeIconColor: Theme.of(context).colorScheme.primary,
                    tooltip: _isFavorite ? 'Quitar de favoritos' : 'Guardar en favoritos',
                    onPressed: () => _toggleFavorite(product),
                  ),
                  SizedBox(width: 4 * scale),
                ],
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageCarousel(imageUrls, hasDiscount, discountPercent, scale),
                    if (imageUrls.length > 1) ...[
                      Container(height: 12 * scale, color: canvas),
                      _buildThumbnailCarousel(imageUrls, scale),
                    ],
                    _buildPriceSection(name, price, unit, originalPrice, hasDiscount, rating, reviewCount, stock, isOutOfStock, scale, product),
                    _buildDescriptionSection(description, tags, scale, widget.onTagTap, product),
                    _buildRelatedProducts(scale),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildBottomBar(isOutOfStock, product, scale),
      ],
    );
  }

  Widget _buildImageCarousel(List<String> imageUrls, bool hasDiscount, int discountPercent, double scale) {
    final canvas = _detailCanvasColor(Theme.of(context).colorScheme);
    return Container(
      color: canvas,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Listener(
                  key: _imageKey,
                  onPointerDown: (e) {
                    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
                    final local = box?.globalToLocal(e.position);
                    final w = box?.size.width ?? MediaQuery.sizeOf(context).width;
                    final x = local?.dx ?? e.position.dx;
                    final edge = w * 0.2; // 20% por lado
                    final enable = x <= edge || x >= (w - edge);
                    if (_edgeSwipeEnabled != enable) setState(() => _edgeSwipeEnabled = enable);
                    _onUserInteractionStart();
                  },
                  onPointerUp: (_) {
                    _onUserInteractionEnd(imageUrls.length);
                    if (_edgeSwipeEnabled != true) setState(() => _edgeSwipeEnabled = true);
                  },
                  onPointerCancel: (_) {
                    _onUserInteractionEnd(imageUrls.length);
                    if (_edgeSwipeEnabled != true) setState(() => _edgeSwipeEnabled = true);
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: imageUrls.length,
                    physics: _edgeSwipeEnabled ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() => _selectedImageIndex = index);
                      _startAutoPlay(imageUrls.length, resume: false);
                    },
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openFullscreenGallery(context, imageUrls, index),
                        child: Hero(
                          tag: '${widget.productId}_$index',
                          child: Material(
                            color: Colors.transparent,
                            child: _buildSquareImageContainer(imageUrls[index]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (imageUrls.length > 1)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: _buildAnimatedPageIndicator(imageUrls.length),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailCarousel(List<String> imageUrls, double scale) {
    final scheme = Theme.of(context).colorScheme;
    final canvas = _detailCanvasColor(scheme);
    return Container(
      height: 72 * scale,
      color: canvas,
      padding: EdgeInsets.only(bottom: 12 * scale),
      child: ListView.builder(
        controller: _thumbnailController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16 * scale),
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          final isActive = _selectedImageIndex == index;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
              setState(() => _selectedImageIndex = index);
            },
            child: Container(
              width: 56 * scale,
              height: 56 * scale,
              margin: EdgeInsets.only(right: 8 * scale),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isActive ? scheme.primary : scheme.outline.withValues(alpha: 0.5),
                  width: isActive ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(10 * scale),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9 * scale),
                child: EvetaCachedImage(
                  imageUrl: imageUrls[index],
                  delivery: EvetaImageDelivery.thumb,
                  fit: BoxFit.cover,
                  memCacheWidth: 240,
                  errorIconSize: 28,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSquareImageContainer(String imageUrl) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: _detailCanvasColor(scheme),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: EvetaCachedImage(
            imageUrl: imageUrl,
            delivery: EvetaImageDelivery.detail,
            fit: BoxFit.contain,
            memCacheWidth: (MediaQuery.sizeOf(context).width *
                    MediaQuery.devicePixelRatioOf(context))
                .round()
                .clamp(800, 1400),
            errorIconSize: 80,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedPageIndicator(int count) {
    return EvetaCarouselSegmentIndicator(
      count: count,
      selectedIndex: _selectedImageIndex,
      progressController: _progressController,
    );
  }

  Widget _buildPriceSection(
    String name,
    String price,
    String unit,
    String? originalPrice,
    bool hasDiscount,
    double rating,
    int reviewCount,
    int stock,
    bool isOutOfStock,
    double scale,
    Map<String, dynamic> product,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final canvas = _detailCanvasColor(scheme);
    return Container(
      color: canvas,
      padding: EdgeInsets.all(20 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.bold, color: scheme.onSurface, height: 1.2)),
          if (rating > 0)
            Padding(
              padding: EdgeInsets.only(top: 8 * scale),
              child: Row(
                children: [
                  ...List.generate(5, (index) => Icon(index < rating.round() ? Icons.star : Icons.star_border, size: 16 * scale, color: Colors.amber.shade600)),
                  SizedBox(width: 6 * scale),
                  Text('$rating ($reviewCount)', style: TextStyle(fontSize: 13 * scale, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          SizedBox(height: 16 * scale),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Bs ${double.parse(price).toStringAsFixed(0)}',
                style: TextStyle(fontSize: 34 * scale, fontWeight: FontWeight.bold, color: scheme.primary),
              ),
              SizedBox(width: 6 * scale),
              Text('/ $unit', style: TextStyle(fontSize: 15 * scale, color: scheme.onSurfaceVariant)),
              if (hasDiscount) ...[
                SizedBox(width: 12 * scale),
                Text(
                  hasDiscount ? 'Bs ${double.parse(originalPrice!).toStringAsFixed(0)}' : '',
                  style: TextStyle(fontSize: 17 * scale, color: scheme.onSurfaceVariant.withValues(alpha: 0.65), decoration: TextDecoration.lineThrough),
                ),
              ],
            ],
          ),
          SizedBox(height: 10 * scale),
          _buildSellerBadge(product, scale),
          if (stock > 0 && stock < 10) ...[
            SizedBox(height: 12 * scale),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
              decoration: BoxDecoration(
                color: scheme.brightness == Brightness.dark
                    ? Colors.orange.withValues(alpha: 0.22)
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8 * scale),
              ),
              child: Text(
                stock == 1 ? '¡Solo queda el último!' : '¡Solo quedan $stock!',
                style: TextStyle(
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w500,
                  color: scheme.brightness == Brightness.dark ? Colors.orange.shade200 : Colors.orange.shade700,
                ),
              ),
            ),
          ],
          SizedBox(height: 10 * scale),
          Divider(height: 1, thickness: 1, color: scheme.outline.withValues(alpha: 0.35)),
        ],
      ),
    );
  }

  Widget _buildSellerBadge(Map<String, dynamic> product, double scale) {
    final seller = product['profiles'];
    String? shopName;
    String? fullName;
    String? email;
    if (seller is Map) {
      shopName = seller['shop_name']?.toString().trim();
      fullName = seller['full_name']?.toString().trim();
      email = seller['email']?.toString().trim();
    }

    final lowerEmail = email?.toLowerCase() ?? '';
    final lowerShop = shopName?.toLowerCase() ?? '';
    final isEveta = lowerEmail == 'evetashop@gmail.com' || lowerShop.contains('eveta');
    final label = (shopName?.isNotEmpty == true)
        ? shopName!
        : (fullName?.isNotEmpty == true ? fullName! : (isEveta ? 'eVeta' : 'Vendedor'));

    final String? sellerId = product['seller_id']?.toString();
    final canOpen = sellerId != null && sellerId.isNotEmpty;

    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: canOpen
          ? () {
              final sid = sellerId;
              if (sid.isEmpty) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SellerStoreScreen(sellerId: sid),
                ),
              );
            }
          : null,
      child: Row(
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 15 * scale,
            color: scheme.onSurfaceVariant,
          ),
          SizedBox(width: 6 * scale),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12 * scale,
                color: scheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Heurística: textos largos o muchas líneas merecen «Ver más» / «Ver menos».
  bool _descriptionNeedsExpandToggle(String description) {
    final d = description.trim();
    if (d.isEmpty) return false;
    final lines = d.replaceAll('\r\n', '\n').split('\n').length;
    if (lines > 5) return true;
    if (d.length > 260) return true;
    return false;
  }

  Widget _buildDescriptionSection(
    String description,
    List<String> tags,
    double scale,
    ValueChanged<String>? onTagTap,
    Map<String, dynamic> product,
  ) {
    final specBlocks = _specRowsForProduct(product);
    final hasSpecs = specBlocks.rows.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    final canvas = _detailCanvasColor(scheme);

    return Container(
      width: double.infinity,
      color: canvas,
      padding: EdgeInsets.all(20 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Descripción',
            style: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.bold, color: scheme.onSurface),
          ),
          SizedBox(height: 10 * scale),
          if (description.trim().isEmpty)
            Text(
              'Sin descripción',
              style: TextStyle(fontSize: 14 * scale, color: scheme.onSurfaceVariant.withValues(alpha: 0.8), height: 1.6),
            )
          else ...[
            Text(
              description,
              style: TextStyle(fontSize: 14 * scale, color: scheme.onSurfaceVariant, height: 1.6),
              maxLines: _descriptionExpanded ? null : 5,
              overflow: _descriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (_descriptionNeedsExpandToggle(description)) ...[
              SizedBox(height: 8 * scale),
              Center(
                child: InkWell(
                  onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
                  borderRadius: BorderRadius.circular(20 * scale),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _descriptionExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 22 * scale,
                          color: scheme.primary,
                        ),
                        SizedBox(width: 6 * scale),
                        Text(
                          _descriptionExpanded ? 'Ver menos' : 'Ver más',
                          style: TextStyle(
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (tags.isNotEmpty) ...[
            SizedBox(height: 18 * scale),
            Wrap(
              spacing: 8 * scale,
              runSpacing: 10 * scale,
              children: tags.map((tag) {
                return GestureDetector(
                  onTap: () => onTagTap?.call(tag),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 6 * scale),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20 * scale),
                      border: Border.all(color: scheme.primary.withValues(alpha: 0.7)),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(fontSize: 12 * scale, color: scheme.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 14 * scale),
          ],
          if (hasSpecs) ...[
            SizedBox(height: (tags.isNotEmpty ? 6 : 20) * scale),
            Text(
              _specSectionHeading(product, specBlocks.fromJsonTemplate),
              style: TextStyle(
                fontSize: 14 * scale,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            SizedBox(height: 10 * scale),
            ...specBlocks.rows.asMap().entries.map((e) => _buildSpecRow(
                  label: e.value.key,
                  body: e.value.value,
                  index: e.key,
                  total: specBlocks.rows.length,
                  scale: scale,
                )),
          ],
          SizedBox(height: 16 * scale),
          Divider(height: 1, thickness: 1, color: scheme.outline.withValues(alpha: 0.35)),
        ],
      ),
    );
  }

  String _specSectionHeading(Map<String, dynamic> product, bool fromJsonTemplate) {
    if (fromJsonTemplate) {
      final cat = product['categories'];
      if (cat is Map) {
        final t = cat['spec_group_title']?.toString().trim();
        if (t != null && t.isNotEmpty) return t;
      }
    }
    return 'Detalles del producto';
  }

  /// Filas con texto no vacío; apartados sin rellenar no se muestran.
  ({List<MapEntry<String, String>> rows, bool fromJsonTemplate}) _specRowsForProduct(Map<String, dynamic> product) {
    final rows = <MapEntry<String, String>>[];
    var fromJson = false;
    final rawSpecs = product['specs_json'];
    if (rawSpecs is List) {
      for (final e in rawSpecs) {
        if (e is! Map) continue;
        final label = e['label']?.toString().trim() ?? '';
        final value = e['value']?.toString().trim() ?? '';
        if (value.isEmpty) continue;
        fromJson = true;
        final displayLabel = label.isEmpty ? 'Detalle' : label;
        rows.add(MapEntry(displayLabel, value));
      }
    }
    void addLegacy(String label, Object? raw) {
      if (raw == null) return;
      final v = '$raw'.trim();
      if (v.isEmpty) return;
      rows.add(MapEntry(label, v));
    }

    addLegacy('Peso', product['weight']);
    addLegacy('Dimensiones', product['dimensions']);
    addLegacy('Material', product['material']);
    addLegacy('Color', product['color']);
    addLegacy('Marca', product['brand']);
    addLegacy('Modelo', product['model']);
    addLegacy('Garantía', product['warranty']);

    return (rows: rows, fromJsonTemplate: fromJson);
  }

  Widget _buildSpecRow({
    required String label,
    required String body,
    required int index,
    required int total,
    required double scale,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final canvas = _detailCanvasColor(scheme);
    return Container(
      width: double.infinity,
      color: canvas,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 9 * scale),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 108 * scale,
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11 * scale,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Text(
                    body,
                    style: TextStyle(
                      fontSize: 12 * scale,
                      color: scheme.onSurface,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (index < total - 1)
            Divider(height: 1, thickness: 1, color: scheme.outline.withValues(alpha: 0.25)),
        ],
      ),
    );
  }

  Widget _buildRelatedProducts(double scale) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _relatedProductsFuture,
      builder: (context, snapshot) {
        final scheme = Theme.of(context).colorScheme;
        final canvas = _detailCanvasColor(scheme);
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: EdgeInsets.only(top: 16 * scale),
            padding: EdgeInsets.fromLTRB(
              EvetaShopDimens.spaceLg,
              16 * scale,
              EvetaShopDimens.spaceLg,
              24 * scale,
            ),
            color: canvas,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Productos Relacionados', style: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.bold, color: scheme.onSurface)),
                SizedBox(height: 12 * scale),
                MasonryGridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: EvetaShopDimens.spaceMd,
                  crossAxisSpacing: EvetaShopDimens.spaceMd,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      height: 220 * scale,
                      child: const ProductCardSkeleton(),
                    );
                  },
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final products = snapshot.data!;
        return Container(
          margin: EdgeInsets.only(top: 16 * scale),
          padding: EdgeInsets.fromLTRB(
            EvetaShopDimens.spaceLg,
            16 * scale,
            EvetaShopDimens.spaceLg,
            24 * scale,
          ),
          color: canvas,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Productos Relacionados', style: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.bold, color: scheme.onSurface)),
              SizedBox(height: 12 * scale),
              MasonryGridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: EvetaShopDimens.spaceMd,
                crossAxisSpacing: EvetaShopDimens.spaceMd,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return LayoutBuilder(
                    builder: (context, c) {
                      return EvetaNewArrivalCard(
                        width: c.maxWidth,
                        product: product,
                        showNewBadge: false,
                        adaptProductImageFraming: true,
                        flexibleImageSlot: true,
                        onTap: () {
                          final id = product['id']?.toString() ?? '';
                          if (id.isEmpty) return;
                          if (widget.onRelatedProductTap != null) {
                            widget.onRelatedProductTap!(id);
                          } else {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ProductDetailScreen(productId: id),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(bool isOutOfStock, Map<String, dynamic> product, double scale) {
    final scheme = Theme.of(context).colorScheme;
    final canvas = _detailCanvasColor(scheme);
    final onPrimary = scheme.onPrimary;
    final primary = scheme.primary;
    return Container(
      padding: EdgeInsets.fromLTRB(16 * scale, 12 * scale, 16 * scale, MediaQuery.of(context).padding.bottom + 12 * scale),
      decoration: BoxDecoration(
        color: canvas,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Container(
            height: 50 * scale,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(25 * scale),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove, size: 20 * scale),
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  color: _quantity > 1 ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.35),
                  splashRadius: 24,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 40 * scale, minHeight: 40 * scale),
                ),
                Container(
                  width: 32 * scale,
                  alignment: Alignment.center,
                  child: Text('$_quantity', style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: scheme.onSurface)),
                ),
                IconButton(
                  icon: Icon(Icons.add, size: 20 * scale),
                  onPressed: _quantity < (product['stock'] ?? 0)
                      ? () => setState(() => _quantity++)
                      : null,
                  color: _quantity < (product['stock'] ?? 0) ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.35),
                  splashRadius: 24,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 40 * scale, minHeight: 40 * scale),
                ),
              ],
            ),
          ),
          SizedBox(width: 16 * scale),
          Expanded(
            child: SizedBox(
              height: 50 * scale,
              child: ElevatedButton(
                onPressed: isOutOfStock ? null : () => _addToCart(product),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOutOfStock ? scheme.surfaceContainerHighest : primary,
                  foregroundColor: isOutOfStock ? scheme.onSurfaceVariant : onPrimary,
                  disabledBackgroundColor: scheme.surfaceContainerHighest,
                  disabledForegroundColor: scheme.onSurfaceVariant,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25 * scale)),
                  elevation: isOutOfStock ? 0 : 4,
                  shadowColor: primary.withValues(alpha: 0.4),
                ),
                child: _isAddingToCart
                    ? SizedBox(width: 24 * scale, height: 24 * scale, child: CircularProgressIndicator(strokeWidth: 2.5, color: onPrimary))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 22 * scale, color: isOutOfStock ? scheme.onSurfaceVariant : onPrimary),
                          SizedBox(width: 8 * scale),
                          Text(
                            isOutOfStock ? 'Agotado' : 'Agregar',
                            style: TextStyle(
                              fontSize: 16 * scale,
                              fontWeight: FontWeight.w600,
                              color: isOutOfStock ? scheme.onSurfaceVariant : onPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
