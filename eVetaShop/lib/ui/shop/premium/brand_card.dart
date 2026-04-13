import 'package:flutter/material.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

/// Tarjeta horizontal tipo “marca / tienda” para carruseles premium.
class BrandCard extends StatelessWidget {
  const BrandCard({
    super.key,
    required this.name,
    this.imageUrl,
    required this.onTap,
    this.width = 92,
    /// Si no es null, la tarjeta ocupa esta altura: el avatar queda centrado arriba y el nombre abajo.
    this.cardHeight,
  });

  final String name;
  final String? imageUrl;
  final VoidCallback onTap;
  final double width;
  final double? cardHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = imageUrl?.trim() ?? '';

    final avatar = CircleAvatar(
      radius: 26,
      backgroundColor: scheme.surfaceContainerHigh,
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary, fontSize: 18),
            )
          : null,
    );

    final title = Text(
      name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
        height: 1.2,
      ),
    );

    Widget content() {
      if (cardHeight == null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceSm, vertical: EvetaShopDimens.spaceMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              avatar,
              const SizedBox(height: 8),
              title,
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(EvetaShopDimens.spaceSm, 6, EvetaShopDimens.spaceSm, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Center(child: avatar),
            ),
            title,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: EvetaShopDimens.spaceMd),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
          child: SizedBox(
            width: width,
            height: cardHeight,
            child: content(),
          ),
        ),
      ),
    );
  }
}
