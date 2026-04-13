import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Imagen de red con caché en disco (no vuelve a descargar en cada pantalla).
class PortalCachedImage extends StatelessWidget {
  const PortalCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholderColor,
    this.errorIconSize = 40,
  });

  final String imageUrl;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Color? placeholderColor;
  final double errorIconSize;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return ColoredBox(
        color: placeholderColor ?? Colors.grey.shade200,
        child: Icon(Icons.image_not_supported, size: errorIconSize, color: Colors.grey.shade400),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: Duration.zero,
      placeholder: (context, _) => ColoredBox(
        color: placeholderColor ?? Colors.grey.shade200,
      ),
      errorWidget: (context, _, _) => ColoredBox(
        color: Colors.grey.shade200,
        child: Icon(Icons.broken_image_outlined, size: errorIconSize, color: Colors.grey.shade500),
      ),
    );
  }
}
