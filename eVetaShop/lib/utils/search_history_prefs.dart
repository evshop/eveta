import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Producto abierto desde la búsqueda (para “vistos recientemente” en el buscador).
class SearchHistoryProduct {
  const SearchHistoryProduct({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String imageUrl;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'imageUrl': imageUrl};

  static SearchHistoryProduct? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    return SearchHistoryProduct(
      id: id,
      name: raw['name']?.toString() ?? '',
      imageUrl: raw['imageUrl']?.toString() ?? '',
    );
  }
}

/// Consultas y productos vistos desde el buscador principal.
abstract final class SearchHistoryPrefs {
  static const _queriesKey = 'eveta_shop_search_queries_v1';
  static const _productsKey = 'eveta_shop_search_products_v1';

  static Future<void> addQuery(String raw) async {
    final q = raw.trim();
    if (q.length < 2) return;
    final prefs = await SharedPreferences.getInstance();
    final list = List<String>.from(prefs.getStringList(_queriesKey) ?? []);
    final lower = q.toLowerCase();
    list.removeWhere((e) => e.toLowerCase() == lower);
    list.insert(0, q);
    while (list.length > 15) {
      list.removeLast();
    }
    await prefs.setStringList(_queriesKey, list);
  }

  static Future<List<String>> getQueries() async {
    final prefs = await SharedPreferences.getInstance();
    return List<String>.from(prefs.getStringList(_queriesKey) ?? []);
  }

  static Future<void> recordProductView(String id, String name, String imageUrl) async {
    final pid = id.trim();
    if (pid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_productsKey);
    final items = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map<String, dynamic>) {
              items.add(e);
            } else if (e is Map) {
              items.add(Map<String, dynamic>.from(e));
            }
          }
        }
      } catch (_) {}
    }
    items.removeWhere((m) => (m['id']?.toString() ?? '') == pid);
    items.insert(0, {
      'id': pid,
      'name': name.trim(),
      'imageUrl': imageUrl.trim(),
    });
    while (items.length > 20) {
      items.removeLast();
    }
    await prefs.setString(_productsKey, jsonEncode(items));
  }

  static Future<List<SearchHistoryProduct>> getProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_productsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final out = <SearchHistoryProduct>[];
      for (final e in decoded) {
        final p = SearchHistoryProduct.fromJson(e);
        if (p != null) out.add(p);
      }
      return out;
    } catch (_) {
      return [];
    }
  }
}
