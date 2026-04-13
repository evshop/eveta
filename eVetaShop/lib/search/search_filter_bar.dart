import 'package:flutter/material.dart';

import 'package:eveta/search/product_search_controller.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

/// Barra de búsqueda redondeada con lupa, limpiar y acceso a filtros.
class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({
    super.key,
    required this.controller,
    required this.onOpenFilters,
    this.hintText = 'Productos o tiendas…',
  });

  final ProductSearchController controller;
  final VoidCallback onOpenFilters;
  final String hintText;

  static const double _radius = 26;

  Color _fieldFill(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) return const Color(0xFF2C2C2E);
    return const Color(0xFFF2F2F2);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final listenable = Listenable.merge([
      controller.focusNode,
      controller.textController,
      controller,
    ]);

    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final focused = controller.focusNode.hasFocus;
        final hasText = controller.textController.text.isNotEmpty;
        final showBadge = controller.filters.hasActiveFilters(controller.priceSliderMax);

        return Row(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: _fieldFill(context),
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(
                    color: focused
                        ? scheme.primary.withValues(alpha: 0.45)
                        : scheme.outline.withValues(alpha: 0.08),
                    width: focused ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: focused ? 0.09 : 0.05),
                      blurRadius: focused ? 14 : 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_radius),
                  child: TextField(
                    controller: controller.textController,
                    focusNode: controller.focusNode,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      fontSize: 15,
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: scheme.onSurfaceVariant,
                        size: 24,
                      ),
                      suffixIcon: hasText
                          ? IconButton(
                              tooltip: 'Limpiar',
                              icon: Icon(
                                Icons.close_rounded,
                                size: 22,
                                color: scheme.onSurfaceVariant,
                              ),
                              onPressed: controller.clearText,
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: EvetaShopColors.brand.withValues(alpha: 0.12),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onOpenFilters,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.tune_rounded,
                        color: EvetaShopColors.brand,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                if (showBadge)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _fieldFill(context),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
