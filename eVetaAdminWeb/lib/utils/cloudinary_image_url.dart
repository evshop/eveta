// Misma lógica que eVetaShop: vistas previas ligeras en el admin web.

enum EvetaImageDelivery {
  card,
  thumb,
  detail,
}

String _deliveryTransform(EvetaImageDelivery delivery) {
  return switch (delivery) {
    EvetaImageDelivery.card => 'c_limit,w_420,q_auto:eco,f_auto',
    EvetaImageDelivery.thumb => 'c_fill,w_180,h_180,g_auto,q_auto:eco,f_auto',
    EvetaImageDelivery.detail => 'c_limit,w_960,q_auto:good,f_auto',
  };
}

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
