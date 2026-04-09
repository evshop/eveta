import 'package:flutter/material.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

/// Buscador tipo marketplace: pill, solo lectura hasta abrir pantalla de búsqueda.
class EvetaSearchBar extends StatelessWidget {
  const EvetaSearchBar({
    super.key,
    required this.onTap,
    this.hintText = 'Buscar productos, marcas…',
    this.controller,
    this.readOnly = true,
    this.onChanged,
  });

  final VoidCallback? onTap;
  final String hintText;
  final TextEditingController? controller;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(EvetaShopDimens.radiusXl + 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EvetaShopDimens.radiusXl + 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceLg, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(EvetaShopDimens.radiusXl + 4),
            border: Border.all(color: scheme.outline.withValues(alpha: isDark ? 0.35 : 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: scheme.onSurfaceVariant, size: 22),
              const SizedBox(width: EvetaShopDimens.spaceSm),
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: readOnly,
                  onTap: onTap,
                  onChanged: onChanged,
                  style: TextStyle(color: scheme.onSurface, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.75), fontSize: 15),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
