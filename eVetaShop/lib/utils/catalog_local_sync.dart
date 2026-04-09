import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:eveta/utils/cart_service.dart';
import 'package:eveta/utils/favorites_service.dart';

/// Alinea carrito y favoritos locales con el catálogo en Supabase:
/// quita productos inexistentes, inactivos o sin stock; en el carrito ajusta cantidad al stock.
class CatalogLocalSync {
  CatalogLocalSync._();

  static int _parseStock(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static bool _isSellable(Map<String, dynamic> row) {
    final active = row['is_active'] == true;
    final stock = _parseStock(row['stock']);
    return active && stock > 0;
  }

  static Future<void> syncCartAndFavoritesWithCatalog() async {
    final cart = await CartService.getCartItems();
    final favs = await FavoritesService.getFavorites();
    final ids = <String>{};
    for (final c in cart) {
      if (c.productId.isNotEmpty) ids.add(c.productId);
    }
    for (final f in favs) {
      if (f.productId.isNotEmpty) ids.add(f.productId);
    }
    if (ids.isEmpty) return;

    List<Map<String, dynamic>> rows;
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select('id, is_active, stock')
          .inFilter('id', ids.toList());
      rows = List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('CatalogLocalSync: $e');
      return;
    }

    final byId = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final id = r['id']?.toString() ?? '';
      if (id.isNotEmpty) byId[id] = r;
    }

    final newCart = <CartItem>[];
    for (final item in cart) {
      final row = byId[item.productId];
      if (row == null || !_isSellable(row)) continue;
      final stock = _parseStock(row['stock']);
      var qty = item.quantity;
      if (qty > stock) qty = stock;
      if (qty <= 0) continue;
      newCart.add(item.copyWith(quantity: qty, stock: stock));
    }
    await CartService.replaceCartItems(newCart);

    final newFavs = <FavoriteItem>[];
    for (final item in favs) {
      final row = byId[item.productId];
      if (row == null || !_isSellable(row)) continue;
      final stock = _parseStock(row['stock']);
      newFavs.add(FavoriteItem(
        productId: item.productId,
        name: item.name,
        price: item.price,
        imageUrl: item.imageUrl,
        originalPrice: item.originalPrice,
        stock: stock,
        rating: item.rating,
        reviewCount: item.reviewCount,
      ));
    }
    await FavoritesService.replaceFavorites(newFavs);
  }
}
