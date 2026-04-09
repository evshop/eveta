import 'package:flutter/material.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

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
    );
  }
}

/// Chips de subcategoría: misma lógica visual, alineados a la izquierda en el padre; tamaño ligeramente compacto.
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
      horizontalPadding: 10,
      verticalPadding: 4,
      fontSize: 11.5,
      borderRadius: EvetaShopDimens.radiusMd,
      selectedShadowBlur: 6,
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
    this.borderRadius = EvetaShopDimens.radiusXl,
    this.selectedShadowBlur = 10,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;
  final double borderRadius;
  final double selectedShadowBlur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final idleBg = scheme.brightness == Brightness.light ? scheme.surfaceContainerHigh : scheme.surfaceContainerHigh;
    final r = BorderRadius.circular(borderRadius);

    return Padding(
      padding: const EdgeInsets.only(right: EvetaShopDimens.spaceSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: r,
          color: selected ? scheme.primary : idleBg,
          border: Border.all(
            color: selected ? scheme.primary.withValues(alpha: 0.35) : scheme.outline.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.14),
                    blurRadius: selectedShadowBlur,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: r,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 18,
                      color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
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
