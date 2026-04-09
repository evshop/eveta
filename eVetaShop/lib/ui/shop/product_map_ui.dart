// Utilidades para mapear filas de producto del catálogo a UI.

String primaryProductImageUrl(Map<String, dynamic> product) {
  final images = product['images'];
  if (images != null) {
    if (images is List && images.isNotEmpty) {
      return images[0].toString();
    }
    if (images is String && images.isNotEmpty) {
      return images;
    }
  }
  return '';
}

int? computeDiscountPercent(String? price, String? originalPrice) {
  if (price == null || originalPrice == null) return null;
  final priceNum = double.tryParse(price);
  final originalNum = double.tryParse(originalPrice);
  if (priceNum == null || originalNum == null || originalNum <= priceNum) return null;
  return ((originalNum - priceNum) / originalNum * 100).round();
}

int productStock(Map<String, dynamic> product) {
  final s = product['stock'];
  if (s is int) return s;
  return int.tryParse(s?.toString() ?? '0') ?? 0;
}

double productRating(Map<String, dynamic> product) {
  final r = product['rating'];
  if (r is num) return r.toDouble();
  return double.tryParse(r?.toString() ?? '0') ?? 0;
}

int productReviewCount(Map<String, dynamic> product) {
  final c = product['review_count'];
  if (c is int) return c;
  return int.tryParse(c?.toString() ?? '0') ?? 0;
}

String formatBs(String? price) {
  final n = double.tryParse(price ?? '');
  if (n == null) return 'Bs $price';
  return 'Bs ${n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2)}';
}
