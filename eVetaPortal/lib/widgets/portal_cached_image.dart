import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Imagen de red con caché en disco y memoria ([CachedNetworkImage]).
/// La misma URL reutiliza bytes locales → menos ancho de banda hacia Cloudinary.
class PortalCachedImage extends StatelessWidget {
  const PortalCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholderColor,
    this.errorIconSize = 40,
    this.maxWidthDiskCache = 1600,
    this.maxHeightDiskCache = 1600,
  });

  final String imageUrl;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Color? placeholderColor;
  final double errorIconSize;
  final int maxWidthDiskCache;
  final int maxHeightDiskCache;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ph = placeholderColor ?? scheme.surfaceContainerHigh;
    final errBg = scheme.surfaceContainerHigh;
    final errIcon = scheme.onSurfaceVariant;

    if (imageUrl.isEmpty) {
      return ColoredBox(
        color: ph,
        child: Icon(Icons.image_not_supported, size: errorIconSize, color: scheme.outline),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: maxWidthDiskCache,
      maxHeightDiskCache: maxHeightDiskCache,
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: Duration.zero,
      placeholder: (context, _) => ColoredBox(color: ph),
      errorWidget: (context, Object url, Object error) => ColoredBox(
        color: errBg,
        child: Icon(Icons.broken_image_outlined, size: errorIconSize, color: errIcon),
      ),
    );
  }
}
