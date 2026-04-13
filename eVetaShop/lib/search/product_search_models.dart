import 'package:flutter/material.dart';

/// Orden de resultados en catálogo.
enum ProductSearchSort {
  recent,
  priceAsc,
  priceDesc,
}

/// Si no hay precio en catálogo, el slider usa 0…[esta cota] (Bs).
const double kProductSearchPriceSliderFallbackMax = 1500;

/// Filtros inmutables para búsqueda avanzada.
@immutable
class ProductSearchFilters {
  const ProductSearchFilters({
    this.selectedCategoryId,
    this.priceMin = 0,
    this.priceMax = kProductSearchPriceSliderFallbackMax,
    this.sort = ProductSearchSort.recent,
  });

  /// `null` = todas las categorías.
  final String? selectedCategoryId;

  /// Límite inferior de precio (Bs).
  final double priceMin;

  /// Límite superior de precio (Bs). Debe ser ≤ [priceSliderMax] del controlador.
  final double priceMax;

  final ProductSearchSort sort;

  static const ProductSearchFilters initial = ProductSearchFilters();

  bool hasActiveFilters(double priceSliderMax) {
    if (selectedCategoryId != null && selectedCategoryId!.isNotEmpty) return true;
    if (priceMin > 0) return true;
    if (priceMax < priceSliderMax - 0.01) return true;
    if (sort != ProductSearchSort.recent) return true;
    return false;
  }

  ProductSearchFilters copyWith({
    String? selectedCategoryId,
    bool clearCategory = false,
    double? priceMin,
    double? priceMax,
    ProductSearchSort? sort,
  }) {
    return ProductSearchFilters(
      selectedCategoryId: clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProductSearchFilters &&
        other.selectedCategoryId == selectedCategoryId &&
        other.priceMin == priceMin &&
        other.priceMax == priceMax &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(selectedCategoryId, priceMin, priceMax, sort);
}

/// Expande un id de categoría raíz a [id + todas las subcategorías] según filas de Supabase.
List<String> categoryIdsIncludingDescendants(
  String? rootId,
  List<Map<String, dynamic>> allCategories,
) {
  if (rootId == null || rootId.isEmpty) return [];
  final out = <String>{rootId};
  var changed = true;
  while (changed) {
    changed = false;
    for (final c in allCategories) {
      final id = c['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final pid = c['parent_id']?.toString().trim();
      if (pid == null || pid.isEmpty || pid == 'null') continue;
      if (out.contains(pid) && !out.contains(id)) {
        out.add(id);
        changed = true;
      }
    }
  }
  return out.toList();
}
