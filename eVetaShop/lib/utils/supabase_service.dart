import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

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
      return List<Map<String, dynamic>>.from(response);
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
          .limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error al obtener productos por categoría: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getShopBySellerId(String sellerId) async {
    try {
      final response = await client
          .from('profiles')
          .select('id, shop_name, shop_description, shop_logo_url, shop_banner_url, full_name, email, avatar_url')
          .eq('id', sellerId)
          .maybeSingle();
      if (response == null) return null;

      final m = Map<String, dynamic>.from(response);
      // Fallback: si no hay banner en columna de tienda, usamos avatar_url (perfiles antiguos).
      final bannerStr = m['shop_banner_url']?.toString().trim() ?? '';
      if (bannerStr.isEmpty &&
          m['avatar_url'] != null &&
          m['avatar_url'].toString().trim().isNotEmpty) {
        m['shop_banner_url'] = m['avatar_url'];
      }
      // Mismo criterio que en búsqueda: logo de tienda vacío → avatar del perfil.
      final logoStr = m['shop_logo_url']?.toString().trim() ?? '';
      if (logoStr.isEmpty &&
          m['avatar_url'] != null &&
          m['avatar_url'].toString().trim().isNotEmpty) {
        m['shop_logo_url'] = m['avatar_url'];
      }
      return m;
    } catch (e) {
      // Si aún no existe `shop_banner_url` en DB, reintentamos sin esa columna.
      if (e.toString().toLowerCase().contains('shop_banner_url')) {
        final response = await client
            .from('profiles')
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
          .select('id, name, price, original_price, images, stock, rating, review_count, is_featured, tags, categories(name)')
          .eq('is_active', true)
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error al obtener productos por seller: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getProductById(String id) async {
    try {
      debugPrint('Buscando producto con ID: $id');
      final response = await client
          .from('products')
          .select('*, categories(spec_group_title), profiles(full_name, shop_name, email)')
          .eq('id', id)
          .eq('is_active', true)
          .maybeSingle();
      debugPrint('Resultado getProductById: $response');
      return response;
    } catch (e) {
      debugPrint('Error al obtener producto (reintento sin categoría embebida): $e');
      try {
        final response = await client
            .from('products')
            .select()
            .eq('id', id)
            .eq('is_active', true)
            .maybeSingle();
        return response;
      } catch (e2) {
        debugPrint('Error al obtener producto: $e2');
        return null;
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
          .select('id, name, price, images, categories(name)')
          .eq('is_active', true)
          .or('name.ilike.%$q%,tags.cs.{$query}')
          .limit(25);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error en búsqueda: $e');
      return [];
    }
  }

  /// Vendedores cuyo nombre de tienda o nombre coincide con la búsqueda.
  static Future<List<Map<String, dynamic>>> searchStores(String query) async {
    try {
      final q = _escapeIlike(query.trim());
      final response = await client
          .from('profiles')
          .select('id, shop_name, shop_logo_url, full_name, avatar_url')
          .eq('is_seller', true)
          .or('shop_name.ilike.%$q%,full_name.ilike.%$q%')
          .limit(12);
      final list = List<Map<String, dynamic>>.from(response);
      list.removeWhere((row) {
        final sn = row['shop_name']?.toString().trim() ?? '';
        final fn = row['full_name']?.toString().trim() ?? '';
        return sn.isEmpty && fn.isEmpty;
      });
      return list;
    } catch (e) {
      debugPrint('Error en búsqueda de tiendas: $e');
      return [];
    }
  }

  /// Vendedores para carrusel “tiendas destacadas” en inicio.
  static Future<List<Map<String, dynamic>>> getFeaturedSellers({int limit = 12}) async {
    try {
      final response = await client
          .from('profiles')
          .select('id, shop_name, shop_logo_url, full_name, avatar_url')
          .eq('is_seller', true)
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
      return List<Map<String, dynamic>>.from(response);
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