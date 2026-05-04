import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import 'package:eveta/search/product_search_models.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  static List<Map<String, dynamic>> _excludeEventTicketMirrorProducts(
    List<Map<String, dynamic>> rows,
  ) {
    return rows
        .where(
          (row) =>
              row['event_ticket_type_id'] == null ||
              row['event_ticket_type_id'].toString().trim().isEmpty,
        )
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final response = await client
          .from('products')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(20);
      debugPrint('Productos obtenidos: ${response.length}');
      if (response.isNotEmpty) {
        debugPrint('Primer producto: ${response[0]}');
      }
      return _excludeEventTicketMirrorProducts(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint('Error al obtener productos: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getProductsByCategory(String categoryId) async {
    try {
      final response = await client
          .from('products')
          .select()
          .eq('is_active', true)
          .eq('category_id', categoryId)
          .order('created_at', ascending: false)
          .limit(100);
      return _excludeEventTicketMirrorProducts(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint('Error al obtener productos por categoría: $e');
      return [];
    }
  }

  /// Productos cuya `category_id` está en [categoryIds] (p. ej. padre + subcategorías).
  static Future<List<Map<String, dynamic>>> getProductsByCategoryIds(List<String> categoryIds) async {
    final ids = categoryIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return [];
    try {
      final response = await client
          .from('products')
          .select()
          .eq('is_active', true)
          .inFilter('category_id', ids)
          .order('created_at', ascending: false)
          .limit(200);
      return _excludeEventTicketMirrorProducts(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint('Error al obtener productos por categorías: $e');
      return [];
    }
  }

  /// [sellerId] es `profiles_portal.id` tras la migración 064.
  static Future<Map<String, dynamic>?> getShopBySellerId(String sellerId) async {
    try {
      final response = await client
          .from('profiles_portal')
          .select(
            'id, shop_name, shop_description, shop_logo_url, shop_banner_url, '
            'shop_border_color, full_name, email, avatar_url',
          )
          .eq('id', sellerId)
          .maybeSingle();
      if (response == null) return null;

      final m = Map<String, dynamic>.from(response);
      final bannerStr = m['shop_banner_url']?.toString().trim() ?? '';
      if (bannerStr.isEmpty &&
          m['avatar_url'] != null &&
          m['avatar_url'].toString().trim().isNotEmpty) {
        m['shop_banner_url'] = m['avatar_url'];
      }
      final logoStr = m['shop_logo_url']?.toString().trim() ?? '';
      if (logoStr.isEmpty &&
          m['avatar_url'] != null &&
          m['avatar_url'].toString().trim().isNotEmpty) {
        m['shop_logo_url'] = m['avatar_url'];
      }
      return m;
    } catch (e) {
      if (e.toString().toLowerCase().contains('shop_banner_url') ||
          e.toString().toLowerCase().contains('shop_border_color')) {
        final response = await client
            .from('profiles_portal')
            .select('id, shop_name, shop_description, shop_logo_url, full_name, email, avatar_url')
            .eq('id', sellerId)
            .maybeSingle();
        if (response == null) return null;
        final m = Map<String, dynamic>.from(response);
        if (m['avatar_url'] != null && m['avatar_url'].toString().isNotEmpty) {
          m['shop_banner_url'] = m['avatar_url'];
        }
        return m;
      }
      debugPrint('Error al obtener shop: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getProductsBySellerId(String sellerId) async {
    try {
      final response = await client
          .from('products')
          .select('id, name, price, original_price, images, stock, rating, review_count, is_featured, tags, event_ticket_type_id, categories(name)')
          .eq('is_active', true)
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false)
          .limit(50);
      return _excludeEventTicketMirrorProducts(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint('Error al obtener productos por seller: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getProductById(String id) async {
    debugPrint('Buscando producto con ID: $id');
    const embedSimple =
        '*, categories(spec_group_title), profiles_portal(shop_name, full_name, email, avatar_url)';
    const embedHint =
        '*, categories(spec_group_title), '
        'profiles_portal!products_seller_id_profiles_portal_fkey(shop_name, full_name, email, avatar_url)';
    Future<Map<String, dynamic>?> oneSelect(String columns) async {
      return await client
          .from('products')
          .select(columns)
          .eq('id', id)
          .eq('is_active', true)
          .maybeSingle();
    }
    try {
      final response = await oneSelect(embedSimple);
      debugPrint('Resultado getProductById: $response');
      return response;
    } catch (e) {
      debugPrint('getProductById embed simple falló: $e');
      try {
        final response = await oneSelect(embedHint);
        debugPrint('Resultado getProductById (hint FK): $response');
        return response;
      } catch (e2) {
        debugPrint('getProductById embed hint falló: $e2');
        try {
          return await oneSelect('*');
        } catch (e3) {
          debugPrint('Error al obtener producto: $e3');
          return null;
        }
      }
    }
  }

  /// Escapa `%` y `_` para evitar que el usuario altere el patrón ILIKE.
  static String _escapeIlike(String query) {
    return query.replaceAll('\\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
  }

  static Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    try {
      final q = _escapeIlike(query.trim());
      final response = await client
          .from('products')
          .select('id, name, price, images, event_ticket_type_id, categories(name)')
          .eq('is_active', true)
          .or('name.ilike.%$q%,tags.cs.{$query}')
          .limit(25);
      return _excludeEventTicketMirrorProducts(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint('Error en búsqueda: $e');
      return [];
    }
  }

  /// Precio máximo entre productos activos (para tope del slider de búsqueda).
  static Future<double?> getMaxActiveProductPrice() async {
    try {
      final row = await client
          .from('products')
          .select('price')
          .eq('is_active', true)
          .isFilter('event_ticket_type_id', null)
          .order('price', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final p = row['price'];
      if (p is num) return p.toDouble();
      return double.tryParse(p?.toString() ?? '');
    } catch (e) {
      debugPrint('Error al obtener precio máximo: $e');
      return null;
    }
  }

  /// Productos que comparten al menos un tag con [tags] (Postgres array overlap).
  static Future<List<Map<String, dynamic>>> getProductsOverlappingTags(
    List<String> tags, {
    required String excludeProductId,
    int limit = 40,
  }) async {
    final clean = tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (clean.isEmpty) return [];
    try {
      final response = await client
          .from('products')
          .select(
            'id, name, price, original_price, images, stock, rating, review_count, is_featured, tags, event_ticket_type_id, categories(name)',
          )
          .eq('is_active', true)
          .neq('id', excludeProductId)
          .overlaps('tags', clean)
          .limit(limit);
      return _excludeEventTicketMirrorProducts(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint('getProductsOverlappingTags: $e — reintento con un tag');
      try {
        final t = _escapeIlike(clean.first);
        final response = await client
            .from('products')
            .select(
              'id, name, price, original_price, images, stock, rating, review_count, is_featured, tags, event_ticket_type_id, categories(name)',
            )
            .eq('is_active', true)
            .neq('id', excludeProductId)
            .or('tags.cs.{$t}')
            .limit(limit);
        return _excludeEventTicketMirrorProducts(
          List<Map<String, dynamic>>.from(response),
        );
      } catch (e2) {
        debugPrint('getProductsOverlappingTags fallback: $e2');
        return [];
      }
    }
  }

  /// Palabra suelta en el nombre (para relacionados por similitud).
  static Future<List<Map<String, dynamic>>> searchProductsByNameWord(
    String word, {
    required String excludeProductId,
    int limit = 15,
  }) async {
    final w = word.trim();
    if (w.length < 2) return [];
    try {
      final q = _escapeIlike(w);
      final response = await client
          .from('products')
          .select(
            'id, name, price, original_price, images, stock, rating, review_count, is_featured, tags, event_ticket_type_id, categories(name)',
          )
          .eq('is_active', true)
          .neq('id', excludeProductId)
          .ilike('name', '%$q%')
          .limit(limit);
      return _excludeEventTicketMirrorProducts(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint('searchProductsByNameWord: $e');
      return [];
    }
  }

  /// Condiciones `or(...)` para nombre, categoría y tags (palabras sueltas y texto con #).
  static String _productTextSearchOrFilter(String rawQuery, {required bool includeCategoryName}) {
    var t = rawQuery.trim();
    if (t.length < 2) return '';
    final parts = <String>{};
    final fullEscaped = _escapeIlike(t);
    parts.add('name.ilike.%$fullEscaped%');
    if (includeCategoryName) {
      parts.add('categories.name.ilike.%$fullEscaped%');
    }

    var tagProbe = t.startsWith('#') ? t.substring(1).trim() : t;
    if (tagProbe.length >= 2 && !tagProbe.contains(',') && !tagProbe.contains('{') && !tagProbe.contains('}')) {
      parts.add('tags.cs.{$tagProbe}');
    }

    final words = t
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.length >= 2)
        .toSet();
    for (final w in words) {
      var w2 = w.startsWith('#') ? w.substring(1).trim() : w;
      if (w2.length < 2) continue;
      final ew = _escapeIlike(w2);
      parts.add('name.ilike.%$ew%');
      if (includeCategoryName) {
        parts.add('categories.name.ilike.%$ew%');
      }
      if (!w2.contains(',') && !w2.contains('{') && !w2.contains('}')) {
        parts.add('tags.cs.{$w2}');
      }
    }
    return parts.join(',');
  }

  /// Búsqueda con filtros (texto opcional si [query] tiene ≥2 caracteres).
  static Future<List<Map<String, dynamic>>> searchProductsAdvanced({
    required String query,
    List<String>? categoryIds,
    double minPrice = 0,
    required double maxPrice,
    required double priceFilterCeiling,
    ProductSearchSort sort = ProductSearchSort.recent,
  }) async {
    final trimmed = query.trim();
    for (final includeCat in [true, false]) {
      try {
        dynamic qb = client
            .from('products')
            .select('id, name, price, stock, images, category_id, created_at, tags, event_ticket_type_id, categories(name)')
            .eq('is_active', true);

        if (trimmed.length >= 2) {
          final orExpr = _productTextSearchOrFilter(trimmed, includeCategoryName: includeCat);
          if (orExpr.isNotEmpty) {
            qb = qb.or(orExpr);
          }
        }

        if (categoryIds != null && categoryIds.isNotEmpty) {
          qb = qb.inFilter('category_id', categoryIds);
        }
        if (minPrice > 0) {
          qb = qb.gte('price', minPrice);
        }
        if (maxPrice < priceFilterCeiling - 0.01) {
          qb = qb.lte('price', maxPrice);
        }

        switch (sort) {
          case ProductSearchSort.recent:
            qb = qb.order('created_at', ascending: false);
            break;
          case ProductSearchSort.priceAsc:
            qb = qb.order('price', ascending: true);
            break;
          case ProductSearchSort.priceDesc:
            qb = qb.order('price', ascending: false);
            break;
        }

        qb = qb.limit(100);
        final response = await qb;
        return _excludeEventTicketMirrorProducts(
          List<Map<String, dynamic>>.from(response),
        );
      } catch (e) {
        debugPrint('searchProductsAdvanced (includeCategoryName=$includeCat): $e');
        if (!includeCat) return [];
      }
    }
    return [];
  }

  /// Vendedores cuyo nombre de tienda o nombre coincide con la búsqueda.
  static Future<List<Map<String, dynamic>>> searchStores(String query) async {
    try {
      final raw = query.trim().toLowerCase();
      if (raw.length < 2) return [];
      // Una sola cláusula .or (RLS 065: is_seller o is_partner_verified); el texto se filtra en cliente.
      final response = await client
          .from('profiles_portal')
          .select('id, shop_name, shop_logo_url, full_name, avatar_url')
          .eq('is_active', true)
          .or('is_seller.eq.true,is_partner_verified.eq.true')
          .limit(40);
      final list = List<Map<String, dynamic>>.from(response);
      list.removeWhere((row) {
        final sn = row['shop_name']?.toString().trim() ?? '';
        final fn = row['full_name']?.toString().trim() ?? '';
        if (sn.isEmpty && fn.isEmpty) return true;
        final hay = '${sn.toLowerCase()} ${fn.toLowerCase()}';
        return !hay.contains(raw);
      });
      return list.take(12).toList();
    } catch (e) {
      debugPrint('Error en búsqueda de tiendas: $e');
      return [];
    }
  }

  /// Vendedores para carrusel “tiendas destacadas” en inicio.
  static Future<List<Map<String, dynamic>>> getFeaturedSellers({int limit = 12}) async {
    try {
      final response = await client
          .from('profiles_portal')
          .select('id, shop_name, shop_logo_url, full_name, avatar_url, is_partner_verified, partner_display_order')
          .eq('is_active', true)
          .or('is_seller.eq.true,is_partner_verified.eq.true')
          .order('is_partner_verified', ascending: false)
          .order('partner_display_order', ascending: true)
          .limit(limit);
      final list = List<Map<String, dynamic>>.from(response);
      list.removeWhere((row) {
        final sn = row['shop_name']?.toString().trim() ?? '';
        return sn.isEmpty;
      });
      return list;
    } catch (e) {
      debugPrint('Error al obtener vendedores destacados: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getFeaturedProducts() async {
    try {
      final response = await client
          .from('products')
          .select()
          .eq('is_featured', true)
          .eq('is_active', true)
          .limit(10);
      return _excludeEventTicketMirrorProducts(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint('Error al obtener productos destacados: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await client
          .from('categories')
          .select('id, name, slug, icon, image_url, parent_id')
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error al obtener categorías: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      debugPrint('Error al obtener perfil: $e');
      return null;
    }
  }

  /// URLs del carrusel de inicio (solo activas). Vacío si la tabla no existe aún o no hay filas.
  static Future<List<String>> getHomePromotionBannerUrls() async {
    try {
      final response = await client
          .from('home_promotion_banners')
          .select('image_url')
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      final list = List<Map<String, dynamic>>.from(response);
      return list
          .map((e) => e['image_url']?.toString().trim() ?? '')
          .where((u) => u.isNotEmpty)
          .toList();
    } catch (e) {
      if (e.toString().toLowerCase().contains('home_promotion_banners')) {
        return [];
      }
      debugPrint('Error al obtener banners de inicio: $e');
      return [];
    }
  }
}