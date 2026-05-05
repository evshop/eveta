import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryApi {
  DeliveryApi._();

  static final _client = Supabase.instance.client;

  /// [sellerIds] son `profiles_portal.id` (FK desde orders.seller_id tras 064).
  static Future<Map<String, Map<String, dynamic>>> _sellerStoreByPortalId(
    List<String> sellerIds,
  ) async {
    final bySeller = <String, Map<String, dynamic>>{};
    if (sellerIds.isEmpty) return bySeller;

    try {
      final portalRaw = await _client
          .from('profiles_portal')
          .select('id, shop_name, shop_address, shop_location_photos')
          .inFilter('id', sellerIds);
      for (final row in List<Map<String, dynamic>>.from(portalRaw as List)) {
        final id = row['id']?.toString().trim();
        if (id == null || id.isEmpty) continue;
        bySeller[id] = row;
      }
    } catch (_) {}

    return bySeller;
  }

  /// Pedidos sin repartidor (pool tipo Yango).
  static Future<List<Map<String, dynamic>>> fetchPool() async {
    // Una sola cadena (sin concatenar líneas) evita URLs PostgREST corruptas en algunos builds.
    const poolSelect =
        'id,seller_id,total,pickup_lat,pickup_lng,dropoff_lat,dropoff_lng,dropoff_address,delivery_fee,distance_km,buyer_display_name,delivery_status,created_at,order_items(image_url,name_snapshot)';
    final rawRows = await _client
        .from('orders')
        .select(poolSelect)
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
    final bySeller = await _sellerStoreByPortalId(sellerIds);
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
    const mineSelect =
        'id,seller_id,total,pickup_lat,pickup_lng,dropoff_lat,dropoff_lng,dropoff_address,delivery_fee,distance_km,buyer_display_name,delivery_status,created_at,order_items(image_url,name_snapshot)';
    final rawRows = await _client
        .from('orders')
        .select(mineSelect)
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
    final bySeller = await _sellerStoreByPortalId(sellerIds);
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

  /// Estado en línea del repartidor actual (`profiles_delivery.is_online`).
  static Future<bool> fetchMyOnlineStatus() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final row = await _client
          .from('profiles_delivery')
          .select('is_online')
          .eq('auth_user_id', uid)
          .maybeSingle();
      if (row == null) return false;
      return row['is_online'] == true;
    } on PostgrestException catch (_) {
      return false;
    }
  }

  static Future<void> setMyOnlineStatus(bool online) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('profiles_delivery')
        .update({'is_online': online})
        .eq('auth_user_id', uid);
  }

  /// Perfil del repartidor actual (avatar / nombre para el mapa).
  static Future<Map<String, dynamic>?> fetchMyDeliveryProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('profiles_delivery')
          .select('full_name, email')
          .eq('auth_user_id', uid)
          .maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row as Map);
    } on PostgrestException catch (_) {
      return null;
    }
  }

  static void debugLog(Object o) => debugPrint('[Delivery] $o');
}
