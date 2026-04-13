import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import 'portal/portal_tokens.dart';
import 'portal_cached_image.dart';

/// Cuadrícula 1:1 con reordenación, portada visible y animación al arrastrar.
class ProductFormImagesGrid extends StatelessWidget {
  const ProductFormImagesGrid({
    super.key,
    required this.images,
    required this.coverUrl,
    required this.isUploading,
    required this.onReorder,
    required this.onRemove,
    required this.onMakeCover,
    required this.onAddTap,
  });

  final List<String> images;
  final String? coverUrl;
  final bool isUploading;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onRemove;
  final void Function(int index) onMakeCover;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    if (images.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aún no agregaste fotos.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
          ),
          const SizedBox(height: PortalTokens.space2),
          _AddPhotoTile(scheme: scheme, isUploading: isUploading, onAddTap: onAddTap),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableGridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: PortalTokens.space1,
          crossAxisSpacing: PortalTokens.space1,
          childAspectRatio: 1,
          onReorder: onReorder,
          dragWidgetBuilderV2: DragWidgetBuilderV2(
            builder: (index, child, _) {
              return Transform.scale(
                scale: 1.04,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
                  shadowColor: Colors.black38,
                  clipBehavior: Clip.antiAlias,
                  child: child,
                ),
              );
            },
          ),
          children: [
            for (var idx = 0; idx < images.length; idx++)
              _ImageTile(
                key: ValueKey<String>(images[idx]),
                url: images[idx],
                isCover: images[idx] == coverUrl,
                scheme: scheme,
                isDark: isDark,
                onRemove: isUploading ? null : () => onRemove(idx),
                onSetCover: () => onMakeCover(idx),
              ),
          ],
        ),
        if (images.length < 10) ...[
          const SizedBox(height: PortalTokens.space2),
          Align(
            alignment: Alignment.centerLeft,
            child: _AddPhotoTile(scheme: scheme, isUploading: isUploading, onAddTap: onAddTap),
          ),
        ],
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({
    required this.scheme,
    required this.isUploading,
    required this.onAddTap,
  });

  final ColorScheme scheme;
  final bool isUploading;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
      child: InkWell(
        onTap: isUploading ? null : onAddTap,
        borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
        splashColor: scheme.primary.withValues(alpha: 0.12),
        child: SizedBox(
          width: 96,
          height: 96,
          child: isUploading
              ? Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: scheme.primary),
                  ),
                )
              : Icon(Icons.add_photo_alternate_rounded, color: scheme.onSurfaceVariant, size: 36),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    super.key,
    required this.url,
    required this.isCover,
    required this.scheme,
    required this.isDark,
    required this.onRemove,
    required this.onSetCover,
  });

  final String url;
  final bool isCover;
  final ColorScheme scheme;
  final bool isDark;
  final VoidCallback? onRemove;
  final VoidCallback onSetCover;

  @override
  Widget build(BuildContext context) {
    final borderColor = isCover ? scheme.primary : scheme.outline.withValues(alpha: isDark ? 0.25 : 0.35);
    final borderW = isCover ? 2.5 : 1.0;

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: scheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(PortalTokens.radiusMd),
                  child: PortalCachedImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
                  border: Border.all(color: borderColor, width: borderW),
                ),
              ),
            ),
            if (isCover)
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_size_select_large_rounded, size: 12, color: scheme.onPrimary),
                      const SizedBox(width: 4),
                      Text(
                        'Portada',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Positioned(
                left: 6,
                bottom: 6,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onSetCover,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.image_outlined, size: 14, color: Colors.white.withValues(alpha: 0.95)),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 4,
              top: 4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
