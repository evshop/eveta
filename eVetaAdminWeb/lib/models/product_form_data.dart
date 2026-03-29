class ProductFormData {
  const ProductFormData({
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.categoryId,
    required this.isActive,
    required this.isFeatured,
    required this.unit,
    required this.images,
    required this.imagesLayout,
    this.specRows = const [],
    this.tags = const [],
  });

  final String name;
  final String description;
  final double price;
  final int stock;
  final String categoryId;
  final bool isActive;
  final bool isFeatured;
  final String unit;
  final List<String> images;
  /// Misma longitud y orden que [images]: width, height, aspect_ratio, orientation.
  final List<Map<String, dynamic>> imagesLayout;

  /// Especificaciones estructuradas (orden = plantilla de la categoría). Vacío si la categoría no usa plantilla.
  final List<Map<String, String>> specRows;
  final List<String> tags;
}
