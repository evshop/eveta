import 'package:shared_preferences/shared_preferences.dart';

/// Ubicación de entrega guardada (mapa de agregar ubicación / checkout).
class DeliveryLocationPrefs {
  DeliveryLocationPrefs._();

  static const _latKey = 'delivery_dropoff_lat';
  static const _lngKey = 'delivery_dropoff_lng';
  static const _addrKey = 'delivery_dropoff_address';

  static Future<void> save({
    required double lat,
    required double lng,
    required String address,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_latKey, lat);
    await p.setDouble(_lngKey, lng);
    await p.setString(_addrKey, address);
  }

  static Future<({double? lat, double? lng, String address})> load() async {
    final p = await SharedPreferences.getInstance();
    return (
      lat: p.getDouble(_latKey),
      lng: p.getDouble(_lngKey),
      address: p.getString(_addrKey) ?? '',
    );
  }

  static Future<bool> hasSavedLocation() async {
    final l = await load();
    return l.lat != null && l.lng != null;
  }
}
