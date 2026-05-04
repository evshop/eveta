import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:eveta_delivery/mapbox_env.dart';

/// Ruta en carretera (Mapbox Directions API). Devuelve null si no hay token o falla la petición.
class MapboxDirections {
  MapboxDirections._();

  static String? _accessToken() {
    final t = mapboxPublicTokenFromEnv();
    return t.isEmpty ? null : t;
  }

  /// Geometría en coordenadas WGS84 para [flutter_map] (lat, lng).
  static Future<List<LatLng>?> fetchDrivingRoute(LatLng from, LatLng to) async {
    final token = _accessToken();
    if (token == null) return null;

    // Mapbox espera lng,lat
    final coords =
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/$coords'
      '?alternatives=false&geometries=geojson&overview=full&steps=false'
      '&access_token=$token',
    );

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = map['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final geometry = (routes.first as Map<String, dynamic>)['geometry'];
      if (geometry is! Map<String, dynamic>) return null;
      final coordsList = geometry['coordinates'];
      if (coordsList is! List) return null;
      final out = <LatLng>[];
      for (final c in coordsList) {
        if (c is List && c.length >= 2) {
          final lng = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          out.add(LatLng(lat, lng));
        }
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }
}
