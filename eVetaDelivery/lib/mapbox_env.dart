import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Misma convención que eVetaShop: `NEXT_PUBLIC_MAPBOX_TOKEN`, con respaldo `MAPBOX_ACCESS_TOKEN`.
/// Quita comillas típicas de archivos `.env` copiados.
String mapboxPublicTokenFromEnv() {
  for (final key in ['NEXT_PUBLIC_MAPBOX_TOKEN', 'MAPBOX_ACCESS_TOKEN']) {
    var v = (dotenv.env[key] ?? '').trim();
    if (v.length >= 2) {
      if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
        v = v.substring(1, v.length - 1).trim();
      }
    }
    if (v.isNotEmpty) return v;
  }
  return '';
}

String mapboxStyleIdFromEnv() {
  var s = (dotenv.env['MAPBOX_STYLE_ID'] ?? 'mapbox/streets-v12').trim();
  if (s.length >= 2 &&
      ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'")))) {
    s = s.substring(1, s.length - 1).trim();
  }
  return s.isEmpty ? 'mapbox/streets-v12' : s;
}
