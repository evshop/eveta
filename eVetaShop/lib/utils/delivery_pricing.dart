import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Tarifa envío: base + km extra más allá de [includedKm], con tope opcional.
class DeliveryPricing {
  DeliveryPricing._();

  /// Punto de recogida por defecto (San Julián) si la tienda no tiene coordenadas en BD.
  static const LatLng defaultPickup = LatLng(-16.9167, -62.6167);

  static const double baseFeeBs = 8;
  static const double perKmBs = 3;
  static const double includedKm = 2;
  static const double maxFeeBs = 80;

  /// Distancia en km (línea recta).
  static double haversineKm(LatLng a, LatLng b) {
    const earthKm = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthKm * c;
  }

  static double _rad(double d) => d * math.pi / 180;

  /// Costo total de un envío según km (un solo tramo pickup → dropoff).
  static double feeForDistanceKm(double km) {
    final extra = math.max(0.0, km - includedKm);
    final raw = baseFeeBs + extra * perKmBs;
    return math.min(raw, maxFeeBs);
  }

  /// Reparte el costo entre [splits] pedidos (varias tiendas en un checkout).
  static double splitFee(double totalFee, int splits) {
    if (splits <= 0) return totalFee;
    return (totalFee / splits);
  }
}
