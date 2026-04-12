import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Una dirección de entrega guardada por el usuario.
class SavedDeliveryLocation {
  const SavedDeliveryLocation({
    required this.id,
    required this.lat,
    required this.lng,
    required this.address,
  });

  final String id;
  final double lat;
  final double lng;
  final String address;

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': lat,
        'lng': lng,
        'address': address,
      };

  static SavedDeliveryLocation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = m['id']?.toString();
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
    if (id == null || id.isEmpty || lat == null || lng == null) return null;
    return SavedDeliveryLocation(
      id: id,
      lat: lat,
      lng: lng,
      address: m['address']?.toString() ?? '',
    );
  }
}

/// Ubicación de entrega: claves legacy + lista de favoritas y activa.
class DeliveryLocationPrefs {
  DeliveryLocationPrefs._();

  static const _latKey = 'delivery_dropoff_lat';
  static const _lngKey = 'delivery_dropoff_lng';
  static const _addrKey = 'delivery_dropoff_address';
  static const _savedKey = 'delivery_saved_locations_v1';
  static const _activeIdKey = 'delivery_active_location_id';

  static Future<void> _writeLegacy(SharedPreferences p, double lat, double lng, String address) async {
    await p.setDouble(_latKey, lat);
    await p.setDouble(_lngKey, lng);
    await p.setString(_addrKey, address);
  }

  static Future<void> _migrateLegacyToListIfNeeded(SharedPreferences p) async {
    if (p.getString(_savedKey) != null && p.getString(_savedKey)!.isNotEmpty) return;
    final lat = p.getDouble(_latKey);
    final lng = p.getDouble(_lngKey);
    if (lat == null || lng == null) return;
    final addr = p.getString(_addrKey) ?? '';
    final id = 'legacy_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}';
    final list = [SavedDeliveryLocation(id: id, lat: lat, lng: lng, address: addr)];
    await p.setString(_savedKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    await p.setString(_activeIdKey, id);
  }

  static Future<List<SavedDeliveryLocation>> loadSaved() async {
    final p = await SharedPreferences.getInstance();
    await _migrateLegacyToListIfNeeded(p);
    final raw = p.getString(_savedKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map(SavedDeliveryLocation.fromJson).whereType<SavedDeliveryLocation>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Ubicación activa para envío (legacy + lista).
  static Future<({double? lat, double? lng, String address})> load() async {
    final p = await SharedPreferences.getInstance();
    await _migrateLegacyToListIfNeeded(p);
    final saved = await loadSaved();
    final activeId = p.getString(_activeIdKey);
    if (activeId != null && activeId.isNotEmpty) {
      for (final e in saved) {
        if (e.id == activeId) {
          return (lat: e.lat, lng: e.lng, address: e.address);
        }
      }
    }
    if (saved.isNotEmpty) {
      final e = saved.first;
      await p.setString(_activeIdKey, e.id);
      await _writeLegacy(p, e.lat, e.lng, e.address);
      return (lat: e.lat, lng: e.lng, address: e.address);
    }
    return (
      lat: p.getDouble(_latKey),
      lng: p.getDouble(_lngKey),
      address: p.getString(_addrKey) ?? '',
    );
  }

  /// Guarda como activa y la añade o actualiza en favoritas (misma posición ≈ igual entrada).
  static Future<void> save({
    required double lat,
    required double lng,
    required String address,
  }) async {
    final p = await SharedPreferences.getInstance();
    await _migrateLegacyToListIfNeeded(p);
    var list = await loadSaved();

    const tol = 0.00015;
    final idx = list.indexWhere((e) => (e.lat - lat).abs() < tol && (e.lng - lng).abs() < tol);
    final id = idx >= 0 ? list[idx].id : 'loc_${DateTime.now().millisecondsSinceEpoch}';
    final entry = SavedDeliveryLocation(id: id, lat: lat, lng: lng, address: address);
    if (idx >= 0) {
      list = List<SavedDeliveryLocation>.from(list)..[idx] = entry;
    } else {
      list = [...list, entry];
    }

    await p.setString(_savedKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    await p.setString(_activeIdKey, id);
    await _writeLegacy(p, lat, lng, address);
  }

  static Future<void> selectSaved(String id) async {
    final p = await SharedPreferences.getInstance();
    final list = await loadSaved();
    SavedDeliveryLocation? found;
    for (final x in list) {
      if (x.id == id) {
        found = x;
        break;
      }
    }
    if (found == null) return;
    await p.setString(_activeIdKey, id);
    await _writeLegacy(p, found.lat, found.lng, found.address);
  }

  static Future<bool> hasSavedLocation() async {
    final l = await load();
    return l.lat != null && l.lng != null;
  }

  static Future<String?> loadActiveId() async {
    final p = await SharedPreferences.getInstance();
    await _migrateLegacyToListIfNeeded(p);
    return p.getString(_activeIdKey);
  }
}
