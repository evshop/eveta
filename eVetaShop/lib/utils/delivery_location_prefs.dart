import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

String? _nullableTrimmed(Object? raw) {
  final s = raw?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

/// Una dirección de entrega guardada por el usuario.
class SavedDeliveryLocation {
  const SavedDeliveryLocation({
    required this.id,
    required this.lat,
    required this.lng,
    required this.address,
    required this.label,
    this.neighborhood = '',
    this.reference,
    this.aptFloor,
    this.instructions,
    this.geocodedLine = '',
  });

  final String id;
  final double lat;
  final double lng;
  /// Texto compuesto para el pedido (incluye detalle de calle + barrio + referencias).
  final String address;
  /// Nombre elegido por el usuario ("Casa", "Oficina").
  final String label;
  final String neighborhood;
  final String? reference;
  final String? aptFloor;
  final String? instructions;
  /// Línea corta de geocoding (calle / zona), útil para mostrar.
  final String geocodedLine;

  String get displayTitle {
    final l = label.trim();
    if (l.isNotEmpty) return l;
    final g = geocodedLine.trim();
    if (g.isNotEmpty) return g;
    return _firstLine(address);
  }

  static String _firstLine(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Mi ubicación';
    final i = t.indexOf('\n');
    return i < 0 ? t : t.substring(0, i).trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': lat,
        'lng': lng,
        'address': address,
        'label': label,
        'neighborhood': neighborhood,
        if (reference != null) 'reference': reference,
        if (aptFloor != null) 'apt_floor': aptFloor,
        if (instructions != null) 'instructions': instructions,
        'geocoded_line': geocodedLine,
      };

  static SavedDeliveryLocation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = m['id']?.toString();
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
    if (id == null || id.isEmpty || lat == null || lng == null) return null;
    final addr = m['address']?.toString() ?? '';
    final labelRaw = m['label']?.toString();
    final geo = m['geocoded_line']?.toString() ?? '';
    final label = (labelRaw != null && labelRaw.trim().isNotEmpty)
        ? labelRaw.trim()
        : _inferLegacyLabel(addr, geo);
    return SavedDeliveryLocation(
      id: id,
      lat: lat,
      lng: lng,
      address: addr,
      label: label,
      neighborhood: m['neighborhood']?.toString() ?? '',
      reference: _nullableTrimmed(m['reference']),
      aptFloor: _nullableTrimmed(m['apt_floor']),
      instructions: _nullableTrimmed(m['instructions']),
      geocodedLine: geo,
    );
  }

  static String _inferLegacyLabel(String address, String geo) {
    final g = geo.trim();
    if (g.isNotEmpty) {
      final parts = g.split(',');
      return parts.first.trim().isEmpty ? 'Mi ubicación' : parts.first.trim();
    }
    final a = address.trim();
    if (a.isEmpty) return 'Mi ubicación';
    final parts = a.split(',');
    return parts.first.trim().isEmpty ? 'Mi ubicación' : parts.first.trim();
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
    final list = [
      SavedDeliveryLocation(
        id: id,
        lat: lat,
        lng: lng,
        address: addr,
        label: SavedDeliveryLocation._inferLegacyLabel(addr, ''),
        geocodedLine: addr.split(',').first.trim(),
      ),
    ];
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
  static Future<({double? lat, double? lng, String address, String displayLabel})> load() async {
    final p = await SharedPreferences.getInstance();
    await _migrateLegacyToListIfNeeded(p);
    final saved = await loadSaved();
    final activeId = p.getString(_activeIdKey);
    if (activeId != null && activeId.isNotEmpty) {
      for (final e in saved) {
        if (e.id == activeId) {
          return (lat: e.lat, lng: e.lng, address: e.address, displayLabel: e.displayTitle);
        }
      }
    }
    if (saved.isNotEmpty) {
      final e = saved.first;
      await p.setString(_activeIdKey, e.id);
      await _writeLegacy(p, e.lat, e.lng, e.address);
      return (lat: e.lat, lng: e.lng, address: e.address, displayLabel: e.displayTitle);
    }
    return (
      lat: p.getDouble(_latKey),
      lng: p.getDouble(_lngKey),
      address: p.getString(_addrKey) ?? '',
      displayLabel: '',
    );
  }

  /// Compone la dirección guardada en Supabase/pedidos.
  static String composeFullAddress({
    required String label,
    required String neighborhood,
    required String geocodedLine,
    String? reference,
    String? aptFloor,
    String? instructions,
  }) {
    final buf = StringBuffer()
      ..write(label.trim())
      ..write(' · ')
      ..write(neighborhood.trim())
      ..write(' · ')
      ..write(geocodedLine.trim());
    if (aptFloor != null && aptFloor.trim().isNotEmpty) {
      buf.write(' · ');
      buf.write(aptFloor.trim());
    }
    if (reference != null && reference.trim().isNotEmpty) {
      buf.write(' · Ref: ');
      buf.write(reference.trim());
    }
    if (instructions != null && instructions.trim().isNotEmpty) {
      buf.write(' · Reparto: ');
      buf.write(instructions.trim());
    }
    return buf.toString();
  }

  /// Guarda ubicación con datos completos del onboarding.
  static Future<void> saveDeliveryLocation({
    required double lat,
    required double lng,
    required String label,
    required String neighborhood,
    required String geocodedLine,
    String? reference,
    String? aptFloor,
    String? instructions,
  }) async {
    final address = composeFullAddress(
      label: label,
      neighborhood: neighborhood,
      geocodedLine: geocodedLine,
      reference: reference,
      aptFloor: aptFloor,
      instructions: instructions,
    );
    final p = await SharedPreferences.getInstance();
    await _migrateLegacyToListIfNeeded(p);
    var list = await loadSaved();

    const tol = 0.00015;
    final idx = list.indexWhere((e) => (e.lat - lat).abs() < tol && (e.lng - lng).abs() < tol);
    final id = idx >= 0 ? list[idx].id : 'loc_${DateTime.now().millisecondsSinceEpoch}';
    final entry = SavedDeliveryLocation(
      id: id,
      lat: lat,
      lng: lng,
      address: address,
      label: label.trim(),
      neighborhood: neighborhood.trim(),
      reference: _nullableTrimmed(reference),
      aptFloor: _nullableTrimmed(aptFloor),
      instructions: _nullableTrimmed(instructions),
      geocodedLine: geocodedLine.trim(),
    );
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

  /// Quita una dirección guardada. Si era la activa, pasa a otra o limpia legacy.
  static Future<void> removeSaved(String id) async {
    final p = await SharedPreferences.getInstance();
    await _migrateLegacyToListIfNeeded(p);
    final list = await loadSaved();
    final next = list.where((e) => e.id != id).toList();
    await p.setString(_savedKey, jsonEncode(next.map((e) => e.toJson()).toList()));

    final activeId = p.getString(_activeIdKey);
    if (activeId != id) return;

    if (next.isEmpty) {
      await p.remove(_activeIdKey);
      await p.remove(_latKey);
      await p.remove(_lngKey);
      await p.remove(_addrKey);
      return;
    }

    await selectSaved(next.first.id);
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
