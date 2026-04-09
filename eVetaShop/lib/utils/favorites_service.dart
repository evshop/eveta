import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Datos guardados por producto favorito (tarjeta resumida).
class FavoriteItem {
  FavoriteItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.originalPrice,
    this.stock = 0,
    this.rating = 0,
    this.reviewCount = 0,
  });

  final String productId;
  final String name;
  final String price;
  final String imageUrl;
  final String? originalPrice;
  final int stock;
  final double rating;
  final int reviewCount;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'price': price,
        'imageUrl': imageUrl,
        'originalPrice': originalPrice,
        'stock': stock,
        'rating': rating,
        'reviewCount': reviewCount,
      };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
        productId: json['productId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        price: json['price']?.toString() ?? '0',
        imageUrl: json['imageUrl']?.toString() ?? '',
        originalPrice: json['originalPrice']?.toString(),
        stock: json['stock'] is int ? json['stock'] as int : int.tryParse(json['stock']?.toString() ?? '0') ?? 0,
        rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
        reviewCount: json['reviewCount'] is int ? json['reviewCount'] as int : int.tryParse(json['reviewCount']?.toString() ?? '0') ?? 0,
      );

  factory FavoriteItem.fromProductMap(Map<String, dynamic> p) {
    String imageUrl = '';
    final images = p['images'];
    if (images is List && images.isNotEmpty) {
      imageUrl = images.first.toString();
    } else if (images is String && images.isNotEmpty) {
      imageUrl = images;
    }
    return FavoriteItem(
      productId: p['id']?.toString() ?? '',
      name: p['name']?.toString() ?? 'Sin nombre',
      price: p['price']?.toString() ?? '0',
      imageUrl: imageUrl,
      originalPrice: p['original_price']?.toString(),
      stock: p['stock'] is int ? p['stock'] as int : int.tryParse(p['stock']?.toString() ?? '0') ?? 0,
      rating: (p['rating'] is num) ? (p['rating'] as num).toDouble() : double.tryParse(p['rating']?.toString() ?? '0') ?? 0,
      reviewCount: p['review_count'] is int ? p['review_count'] as int : int.tryParse(p['review_count']?.toString() ?? '0') ?? 0,
    );
  }
}

class FavoritesService {
  static const String _key = 'favorite_products';
  static final ValueNotifier<int> favoritesCountNotifier = ValueNotifier<int>(0);

  static Future<void> init() async {
    favoritesCountNotifier.value = (await getFavorites()).length;
  }

  static Future<List<FavoriteItem>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => FavoriteItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> isFavorite(String productId) async {
    final list = await getFavorites();
    return list.any((e) => e.productId == productId);
  }

  static Future<void> _save(List<FavoriteItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
    favoritesCountNotifier.value = items.length;
  }

  static Future<void> addFavorite(FavoriteItem item) async {
    if (item.productId.isEmpty) return;
    final items = await getFavorites();
    items.removeWhere((e) => e.productId == item.productId);
    items.insert(0, item);
    await _save(items);
  }

  static Future<void> removeFavorite(String productId) async {
    final items = await getFavorites();
    items.removeWhere((e) => e.productId == productId);
    await _save(items);
  }

  /// Reemplaza la lista completa (p. ej. tras validar contra el catálogo en Supabase).
  static Future<void> replaceFavorites(List<FavoriteItem> items) async {
    await _save(items);
  }

  static Future<bool> toggleFavorite(FavoriteItem item) async {
    if (item.productId.isEmpty) return false;
    final exists = await isFavorite(item.productId);
    if (exists) {
      await removeFavorite(item.productId);
      return false;
    }
    await addFavorite(item);
    return true;
  }
}
