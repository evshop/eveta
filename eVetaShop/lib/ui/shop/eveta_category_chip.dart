import 'package:flutter/material.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

/// Borde cápsula tipo iOS (lista ajustes / segmentos).
Color evetaIosCapsuleBorder(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? const Color(0xFF48484A) : const Color(0xFFC6C6C8);
}

class EvetaCategoryChip extends StatelessWidget {
  const EvetaCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return _CategoryChipBase(
      label: label,
      selected: selected,
      onTap: onTap,
      icon: icon,
      horizontalPadding: EvetaShopDimens.spaceLg,
      verticalPadding: 10,
      fontSize: 13,
      borderRadius: 100,
    );
  }
}

/// Subcategorías: misma cápsula iOS que [EvetaCategoryChip], más compacta.
class SubcategoryChip extends StatelessWidget {
  const SubcategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CategoryChipBase(
      label: label,
      selected: selected,
      onTap: onTap,
      horizontalPadding: 12,
      verticalPadding: 6,
      fontSize: 11.5,
      borderRadius: 100,
    );
  }
}

class _CategoryChipBase extends StatelessWidget {
  const _CategoryChipBase({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.fontSize,
    required this.borderRadius,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = BorderRadius.circular(borderRadius);
    final iosBorder = evetaIosCapsuleBorder(context);
    final borderColor = selected ? scheme.primary : iosBorder;
    final textColor = selected ? scheme.primary : scheme.onSurface;
    final weight = selected ? FontWeight.w700 : FontWeight.w500;

    return Padding(
      padding: const EdgeInsets.only(right: EvetaShopDimens.spaceSm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          splashColor: scheme.primary.withValues(alpha: 0.12),
          highlightColor: scheme.onSurface.withValues(alpha: 0.05),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: r,
              border: Border.all(
                color: borderColor,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: textColor),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: weight,
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
