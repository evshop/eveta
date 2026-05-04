import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryApi {
  DeliveryApi._();

  static final _client = Supabase.instance.client;

  static Future<Map<String, Map<String, dynamic>>> _sellerStoreByLegacyId(
    List<String> sellerIds,
  ) async {
    final bySeller = <String, Map<String, dynamic>>{};
    if (sellerIds.isEmpty) return bySeller;

    // Primero prioriza datos de Portal (fuente canónica de tienda).
    try {
      final portalRaw = await _client
          .from('profiles_portal')
          .select('legacy_profile_id, shop_name, shop_address, shop_location_photos')
          .inFilter('legacy_profile_id', sellerIds);
      for (final row in List<Map<String, dynamic>>.from(portalRaw as List)) {
        final legacyId = row['legacy_profile_id']?.toString().trim();
        if (legacyId == null || legacyId.isEmpty) continue;
        bySeller[legacyId] = row;
      }
    } catch (_) {
      // Entornos sin tabla/policies nuevas: cae a legacy `profiles`.
    }

    // Fallback para cuentas Shop puras (o entornos legacy).
    final unresolved = sellerIds.where((id) => !bySeller.containsKey(id)).toList();
    if (unresolved.isEmpty) return bySeller;
    try {
      final sellersRaw = await _client
          .from('profiles')
          .select('id, shop_name, shop_address, shop_location_photos')
          .inFilter('id', unresolved);
      for (final row in List<Map<String, dynamic>>.from(sellersRaw as List)) {
        final id = row['id']?.toString().trim();
        if (id == null || id.isEmpty) continue;
        bySeller[id] = row;
      }
    } catch (_) {}

    return bySeller;
  }

  /// Pedidos sin repartidor (pool tipo Yango).
  static Future<List<Map<String, dynamic>>> fetchPool() async {
    final rawRows = await _client
        .from('orders')
        .select(
          'id, seller_id, total, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, dropoff_address, '
          'delivery_status, created_at, order_items(image_url)',
        )
        .eq('delivery_status', 'awaiting_driver')
        .order('created_at', ascending: true);
    final rows = List<Map<String, dynamic>>.from(rawRows as List);
    final sellerIds = rows
        .map((r) => r['seller_id']?.toString())
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();
    if (sellerIds.isEmpty) return rows;
    final bySeller = await _sellerStoreByLegacyId(sellerIds);
    for (final order in rows) {
      final sid = order['seller_id']?.toString() ?? '';
      final shop = bySeller[sid];
      if (shop == null) continue;
      order['store_name'] = shop['shop_name'];
      order['store_address'] = shop['shop_address'];
      order['store_location_photos'] = shop['shop_location_photos'];
    }
    return rows;
  }

  /// Pedidos asignados al repartidor actual.
  static Future<List<Map<String, dynamic>>> fetchMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rawRows = await _client
        .from('orders')
        .select(
          'id, seller_id, total, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, dropoff_address, '
          'delivery_status, created_at',
        )
        .eq('driver_id', uid)
        .inFilter('delivery_status', ['driver_assigned', 'picked_up'])
        .order('created_at', ascending: false);
    final rows = List<Map<String, dynamic>>.from(rawRows as List);
    final sellerIds = rows
        .map((r) => r['seller_id']?.toString())
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();
    if (sellerIds.isEmpty) return rows;
    final bySeller = await _sellerStoreByLegacyId(sellerIds);
    for (final order in rows) {
      final sid = order['seller_id']?.toString() ?? '';
      final shop = bySeller[sid];
      if (shop == null) continue;
      order['store_name'] = shop['shop_name'];
      order['store_address'] = shop['shop_address'];
      order['store_location_photos'] = shop['shop_location_photos'];
    }
    return rows;
  }

  static Future<void> acceptOrder(String orderId) async {
    await _client.rpc<void>(
      'accept_delivery_order',
      params: {'p_order_id': orderId},
    );
  }

  static Future<void> advanceStatus(String orderId, String next) async {
    await _client.rpc<void>(
      'advance_delivery_status',
      params: {
        'p_order_id': orderId,
        'p_next': next,
      },
    );
  }

  static void debugLog(Object o) => debugPrint('[Delivery] $o');
}
