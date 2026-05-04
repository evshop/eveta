import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:eveta/utils/cart_service.dart';
import 'package:eveta/utils/delivery_pricing.dart';

class OrderService {
  OrderService._();

  static final _client = Supabase.instance.client;

  static String _firstImage(dynamic images) {
    if (images is List && images.isNotEmpty) return images.first.toString();
    if (images is String && images.isNotEmpty) return images;
    return '';
  }

  static double _safeMoney(num? value) {
    if (value == null) return 0.0;
    final d = value.toDouble();
    if (!d.isFinite) return 0.0;
    return double.parse(d.toStringAsFixed(2));
  }

  /// [sellerIds] son `profiles_portal.id` (FK desde products/orders.seller_id).
  static Future<Map<String, Map<String, dynamic>>> _pickupBySellerIds(
    List<String> sellerIds,
  ) async {
    final bySeller = <String, Map<String, dynamic>>{};
    if (sellerIds.isEmpty) return bySeller;

    try {
      final portalRaw = await _client
          .from('profiles_portal')
          .select('id, shop_lat, shop_lng')
          .inFilter('id', sellerIds);
      for (final row in List<Map<String, dynamic>>.from(portalRaw as List)) {
        final id = row['id']?.toString().trim();
        if (id == null || id.isEmpty) continue;
        bySeller[id] = row;
      }
    } catch (_) {}

    return bySeller;
  }

  /// Crea uno o más pedidos (uno por tienda) desde el carrito. Vacía el carrito si todo OK.
  static Future<List<String>> placeOrdersFromCart({
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Inicia sesión para pedir.');
    }

    final cart = await CartService.getCartItems();
    if (cart.isEmpty) throw Exception('El carrito está vacío.');

    final ids = cart.map((e) => e.productId).toList();
    final rows = await _client
        .from('products')
        .select('id, seller_id, price, name, images, stock')
        .inFilter('id', ids);

    final products = List<Map<String, dynamic>>.from(rows as List);
    final byId = {for (final p in products) p['id'].toString(): p};

    final missing = ids.where((id) => !byId.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      throw Exception('Algunos productos ya no existen. Actualiza el carrito.');
    }

    final drop = LatLng(dropoffLat, dropoffLng);
    final pickup = DeliveryPricing.defaultPickup;
    final distanceKm = DeliveryPricing.haversineKm(pickup, drop);
    final totalDeliveryFee = DeliveryPricing.feeForDistanceKm(distanceKm);

    final bySeller = <String, List<CartItem>>{};
    for (final item in cart) {
      final p = byId[item.productId]!;
      final sid = p['seller_id']?.toString();
      if (sid == null || sid.isEmpty) {
        throw Exception('Producto sin tienda: ${item.name}');
      }
      bySeller.putIfAbsent(sid, () => []).add(item);
    }

    final sellerCount = bySeller.length;
    final feeEach = DeliveryPricing.splitFee(totalDeliveryFee, sellerCount);
    final sellerIds = bySeller.keys.toList();
    final sellerMap = await _pickupBySellerIds(sellerIds);

    final createdOrderIds = <String>[];

    for (final entry in bySeller.entries) {
      final sellerId = entry.key;
      final items = entry.value;
      final sellerProfile = sellerMap[sellerId];
      final sellerLat = (sellerProfile?['shop_lat'] is num)
          ? (sellerProfile!['shop_lat'] as num).toDouble()
          : double.tryParse(sellerProfile?['shop_lat']?.toString() ?? '');
      final sellerLng = (sellerProfile?['shop_lng'] is num)
          ? (sellerProfile!['shop_lng'] as num).toDouble()
          : double.tryParse(sellerProfile?['shop_lng']?.toString() ?? '');
      final pickup = (sellerLat != null && sellerLng != null)
          ? LatLng(sellerLat, sellerLng)
          : DeliveryPricing.defaultPickup;

      double subtotal = 0;
      final lineRows = <Map<String, dynamic>>[];

      for (final c in items) {
        final p = byId[c.productId]!;
        final price = (p['price'] is num)
            ? (p['price'] as num).toDouble()
            : double.tryParse(p['price']?.toString() ?? '0') ?? 0;
        final stock = (p['stock'] is int)
            ? p['stock'] as int
            : int.tryParse(p['stock']?.toString() ?? '0') ?? 0;
        if (stock < c.quantity) {
          throw Exception('Stock insuficiente: ${p['name'] ?? c.name}');
        }
        final line = price * c.quantity;
        subtotal += line;
        lineRows.add({
          'product_id': c.productId,
          'seller_id': sellerId,
          'name_snapshot': (p['name'] ?? c.name).toString(),
          // Columna en Postgres suele ser `unit_price` (no `price_unit`).
          'unit_price': price,
          'quantity': c.quantity,
          // Algunas BD tienen `total` NOT NULL en order_items.
          'total': _safeMoney(line),
          'line_total': line,
          'image_url': _firstImage(p['images']),
        });
      }

      final safeSubtotal = _safeMoney(subtotal);
      final sellerDistanceKm = DeliveryPricing.haversineKm(pickup, drop);
      final safeFeeEach = _safeMoney(
        sellerCount <= 1 ? DeliveryPricing.feeForDistanceKm(sellerDistanceKm) : feeEach,
      );
      final total = _safeMoney(safeSubtotal + safeFeeEach);

      final orderInsert = await _client
          .from('orders')
          .insert({
            'buyer_id': user.id,
            'seller_id': sellerId,
            'subtotal': safeSubtotal,
            'delivery_fee': safeFeeEach,
            'total': total,
            'distance_km': _safeMoney(sellerDistanceKm),
            // Portal / tienda usan `pending` para pedidos nuevos.
            'status': 'pending',
            'delivery_status': 'awaiting_driver',
            'dropoff_address': dropoffAddress,
            'dropoff_lat': dropoffLat,
            'dropoff_lng': dropoffLng,
            'pickup_lat': pickup.latitude,
            'pickup_lng': pickup.longitude,
            'currency': 'Bs',
          })
          .select('id')
          .single();

      final orderId = orderInsert['id'].toString();

      for (final row in lineRows) {
        row['order_id'] = orderId;
      }

      await _client.from('order_items').insert(lineRows);
      createdOrderIds.add(orderId);
    }

    await CartService.clearCart();
    debugPrint('Pedidos creados: $createdOrderIds');
    return createdOrderIds;
  }

  static String humanizeOrderError(Object e) {
    if (e is PostgrestException) {
      final m = e.message.trim();
      final h = (e.hint ?? '').trim();
      if (m.isNotEmpty && h.isNotEmpty) return '$m\n$h';
      if (m.isNotEmpty) return m;
    }
    return e.toString();
  }

  static Future<List<Map<String, dynamic>>> fetchMyOrders() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('orders')
        .select(
          'id, subtotal, delivery_fee, total, distance_km, status, delivery_status, '
          'dropoff_address, created_at, seller_id',
        )
        .eq('buyer_id', user.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<void> issueTicketsForOrders(List<String> orderIds) async {
    if (orderIds.isEmpty) return;
    for (final orderId in orderIds) {
      try {
        await _client.rpc('issue_tickets_on_order_paid', params: {
          'p_order_id': orderId,
        });
      } catch (e) {
        debugPrint('No se pudieron emitir tickets para orden $orderId: $e');
      }
    }
  }
}
