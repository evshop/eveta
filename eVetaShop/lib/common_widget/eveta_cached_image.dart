import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';

/// Imagen en red con caché en disco y URL optimizada (Cloudinary).
class EvetaCachedImage extends StatelessWidget {
  const EvetaCachedImage({
    super.key,
    required this.imageUrl,
    required this.delivery,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholderColor,
    this.errorIconSize = 40,
  });

  final String imageUrl;
  final EvetaImageDelivery delivery;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Color? placeholderColor;
  final double errorIconSize;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return ColoredBox(
        color: placeholderColor ?? Colors.grey.shade100,
        child: Icon(Icons.image_not_supported, size: errorIconSize, color: Colors.grey.shade400),
      );
    }
    final url = evetaImageDeliveryUrl(imageUrl, delivery);
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: Duration.zero,
      placeholder: (context, _) => ColoredBox(
        color: placeholderColor ?? Colors.grey.shade100,
      ),
      errorWidget: (context, u, e) => ColoredBox(
        color: Colors.grey.shade100,
        child: Icon(Icons.image_not_supported, size: errorIconSize, color: Colors.grey.shade400),
      ),
    );
  }
}
