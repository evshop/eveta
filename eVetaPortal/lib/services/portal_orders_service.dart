import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Acciones de pedido vía RPC (script `071_portal_delivery_ready_flow.sql`).
class PortalOrdersService {
  PortalOrdersService._();

  static final _client = Supabase.instance.client;

  static Future<void> markReadyForPickup(String orderId) async {
    await _client.rpc<void>(
      'portal_mark_ready_for_pickup',
      params: {'p_order_id': orderId},
    );
  }

  static Future<void> rejectOrder(String orderId) async {
    await _client.rpc<void>(
      'portal_reject_order',
      params: {'p_order_id': orderId},
    );
  }

  static String humanizeError(Object e) {
    if (e is PostgrestException) {
      final m = e.message.trim();
      if (m.isNotEmpty) return m;
    }
    return e.toString();
  }

  static void debugLog(String msg) => debugPrint('[PortalOrders] $msg');
}
