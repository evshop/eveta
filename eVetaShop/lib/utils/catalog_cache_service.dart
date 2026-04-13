import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eveta/utils/supabase_service.dart';

/// Caché local del catálogo ([SharedPreferences]) para reducir lecturas a Supabase
/// y repetición de trabajo; las imágenes siguen cacheándose por URL con
/// [cached_network_image] / disco.
class CatalogCacheService {
  CatalogCacheService._();

  /// Tras este tiempo se vuelve a pedir al servidor (si la app lo intenta).
  static const Duration ttl = Duration(hours: 6);

  static const String _prefix = 'eveta_catalog_v1_';

  static String _key(String name) => '$_prefix$name';

  static Future<void> _store(String name, Object? data) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'at': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    };
    await prefs.setString(_key(name), jsonEncode(payload));
  }

  static Future<Map<String, dynamic>?> _loadMeta(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key(name));
    if (s == null || s.isEmpty) return null;
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static bool _isFresh(int atMillis) {
    final age = DateTime.now().millisecondsSinceEpoch - atMillis;
    return age < ttl.inMilliseconds;
  }

  static List<Map<String, dynamic>> _listFromData(dynamic data) {
    if (data is! List) return [];
    return data
        .map((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        })
        .where((m) => m.isNotEmpty)
        .toList();
  }

  static Map<String, dynamic>? _mapFromData(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  static Future<List<Map<String, dynamic>>> _cachedList(
    String cacheName,
    Future<List<Map<String, dynamic>>> Function() fetch, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final meta = await _loadMeta(cacheName);
      if (meta != null && meta['at'] != null && meta['data'] != null) {
        final at = meta['at'] as int;
        if (_isFresh(at)) {
          final list = _listFromData(meta['data']);
          if (list.isNotEmpty) {
            return list;
          }
        }
      }
    }

    final list = await fetch();
    if (list.isNotEmpty) {
      await _store(cacheName, list);
      return list;
    }

    final stale = await _loadMeta(cacheName);
    if (stale != null && stale['data'] != null) {
      final fallback = _listFromData(stale['data']);
      if (fallback.isNotEmpty) {
        return fallback;
      }
    }
    return list;
  }

  static Future<Map<String, dynamic>?> _cachedProduct(
    String cacheName,
    Future<Map<String, dynamic>?> Function() fetch, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final meta = await _loadMeta(cacheName);
      if (meta != null && meta['at'] != null && meta['data'] != null) {
        final at = meta['at'] as int;
        if (_isFresh(at)) {
          final m = _mapFromData(meta['data']);
          if (m != null && m.isNotEmpty) {
            return m;
          }
        }
      }
    }

    final map = await fetch();
    if (map != null && map.isNotEmpty) {
      await _store(cacheName, map);
      return map;
    }

    final stale = await _loadMeta(cacheName);
    if (stale != null && stale['data'] != null) {
      final fallback = _mapFromData(stale['data']);
      if (fallback != null && fallback.isNotEmpty) {
        return fallback;
      }
    }
    return map;
  }

  /// Misma lista que [SupabaseService.getProducts] (inicio).
  static Future<List<Map<String, dynamic>>> getProducts({bool forceRefresh = false}) {
    return _cachedList('home_products', SupabaseService.getProducts, forceRefresh: forceRefresh);
  }

  static Future<List<Map<String, dynamic>>> getProductsByCategory(
    String categoryId, {
    bool forceRefresh = false,
  }) {
    return _cachedList(
      'cat_${categoryId.trim()}',
      () => SupabaseService.getProductsByCategory(categoryId),
      forceRefresh: forceRefresh,
    );
  }

  static Future<List<Map<String, dynamic>>> getProductsByCategoryIds(
    List<String> categoryIds, {
    bool forceRefresh = false,
  }) {
    final sorted = categoryIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()..sort();
    if (sorted.isEmpty) return Future.value([]);
    final key = 'cats_${sorted.join('|')}';
    return _cachedList(
      key,
      () => SupabaseService.getProductsByCategoryIds(sorted),
      forceRefresh: forceRefresh,
    );
  }

  static Future<Map<String, dynamic>?> getProductById(
    String id, {
    bool forceRefresh = false,
  }) {
    return _cachedProduct(
      'product_${id.trim()}',
      () => SupabaseService.getProductById(id),
      forceRefresh: forceRefresh,
    );
  }

  static Future<List<Map<String, dynamic>>> getCategories({bool forceRefresh = false}) {
    return _cachedList('categories_all', SupabaseService.getCategories, forceRefresh: forceRefresh);
  }

  /// Borra todo el caché de catálogo (p. ej. depuración).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
    debugPrint('CatalogCacheService: cleared ${keys.length} keys');
  }
}
