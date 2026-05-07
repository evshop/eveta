import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_clients.dart';

/// Acciones de pedido vía RPC (script `071_portal_delivery_ready_flow.sql`).
class PortalOrdersService {
  PortalOrdersService._();

  static Future<void> markReadyForPickup(String orderId) async {
    final jwt = await SupabaseClients.getPortalAccessToken();
    if (jwt == null || jwt.isEmpty) {
      throw AuthException('No hay sesión activa.');
    }
    final res = await SupabaseClients.core.functions.invoke(
      'portal-seller',
      body: {'action': 'mark_ready_for_pickup', 'order_id': orderId},
      headers: {'Authorization': 'Bearer $jwt'},
    );
    if (res.status != 200) {
      final msg = (res.data is Map && res.data['error'] != null) ? res.data['error'].toString() : 'No se pudo marcar listo.';
      throw AuthException(msg);
    }
  }

  static Future<void> rejectOrder(String orderId) async {
    final jwt = await SupabaseClients.getPortalAccessToken();
    if (jwt == null || jwt.isEmpty) {
      throw AuthException('No hay sesión activa.');
    }
    final res = await SupabaseClients.core.functions.invoke(
      'portal-seller',
      body: {'action': 'reject_order', 'order_id': orderId},
      headers: {'Authorization': 'Bearer $jwt'},
    );
    if (res.status != 200) {
      final msg = (res.data is Map && res.data['error'] != null) ? res.data['error'].toString() : 'No se pudo rechazar.';
      throw AuthException(msg);
    }
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
