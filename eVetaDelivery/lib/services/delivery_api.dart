import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryApi {
  DeliveryApi._();

  static final _client = Supabase.instance.client;

  /// Pedidos sin repartidor (pool tipo Yango).
  static Future<List<Map<String, dynamic>>> fetchPool() async {
    final rows = await _client
        .from('orders')
        .select(
          'id, total, dropoff_lat, dropoff_lng, dropoff_address, delivery_status, created_at',
        )
        .eq('delivery_status', 'awaiting_driver')
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Pedidos asignados al repartidor actual.
  static Future<List<Map<String, dynamic>>> fetchMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('orders')
        .select(
          'id, total, dropoff_lat, dropoff_lng, dropoff_address, delivery_status, created_at',
        )
        .eq('driver_id', uid)
        .inFilter('delivery_status', ['driver_assigned', 'picked_up'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
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
