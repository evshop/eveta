import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:eveta/common_widget/bottom_nav_bar_widget.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/product_map_ui.dart';
import 'package:eveta/utils/cart_animation_helper.dart';
import 'package:eveta/utils/cart_service.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';
import 'package:eveta/utils/favorites_service.dart';

/// Tarjeta horizontal para la sección «Nuevas llegadas»: imagen protagonista, badge Nuevo, precio claro.
class EvetaNewArrivalCard extends StatefulWidget {
  const EvetaNewArrivalCard({
    super.key,
    required this.product,
    this.width = 168,
    this.onTap,
    this.showNewBadge = true,
    /// En «Populares»: siempre [BoxFit.cover] (sin bandas vacías a los lados); alineación según ratio (vertical → arriba).
    this.adaptProductImageFraming = false,
    /// Con [SliverMasonryGrid]: la franja de imagen crece o encoge según el ratio (entre [minFlexibleImageHeight] y [maxFlexibleImageHeight]).
    this.flexibleImageSlot = false,
  });

  /// Altura de referencia para listas con altura fija (sin [flexibleImageSlot]).
  static const double gridMainAxisExtent = 226;
  static const double minFlexibleImageHeight = 76;
  static const double maxFlexibleImageHeight = 198;

  final Map<String, dynamic> product;
  final double width;
  final VoidCallback? onTap;
  /// En «Recomendado para ti» va en false para mismo layout sin chip «Nuevo».
  final bool showNewBadge;
  final bool adaptProductImageFraming;
  final bool flexibleImageSlot;

  @override
  State<EvetaNewArrivalCard> createState() => _EvetaNewArrivalCardState();
}

class _EvetaNewArrivalCardState extends State<EvetaNewArrivalCard> {
  static const double _imgHeight = 118;
  static const double _radius = 20;

  final GlobalKey _imageKey = GlobalKey();
  bool _favorite = false;
  bool _favLoaded = false;
  double _imageSlotHeight = _imgHeight;

  @override
  void initState() {
    super.initState();
    _loadFav();
  }

