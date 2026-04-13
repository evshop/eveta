import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:eveta/search/product_search_models.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

List<Map<String, dynamic>> _topLevelCategories(List<Map<String, dynamic>> all) {
  final out = all.where((c) {
    final p = c['parent_id'];
    if (p == null) return true;
    final s = p.toString().trim();
    return s.isEmpty || s == 'null';
  }).toList();
  out.sort((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
  return out;
}

String _formatBs(double v) {
  if (v >= 1000) return 'Bs ${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
  return 'Bs ${v.round()}';
}

/// Bottom sheet iOS/Material 3 para filtros de búsqueda.
class AdvancedSearchFiltersSheet extends StatefulWidget {
  const AdvancedSearchFiltersSheet({
    super.key,
    required this.initial,
    required this.categories,
    required this.priceSliderMax,
  });

  final ProductSearchFilters initial;
  final List<Map<String, dynamic>> categories;
  final double priceSliderMax;

  static Future<ProductSearchFilters?> show(
    BuildContext context, {
    required ProductSearchFilters initial,
    required List<Map<String, dynamic>> categories,
    required double priceSliderMax,
  }) {
    return showModalBottomSheet<ProductSearchFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return AdvancedSearchFiltersSheet(
          initial: initial,
          categories: categories,
          priceSliderMax: priceSliderMax,
        );
      },
    );
  }

  @override
  State<AdvancedSearchFiltersSheet> createState() => _AdvancedSearchFiltersSheetState();
}

class _AdvancedSearchFiltersSheetState extends State<AdvancedSearchFiltersSheet> {
  late String? _categoryId;
  late RangeValues _price;
  late ProductSearchSort _sort;

  double get _max => widget.priceSliderMax <= 0 ? kProductSearchPriceSliderFallbackMax : widget.priceSliderMax;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initial.selectedCategoryId;
    final hi = widget.initial.priceMax.clamp(0.0, _max);
    final lo = widget.initial.priceMin.clamp(0.0, hi);
    _price = RangeValues(lo, hi);
    _sort = widget.initial.sort;
  }

  void _hapticLight() {
    HapticFeedback.selectionClick();
  }

  ProductSearchFilters _buildResult() {
    final max = _max;
    return ProductSearchFilters(
      selectedCategoryId: _categoryId,
      priceMin: _price.start.clamp(0, max),
      priceMax: _price.end.clamp(0, max),
      sort: _sort,
    );
  }

  void _apply() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(_buildResult());
  }

  void _clear() {
    HapticFeedback.lightImpact();
    setState(() {
      _categoryId = null;
      _price = RangeValues(0, _max);
      _sort = ProductSearchSort.recent;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tops = _topLevelCategories(widget.categories);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final max = _max;
    final divisions = (max / 50).clamp(4, 40).round();

    final sheetBg = isDark ? EvetaShopColors.darkCardElevated : scheme.surface;
    final handleColor = scheme.onSurfaceVariant.withValues(alpha: 0.35);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
              child: Row(
                children: [
                  Text(
                    'Filtros',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clear,
                    child: const Text('Limpiar filtros'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Categoría',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _CategoryChip(
                          label: 'Todas',
                          selected: _categoryId == null || _categoryId!.isEmpty,
                          onTap: () {
                            _hapticLight();
                            setState(() => _categoryId = null);
                          },
                        ),
                        ...tops.map((c) {
                          final id = c['id']?.toString() ?? '';
                          final name = c['name']?.toString() ?? '—';
                          if (id.isEmpty) return const SizedBox.shrink();
                          final sel = _categoryId == id;
                          return _CategoryChip(
                            label: name,
                            selected: sel,
                            onTap: () {
                              _hapticLight();
                              setState(() => _categoryId = id);
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Precio (hasta ${_formatBs(max)})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatBs(_price.start),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatBs(_price.end),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: RangeValues(
                        _price.start.clamp(0, max),
                        _price.end.clamp(0, max),
                      ),
                      min: 0,
                      max: max,
                      divisions: divisions,
                      onChanged: (v) => setState(() => _price = v),
                      onChangeEnd: (_) => HapticFeedback.selectionClick(),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Ordenar por',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SortTile(
                      title: 'Más recientes',
                      selected: _sort == ProductSearchSort.recent,
                      onTap: () {
                        _hapticLight();
                        setState(() => _sort = ProductSearchSort.recent);
                      },
                    ),
                    const SizedBox(height: 8),
                    _SortTile(
                      title: 'Precio: menor a mayor',
                      selected: _sort == ProductSearchSort.priceAsc,
                      onTap: () {
                        _hapticLight();
                        setState(() => _sort = ProductSearchSort.priceAsc);
                      },
                    ),
                    const SizedBox(height: 8),
                    _SortTile(
                      title: 'Precio: mayor a menor',
                      selected: _sort == ProductSearchSort.priceDesc,
                      onTap: () {
                        _hapticLight();
                        setState(() => _sort = ProductSearchSort.priceDesc);
                      },
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
              decoration: BoxDecoration(
                color: sheetBg,
                border: Border(
                  top: BorderSide(color: scheme.outline.withValues(alpha: 0.12)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(EvetaShopDimens.radiusXl),
                  ),
                ),
                child: const Text('Aplicar filtros'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.18)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.55)
                  : scheme.outline.withValues(alpha: 0.22),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? scheme.primary : scheme.onSurface,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _SortTile extends StatelessWidget {
  const _SortTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.14)
                : (isDark
                    ? EvetaShopColors.darkSurfaceContainer
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.65)),
            borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.45)
                  : scheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
