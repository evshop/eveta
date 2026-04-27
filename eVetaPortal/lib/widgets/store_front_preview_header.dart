import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'portal_cached_image.dart';

/// Misma composición visual que la cabecera de tienda en eVetaShop ([_StoreScrollHeader]).
class StoreFrontPreviewHeader extends StatelessWidget {
  const StoreFrontPreviewHeader({
    super.key,
    required this.bannerUrl,
    required this.logoUrl,
    this.bannerBytes,
    this.logoBytes,
    required this.shopName,
    required this.shopDescription,
    this.logoBorderColor,
    required this.scale,
    this.onBannerTap,
    this.onLogoTap,
    this.onInfoTap,
  });

  final String? bannerUrl;
  final String? logoUrl;
  final Uint8List? bannerBytes;
  final Uint8List? logoBytes;
  final String shopName;
  final String shopDescription;
  final Color? logoBorderColor;
  final double scale;
  final VoidCallback? onBannerTap;
  final VoidCallback? onLogoTap;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = logoBorderColor ?? scheme.primary;
    final bannerH = 196.0 * scale;
    final headerH = 304.0 * scale;
    final surface = scheme.surface;
    final b = bannerUrl?.trim() ?? '';
    final l = logoUrl?.trim() ?? '';
    final hasBannerBytes = bannerBytes != null && bannerBytes!.isNotEmpty;
    final hasLogoBytes = logoBytes != null && logoBytes!.isNotEmpty;

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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBannerTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    hasBannerBytes
                        ? Image.memory(
                            bannerBytes!,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                          )
                        : (b.isNotEmpty
                            ? PortalCachedImage(
                                imageUrl: b,
                                fit: BoxFit.cover,
                                memCacheWidth: 1280,
                              )
                            : ColoredBox(color: scheme.surfaceContainerHigh)),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              surface.withValues(alpha: 0.12),
                              surface.withValues(alpha: 0.55),
                              surface,
                            ],
                            stops: const [0.0, 0.38, 0.62, 0.88, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: bannerH,
            bottom: 0,
            child: ColoredBox(color: surface),
          ),
          Positioned(
            left: 16 * scale,
            right: 16 * scale,
            top: 188 * scale,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onLogoTap,
                    child: l.isNotEmpty
                        ? Container(
                            width: 62 * scale,
                            height: 62 * scale,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.surfaceContainerHighest,
                              border: Border.all(color: borderColor, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: hasLogoBytes
                                  ? Image.memory(
                                      logoBytes!,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.medium,
                                    )
                                  : PortalCachedImage(
                                      imageUrl: l,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 300,
                                    ),
                            ),
                          )
                        : Container(
                            width: 62 * scale,
                            height: 62 * scale,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                              border: Border.all(color: borderColor, width: 2),
                            ),
                            child: Icon(Icons.storefront_outlined, color: scheme.onSurfaceVariant),
                          ),
                  ),
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12 * scale),
                      onTap: onInfoTap,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4 * scale, horizontal: 4 * scale),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              shopName.isEmpty ? 'Nombre de tienda' : shopName,
                              style: TextStyle(
                                fontSize: 18 * scale,
                                fontWeight: FontWeight.w700,
                                color: shopName.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface,
                              ),
                              maxLines: 2,
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
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ] else
                              Padding(
                                padding: EdgeInsets.only(top: 4 * scale),
                                child: Text(
                                  'Toca para añadir descripción',
                                  style: TextStyle(
                                    fontSize: 12 * scale,
                                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
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