  @override
  void didUpdateWidget(covariant EvetaNewArrivalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product['id']?.toString() != widget.product['id']?.toString()) {
      _imageSlotHeight = _imgHeight;
      _loadFav();
    }
  }

  void _onImageNaturalSize(double iw, double ih) {
    if (!mounted || !widget.flexibleImageSlot || ih <= 0 || iw <= 0) return;
    final portrait = iw < ih;
    final maxH = portrait ? 252.0 : EvetaNewArrivalCard.maxFlexibleImageHeight;
    final h = (widget.width * ih / iw).clamp(
      EvetaNewArrivalCard.minFlexibleImageHeight,
      maxH,
    );
    if ((h - _imageSlotHeight).abs() < 0.5) return;
    setState(() => _imageSlotHeight = h);
  }

  Future<void> _loadFav() async {
    final id = widget.product['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final v = await FavoritesService.isFavorite(id);
    if (mounted) {
      setState(() {
        _favorite = v;
        _favLoaded = true;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final item = FavoriteItem.fromProductMap(widget.product);
    final now = await FavoritesService.toggleFavorite(item);
    if (mounted) setState(() => _favorite = now);
  }

  void _addToCart(BuildContext context) {
    final id = widget.product['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final name = widget.product['name']?.toString() ?? '';
    final price = widget.product['price']?.toString() ?? '0';
    final url = primaryProductImageUrl(widget.product);
    final stock = productStock(widget.product);

    CartService.addToCart(CartItem(
      productId: id,
      name: name,
      price: price,
      imageUrl: url,
      quantity: 1,
      stock: stock,
    ));

    final flyChild = SizedBox(
      width: 52,
      height: 52,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
        child: url.isNotEmpty
            ? EvetaCachedImage(
                imageUrl: url,
                delivery: EvetaImageDelivery.thumb,
                fit: BoxFit.cover,
                memCacheWidth: 200,
              )
            : Icon(Icons.shopping_cart_outlined, color: Theme.of(context).colorScheme.primary),
      ),
    );

    CartAnimationHelper.runFlyToCartAnimation(
      context: context,
      sourceKey: _imageKey,
      destKey: BottomNavBarWidget.cartKey,
      child: flyChild,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = widget.product['name']?.toString() ?? 'Producto';
    final price = widget.product['price']?.toString();
    final original = widget.product['original_price']?.toString();
    final discount = computeDiscountPercent(price, original);
    final url = primaryProductImageUrl(widget.product);
    final featured = widget.product['is_featured'] == true;
    final stock = productStock(widget.product);
    final isLight = scheme.brightness == Brightness.light;

    final borderColor = scheme.outline.withValues(alpha: isLight ? 0.14 : 0.38);
    final cardBg = scheme.surfaceContainerHighest;
    final rr = BorderRadius.circular(_radius);
    final imageH = widget.flexibleImageSlot ? _imageSlotHeight : _imgHeight;

    // [PhysicalModel] aplica sombra ya recortada al mismo radio en las 4 esquinas (sin manchas cuadradas).
    final inner = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: rr,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: rr,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: ClipRRect(
            borderRadius: rr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  key: _imageKey,
                  height: imageH,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                scheme.surfaceContainerHigh,
                                scheme.surfaceContainer.withValues(alpha: 0.92),
                              ],
                            ),
                          ),
                          child: url.isNotEmpty
                              ? _ArrivalCardImage(
                                  imageUrl: url,
                                  adaptFraming: widget.adaptProductImageFraming,
                                  memCacheWidth: 480,
                                  onDecodedSize: widget.flexibleImageSlot ? _onImageNaturalSize : null,
                                )
                              : Center(
                                  child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant, size: 42),
                                ),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.02),
                                Colors.black.withValues(alpha: 0.12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (widget.showNewBadge || featured)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.showNewBadge)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: EvetaShopColors.brand,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: EvetaShopColors.brand.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.white),
                                      SizedBox(width: 5),
                                      Text(
                                        'Nuevo',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (widget.showNewBadge && featured) const SizedBox(width: 6),
                            if (featured)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'TOP',
                                  style: TextStyle(
                                    color: scheme.onPrimaryContainer,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (discount != null && discount > 0)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: scheme.error,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '-$discount%',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: isLight
                            ? Colors.white.withValues(alpha: 0.94)
                            : scheme.surfaceContainerHigh.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        elevation: isLight ? 1 : 0,
                        shadowColor: Colors.black26,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          onPressed: _favLoaded ? _toggleFavorite : null,
                          icon: Icon(
                            _favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 20,
                            color: _favorite ? EvetaShopColors.brand : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.18,
                        letterSpacing: -0.2,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatBs(price),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (original != null &&
                                  original.isNotEmpty &&
                                  discount != null &&
                                  discount > 0)
                                Text(
                                  formatBs(original),
                                  style: TextStyle(
                                    fontSize: 11,
                                    decoration: TextDecoration.lineThrough,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Material(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: stock > 0 ? () => _addToCart(context) : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(7),
                              child: Icon(
                                Icons.shopping_cart_outlined,
                                size: 19,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      width: widget.width,
      child: PhysicalModel(
        borderRadius: rr,
        elevation: isLight ? 2 : 5,
        color: cardBg,
        shadowColor: Colors.black.withValues(alpha: isLight ? 0.14 : 0.42),
        child: inner,
      ),
    );
  }
}

/// Capa de imagen: sin adaptación usa [EvetaCachedImage] + cover; con adaptación ajusta [BoxFit] y [Alignment] al ratio.
class _ArrivalCardImage extends StatefulWidget {
  const _ArrivalCardImage({
    required this.imageUrl,
    required this.adaptFraming,
    required this.memCacheWidth,
    this.onDecodedSize,
  });

  final String imageUrl;
  final bool adaptFraming;
  final int memCacheWidth;
  final void Function(double iw, double ih)? onDecodedSize;

  @override
  State<_ArrivalCardImage> createState() => _ArrivalCardImageState();
}

class _ArrivalCardImageState extends State<_ArrivalCardImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _listener;
  Alignment _alignment = Alignment.center;

  @override
  void initState() {
    super.initState();
    _bindAspectStream();
  }

  @override
  void didUpdateWidget(covariant _ArrivalCardImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.adaptFraming != widget.adaptFraming ||
        oldWidget.onDecodedSize != widget.onDecodedSize) {
      _unbindAspectStream();
      _alignment = Alignment.center;
      _bindAspectStream();
    }
  }

  void _bindAspectStream() {
    if (widget.imageUrl.isEmpty) return;
    if (!widget.adaptFraming && widget.onDecodedSize == null) return;
    final resolved = evetaImageDeliveryUrl(widget.imageUrl, EvetaImageDelivery.card);
    final provider = CachedNetworkImageProvider(resolved);
    final stream = provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final iw = info.image.width.toDouble();
        final ih = info.image.height.toDouble();
        if (!mounted || ih <= 0 || iw <= 0) return;
        widget.onDecodedSize?.call(iw, ih);
        if (!widget.adaptFraming) return;
        final r = iw / ih;
        // Siempre cover: el ancho del hueco queda tapado al 100 % (nada vacío a los lados).
        final align = r < 1 ? Alignment.topCenter : Alignment.center;
        setState(() => _alignment = align);
      },
      onError: (Object _, StackTrace? __) {},
    );
    stream.addListener(_listener!);
    _imageStream = stream;
  }

  void _unbindAspectStream() {
    final s = _imageStream;
    final l = _listener;
    if (s != null && l != null) {
      s.removeListener(l);
    }
    _imageStream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _unbindAspectStream();
    super.dispose();
  }

  String get _resolvedUrl => evetaImageDeliveryUrl(widget.imageUrl, EvetaImageDelivery.card);

  @override
  Widget build(BuildContext context) {
    if (!widget.adaptFraming) {
      return EvetaCachedImage(
        imageUrl: widget.imageUrl,
        delivery: EvetaImageDelivery.card,
        fit: BoxFit.cover,
        memCacheWidth: widget.memCacheWidth,
      );
    }
    return CachedNetworkImage(
      imageUrl: _resolvedUrl,
      fit: BoxFit.cover,
      alignment: _alignment,
      memCacheWidth: widget.memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: Duration.zero,
      placeholder: (context, _) => const ColoredBox(color: Colors.transparent),
      errorWidget: (context, url, e) => ColoredBox(
        color: Colors.grey.shade100,
        child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey.shade400),
      ),
    );
  }
}
