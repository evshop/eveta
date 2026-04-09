import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/screens/product_detail_screen.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';
import 'package:eveta/utils/page_transitions.dart';
import 'package:eveta/utils/cart_service.dart';
import 'package:eveta/utils/cart_animation_helper.dart';
import 'package:eveta/common_widget/bottom_nav_bar_widget.dart';

class GridTilesProducts extends StatefulWidget {
  const GridTilesProducts({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.slug,
    this.price,
    this.originalPrice,
    this.discount,
    this.isBestSeller = false,
    this.stock = 1,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.shopName,
    this.freeShipping = false,
    this.onTap,
    this.isTwoLineMode = false,
    this.portraitImageExtraHeight = 0,
    this.expandToMaxHeight = false,
  });

  /// Suma altura (px) al bloque de imagen cuando la foto es muy vertical (p. ej. inicio).
  /// Queda acotado en el propio widget.
  final double portraitImageExtraHeight;

  /// Si es true y el padre da altura de fila (p. ej. [IntrinsicHeight] en inicio), solo crece el bloque de imagen;
  /// título y precio quedan pegados abajo sin hueco blanco debajo del precio.
  final bool expandToMaxHeight;

  final String name;
  final String imageUrl;
  final String slug;
  final String? price;
  final String? originalPrice;
  final int? discount;
  final bool isBestSeller;
  final int stock;
  final double rating;
  final int reviewCount;
  final String? shopName;
  final bool freeShipping;
  final VoidCallback? onTap;
  final bool isTwoLineMode;

  @override
  State<GridTilesProducts> createState() => _GridTilesProductsState();
}

class _GridTilesProductsState extends State<GridTilesProducts> {
  final GlobalKey _cardKey = GlobalKey();

  void _onAddToCart() {
    CartService.addToCart(CartItem(
      productId: widget.slug,
      name: widget.name,
      price: widget.price ?? '0',
      imageUrl: widget.imageUrl,
      quantity: 1,
      stock: widget.stock,
    ));

    // Thumbnail cuadrado para la animación
    final Widget flyChild = SizedBox(
      width: 60,
      height: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: widget.imageUrl.isNotEmpty
            ? EvetaCachedImage(
                imageUrl: widget.imageUrl,
                delivery: EvetaImageDelivery.thumb,
                fit: BoxFit.cover,
                memCacheWidth: 200,
              )
            : const Icon(Icons.shopping_cart, color: Color(0xFF09CB6B)),
      ),
    );

    CartAnimationHelper.runFlyToCartAnimation(
      context: context,
      sourceKey: _cardKey,
      destKey: BottomNavBarWidget.cartKey,
      child: flyChild,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = widget.stock == 0;
    final bool hasDiscount = widget.originalPrice != null && widget.discount != null && widget.discount! > 0;
    final imageBlockHeight = (130.0 + widget.portraitImageExtraHeight.clamp(0.0, 62.0)).clamp(130.0, 200.0);

    final meta = Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.isTwoLineMode
              ? Text(
                  widget.name,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : SizedBox(
                  height: 18,
                  child: widget.name.length > 15
                      ? Marquee(
                          text: widget.name,
                          style: const TextStyle(
                            color: Color(0xFF333333),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          scrollAxis: Axis.horizontal,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          blankSpace: 20.0,
                          velocity: 30.0,
                          pauseAfterRound: const Duration(seconds: 1),
                          startPadding: 0.0,
                          accelerationDuration: const Duration(seconds: 1),
                          accelerationCurve: Curves.linear,
                          decelerationDuration: const Duration(milliseconds: 500),
                          decelerationCurve: Curves.easeOut,
                        )
                      : Text(
                          widget.name,
                          style: const TextStyle(
                            color: Color(0xFF333333),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
          const SizedBox(height: 4),
          Divider(
            color: Colors.grey.shade300,
            thickness: 0.5,
          ),
          const SizedBox(height: 4),
          if (hasDiscount) ...[
            Text(
              'Bs ${double.parse(widget.originalPrice!).toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            widget.price != null ? 'Bs ${double.parse(widget.price!).toStringAsFixed(0)}' : 'Precio N/A',
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    final imageOverlays = <Widget>[
      if (widget.isBestSeller)
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.shade600,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Más vendido',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      if (isOutOfStock)
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(
              child: Text(
                'AGOTADO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      if (!isOutOfStock)
        Positioned(
          bottom: 6,
          right: 6,
          child: GestureDetector(
            onTap: _onAddToCart,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: Color(0xFF09CB6B),
                size: 18,
              ),
            ),
          ),
        ),
    ];

    final column = widget.expandToMaxHeight
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: imageBlockHeight),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: EvetaCachedImage(
                          imageUrl: widget.imageUrl,
                          delivery: EvetaImageDelivery.card,
                          fit: BoxFit.cover,
                          memCacheWidth: 480,
                          errorIconSize: 40,
                        ),
                      ),
                      ...imageOverlays,
                    ],
                  ),
                ),
              ),
              meta,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: imageBlockHeight,
                child: Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: EvetaCachedImage(
                        imageUrl: widget.imageUrl,
                        delivery: EvetaImageDelivery.card,
                        fit: BoxFit.cover,
                        memCacheWidth: 480,
                        errorIconSize: 40,
                      ),
                    ),
                    ...imageOverlays,
                  ],
                ),
              ),
              meta,
            ],
          );

    return InkWell(
      onTap: widget.onTap ?? () {
        Navigator.push(
          context,
          SlideUpPageRoute(
            builder: (context) => ProductDetailScreen(productId: widget.slug),
          ),
        );
      },
      child: widget.expandToMaxHeight
          ? SizedBox.expand(
              child: Container(
                key: _cardKey,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300, width: 0.5),
                ),
                child: column,
              ),
            )
          : Container(
              key: _cardKey,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 0.5),
              ),
              child: column,
            ),
    );
  }
}