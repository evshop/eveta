/// Tamaños de entrega para ahorrar ancho de banda / transformaciones Cloudinary.
enum EvetaImageDelivery {
  /// Tarjetas, listas, carrito, categorías (ligero).
  card,
  /// Miniaturas del carrusel en detalle.
  thumb,
  /// Vista principal en detalle del producto (buena calidad, no original).
  detail,
  /// Banners 16:9 del carrusel de inicio (relleno suave, peso moderado).
  promo,
}

String _deliveryTransform(EvetaImageDelivery delivery) {
  return switch (delivery) {
    EvetaImageDelivery.card => 'c_limit,w_480,q_auto:eco,f_auto',
    EvetaImageDelivery.thumb => 'c_fill,w_200,h_200,g_auto,q_auto:eco,f_auto',
    EvetaImageDelivery.detail => 'c_limit,w_1280,q_auto:good,f_auto',
    EvetaImageDelivery.promo => 'c_fill,w_960,h_540,g_auto,q_auto:eco,f_auto',
  };
}

/// Evita quitar el primer segmento si es carpeta (ej. mi_carpeta); solo cadenas típicas de transformación.
bool _looksLikeCloudinaryTransformSegment(String segment) {
  if (segment.isEmpty) return false;
  if (RegExp(r'^v\d+$').hasMatch(segment)) return false;
  if (segment.contains(',')) return true;
  final head = segment.split('_').first;
  const transformKeys = {
    'w', 'h', 'c', 'q', 'f', 'e', 'a', 'b', 'd', 'g', 'l', 'o', 'r', 't', 'u', 'x', 'y', 'z',
    'fl', 'dn', 'af', 'if', 'ar', 'bo', 'br', 'co', 'cs', 'du', 'eo', 'fx', 'pg', 'rw', 'so',
  };
  return transformKeys.contains(head);
}

/// Inserta o sustituye transformaciones en una URL de Cloudinary. Otras URLs se devuelven igual.
String evetaImageDeliveryUrl(String url, EvetaImageDelivery delivery) {
  if (url.isEmpty) return url;
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  if (!uri.host.contains('cloudinary.com')) return url;

  final path = uri.path;
  const marker = '/upload/';
  final idx = path.indexOf(marker);
  if (idx < 0) return url;

  final base = path.substring(0, idx + marker.length);
  var rest = path.substring(idx + marker.length);

  final parts = rest.split('/');
  if (parts.isNotEmpty && _looksLikeCloudinaryTransformSegment(parts.first)) {
    rest = parts.skip(1).join('/');
  }

  final transform = _deliveryTransform(delivery);
  final newPath = '$base$transform/$rest';
  return uri.replace(path: newPath).toString();
}
