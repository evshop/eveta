import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_form_data.dart';
import 'auth_service.dart';

class ProductsService {
  static SupabaseClient get _client => Supabase.instance.client;

  static String _slugify(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final data = await _client
          .from('categories')
          .select(
            'id, name, slug, icon, image_url, color_hex, parent_id, spec_template_enabled, spec_field_labels, spec_group_title',
          )
          .order('name');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('spec_template') || msg.contains('spec_field') || msg.contains('color_hex')) {
        try {
          final data = await _client
              .from('categories')
              .select('id, name, slug, icon, image_url, color_hex, parent_id')
              .order('name');
          return List<Map<String, dynamic>>.from(data);
        } catch (e2) {
          final msg2 = e2.toString().toLowerCase();
          if (msg2.contains('color_hex')) {
            final data = await _client
                .from('categories')
                .select('id, name, slug, icon, image_url, parent_id')
                .order('name');
            return List<Map<String, dynamic>>.from(data);
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  static Future<String> _slugForCategoryName(String cleanName, String? parentId) async {
    if (parentId != null && parentId.isNotEmpty) {
      final prow = await _client.from('categories').select('slug').eq('id', parentId).maybeSingle();
      final ps = prow?['slug']?.toString() ?? 'cat';
      return _slugify('$ps-$cleanName');
    }
    return _slugify(cleanName);
  }

  static Future<void> createCategory(
    String name, {
    String? parentId,
    String? logoUrl,
    String? bannerUrl,
    String? colorHex,
    bool specTemplateEnabled = false,
    List<String> specFieldLabels = const [],
    String? specGroupTitle,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) throw AuthException('Nombre de categoría inválido');
    final slug = await _slugForCategoryName(clean, parentId);
    final labels = specFieldLabels.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final group = specGroupTitle?.trim();
    final row = {
      'name': clean,
      'slug': slug,
      'icon': logoUrl,
      'image_url': bannerUrl,
      'color_hex': colorHex,
      'parent_id': parentId,
      'spec_template_enabled': specTemplateEnabled && labels.isNotEmpty,
      'spec_field_labels': labels,
      'spec_group_title': (group != null && group.isNotEmpty) ? group : null,
    };
    try {
      await _client.from('categories').insert(row);
    } catch (e) {
      if (e.toString().toLowerCase().contains('color_hex')) {
        row.remove('color_hex');
        await _client.from('categories').insert(row);
        return;
      }
      if (e.toString().toLowerCase().contains('spec_group_title')) {
        try {
          row.remove('spec_group_title');
          await _client.from('categories').insert(row);
        } catch (e2) {
          if (e2.toString().toLowerCase().contains('spec_template') ||
              e2.toString().toLowerCase().contains('spec_field')) {
            await _client.from('categories').insert({
              'name': clean,
              'slug': slug,
              'icon': logoUrl,
              'image_url': bannerUrl,
              'color_hex': colorHex,
              'parent_id': parentId,
            });
          } else {
            rethrow;
          }
        }
        return;
      }
      if (e.toString().toLowerCase().contains('spec_template') ||
          e.toString().toLowerCase().contains('spec_field')) {
        await _client.from('categories').insert({
          'name': clean,
          'slug': slug,
          'icon': logoUrl,
          'image_url': bannerUrl,
          'color_hex': colorHex,
          'parent_id': parentId,
        });
        return;
      }
      rethrow;
    }
  }

  static Future<void> updateCategory(
    String categoryId, {
    required String name,
    String? parentId,
    String? logoUrl,
    String? bannerUrl,
    String? colorHex,
    bool specTemplateEnabled = false,
    List<String> specFieldLabels = const [],
    String? specGroupTitle,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) throw AuthException('Nombre de categoría inválido');
    final slug = await _slugForCategoryName(clean, parentId);
    final labels = specFieldLabels.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final group = specGroupTitle?.trim();
    final row = {
      'name': clean,
      'slug': slug,
      'icon': logoUrl,
      'image_url': bannerUrl,
      'color_hex': colorHex,
      'parent_id': parentId,
      'spec_template_enabled': specTemplateEnabled && labels.isNotEmpty,
      'spec_field_labels': labels,
      'spec_group_title': (group != null && group.isNotEmpty) ? group : null,
    };
    try {
      await _client.from('categories').update(row).eq('id', categoryId);
    } catch (e) {
      if (e.toString().toLowerCase().contains('color_hex')) {
        row.remove('color_hex');
        await _client.from('categories').update(row).eq('id', categoryId);
        return;
      }
      if (e.toString().toLowerCase().contains('spec_group_title')) {
        try {
          row.remove('spec_group_title');
          await _client.from('categories').update(row).eq('id', categoryId);
        } catch (e2) {
          if (e2.toString().toLowerCase().contains('spec_template') ||
              e2.toString().toLowerCase().contains('spec_field')) {
            await _client.from('categories').update({
              'name': clean,
              'slug': slug,
              'icon': logoUrl,
              'image_url': bannerUrl,
              'color_hex': colorHex,
              'parent_id': parentId,
            }).eq('id', categoryId);
          } else {
            rethrow;
          }
        }
        return;
      }
      if (e.toString().toLowerCase().contains('spec_template') ||
          e.toString().toLowerCase().contains('spec_field')) {
        await _client.from('categories').update({
          'name': clean,
          'slug': slug,
          'icon': logoUrl,
          'image_url': bannerUrl,
          'color_hex': colorHex,
          'parent_id': parentId,
        }).eq('id', categoryId);
        return;
      }
      rethrow;
    }
  }

  /// Elimina subcategorías y luego la categoría (productos enlazados pueden bloquear el borrado).
  static Future<void> deleteCategory(String categoryId) async {
    await _client.from('categories').delete().eq('parent_id', categoryId);
    await _client.from('categories').delete().eq('id', categoryId);
  }

  static Future<void> clearAllCategories() async {
    final subs = await _client
        .from('categories')
        .select('id')
        .not('parent_id', 'is', null);
    for (final row in List<Map<String, dynamic>>.from(subs)) {
      await _client.from('categories').delete().eq('id', row['id']);
    }
    await _client.from('categories').delete().neq('id', '00000000-0000-0000-0000-000000000000');
  }

  static const _selectMyProductsWithLayout =
      'id, name, description, category_id, price, stock, images, images_layout, specs_json, tags, is_active, is_featured, unit, categories(name, parent_id)';
  static const _selectMyProductsBasic =
      'id, name, description, category_id, price, stock, images, tags, is_active, is_featured, unit, categories(name, parent_id)';
  static const _selectMyProductsLayoutNoSpecs =
      'id, name, description, category_id, price, stock, images, images_layout, tags, is_active, is_featured, unit, categories(name, parent_id)';

  static Future<String?> _currentSellerPortalId() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('profiles_portal')
          .select('id')
          .eq('auth_user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();
      final id = row?['id']?.toString().trim();
      if (id == null || id.isEmpty) return null;
      return id;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMyProducts() async {
    final portalId = await _currentSellerPortalId();
    if (portalId == null) return [];
    return fetchProductsForSeller(portalId);
  }

  static const _profilesEmbed =
      ', seller_id, categories(name, parent_id), profiles_portal!products_seller_id_profiles_portal_fkey(shop_name, email, full_name)';

  /// Todos los productos (solo administrador). Requiere RLS que permita SELECT a filas de cualquier `seller_id`.
  static Future<List<Map<String, dynamic>>> fetchAllProductsForAdmin() async {
    if (!await AuthService.isCurrentUserAdmin()) {
      throw AuthException('Sin permisos de administrador.');
    }

    Future<List<Map<String, dynamic>>> query(String columns) async {
      final data = await _client
          .from('products')
          .select(columns)
          .isFilter('event_ticket_type_id', null)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    }

    Future<List<Map<String, dynamic>>> withProfilesOrNot(String baseCols) async {
      try {
        return await query('$baseCols$_profilesEmbed');
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('profiles_portal') ||
            msg.contains('profiles') ||
            msg.contains('relationship')) {
          try {
            return await query('$baseCols, seller_id, categories(name, parent_id)');
          } catch (_) {
            rethrow;
          }
        }
        rethrow;
      }
    }

    try {
      return await withProfilesOrNot(
        'id, name, description, category_id, price, stock, images, images_layout, specs_json, tags, is_active, is_featured, unit',
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('specs_json')) {
        try {
          return await withProfilesOrNot(
            'id, name, description, category_id, price, stock, images, images_layout, tags, is_active, is_featured, unit',
          );
        } catch (e2) {
          if (e2.toString().toLowerCase().contains('images_layout')) {
            return await withProfilesOrNot(
              'id, name, description, category_id, price, stock, images, tags, is_active, is_featured, unit',
            );
          }
          rethrow;
        }
      }
      if (msg.contains('images_layout')) {
        return await withProfilesOrNot(
          'id, name, description, category_id, price, stock, images, tags, is_active, is_featured, unit',
        );
      }
      rethrow;
    }
  }

  /// Productos de una tienda (`seller_id` en `products` referencia `profiles_portal.id`).
  static Future<List<Map<String, dynamic>>> fetchProductsForSeller(String sellerId) async {
    if (sellerId.isEmpty) return [];

    Future<List<Map<String, dynamic>>> query(String columns) async {
      final data = await _client
          .from('products')
          .select(columns)
          .eq('seller_id', sellerId)
          .isFilter('event_ticket_type_id', null)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    }

    try {
      return await query(_selectMyProductsWithLayout);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('specs_json')) {
        try {
          return await query(_selectMyProductsLayoutNoSpecs);
        } catch (e2) {
          if (e2.toString().toLowerCase().contains('images_layout')) {
            return await query(_selectMyProductsBasic);
          }
          rethrow;
        }
      }
      if (msg.contains('images_layout')) {
        return await query(_selectMyProductsBasic);
      }
      rethrow;
    }
  }

  /// [sellerIdOverride]: `profiles_portal.id` de la tienda destino.
  /// Solo administradores pueden crear para otra tienda.
  static Future<void> createProduct(ProductFormData form, {String? sellerIdOverride}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw AuthException('No hay sesión activa');

    String? sid;
    final o = sellerIdOverride?.trim();
    if (o != null && o.isNotEmpty) {
      if (!await AuthService.isCurrentUserAdmin()) {
        throw AuthException('Solo un administrador puede crear productos para otra tienda.');
      }
      sid = o;
    } else {
      sid = await _currentSellerPortalId();
    }
    if (sid == null || sid.isEmpty) {
      throw AuthException('No se pudo resolver tu tienda en Portal.');
    }
    try {
      await _client.from('products').insert({
        'seller_id': sid,
        'category_id': form.categoryId,
        'name': form.name,
        'description': form.description,
        'price': form.price,
        'stock': form.stock,
        'unit': form.unit,
        'is_active': form.isActive,
        'is_featured': form.isFeatured,
        'images': form.images,
        'images_layout': form.imagesLayout,
        'specs_json': form.specRows.isEmpty ? [] : form.specRows,
        'tags': form.tags,
      });
    } catch (e) {
      if (e.toString().toLowerCase().contains('specs_json')) {
        await _client.from('products').insert({
          'seller_id': sid,
          'category_id': form.categoryId,
          'name': form.name,
          'description': form.description,
          'price': form.price,
          'stock': form.stock,
          'unit': form.unit,
          'is_active': form.isActive,
          'is_featured': form.isFeatured,
          'images': form.images,
          'images_layout': form.imagesLayout,
          'tags': form.tags,
        });
        return;
      }
      rethrow;
    }
  }

  static Future<void> updateProduct(String id, ProductFormData form) async {
    try {
      await _client.from('products').update({
        'category_id': form.categoryId,
        'name': form.name,
        'description': form.description,
        'price': form.price,
        'stock': form.stock,
        'unit': form.unit,
        'is_active': form.isActive,
        'is_featured': form.isFeatured,
        'images': form.images,
        'images_layout': form.imagesLayout,
        'specs_json': form.specRows.isEmpty ? [] : form.specRows,
        'tags': form.tags,
      }).eq('id', id);
    } catch (e) {
      if (e.toString().toLowerCase().contains('specs_json')) {
        await _client.from('products').update({
          'category_id': form.categoryId,
          'name': form.name,
          'description': form.description,
          'price': form.price,
          'stock': form.stock,
          'unit': form.unit,
          'is_active': form.isActive,
          'is_featured': form.isFeatured,
          'images': form.images,
          'images_layout': form.imagesLayout,
          'tags': form.tags,
        }).eq('id', id);
        return;
      }
      rethrow;
    }
  }

  static Future<void> deleteProduct(String id) async {
    await _client.from('products').delete().eq('id', id);
  }
}
