import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final String productId;
  final String name;
  final String price;
  final String imageUrl;
  final int quantity;
  final int stock;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.quantity,
    required this.stock,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'price': price,
        'imageUrl': imageUrl,
        'quantity': quantity,
        'stock': stock,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        productId: json['productId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        price: json['price']?.toString() ?? '0',
        imageUrl: json['imageUrl']?.toString() ?? '',
        quantity: json['quantity'] is int ? json['quantity'] as int : int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
        stock: json['stock'] is int ? json['stock'] as int : int.tryParse(json['stock']?.toString() ?? '0') ?? 0,
      );

  CartItem copyWith({int? quantity, int? stock}) => CartItem(
        productId: productId,
        name: name,
        price: price,
        imageUrl: imageUrl,
        quantity: quantity ?? this.quantity,
        stock: stock ?? this.stock,
      );
}

class CartService {
  static const String _cartKey = 'cart_items';
  static final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

  static Future<void> init() async {
    cartCountNotifier.value = await getCartCount();
  }

  static Future<List<CartItem>> getCartItems() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString(_cartKey);
    if (cartJson == null || cartJson.isEmpty) return [];

    final List<dynamic> decoded = jsonDecode(cartJson);
    return decoded.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> addToCart(CartItem item) async {
    final items = await getCartItems();
    final existingIndex = items.indexWhere((i) => i.productId == item.productId);

    if (existingIndex >= 0) {
      final existing = items[existingIndex];
      final newQty = existing.quantity + item.quantity;
      if (newQty <= (item.stock > 0 ? item.stock : 999)) { // Fallback stock
        items[existingIndex] = existing.copyWith(quantity: newQty);
      }
    } else {
      items.add(item);
    }

    await _saveCart(items);
    cartCountNotifier.value = await getCartCount();
  }

  static Future<void> updateQuantity(String productId, int quantity) async {
    final items = await getCartItems();
    final index = items.indexWhere((i) => i.productId == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        items.removeAt(index);
      } else {
        items[index] = items[index].copyWith(quantity: quantity);
      }
      await _saveCart(items);
      cartCountNotifier.value = await getCartCount();
    }
  }

  static Future<void> removeFromCart(String productId) async {
    final items = await getCartItems();
    items.removeWhere((i) => i.productId == productId);
    await _saveCart(items);
    cartCountNotifier.value = await getCartCount();
  }

  static Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
    cartCountNotifier.value = 0;
  }

  /// Reemplaza el carrito completo (p. ej. tras validar contra el catálogo en Supabase).
  static Future<void> replaceCartItems(List<CartItem> items) async {
    await _saveCart(items);
    cartCountNotifier.value = await getCartCount();
  }

  static Future<void> _saveCart(List<CartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_cartKey, encoded);
  }

  static Future<int> getCartCount() async {
    final items = await getCartItems();
    int count = 0;
    for (final item in items) {
      count += item.quantity;
    }
    return count;
  }

  static Future<double> getCartTotal() async {
    final items = await getCartItems();
    double total = 0;
    for (final item in items) {
      final price = double.tryParse(item.price) ?? 0;
      total += price * item.quantity;
    }
    return total;
  }
}