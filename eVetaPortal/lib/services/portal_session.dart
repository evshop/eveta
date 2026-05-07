import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_clients.dart';

/// Centraliza el acceso a la cuenta Portal del usuario actual.
///
/// Reglas:
/// - Toda lectura/escritura de tienda se hace contra `profiles_portal`.
/// - Tras 064, `products.seller_id` y `orders.seller_id` referencian
///   `profiles_portal.id`. Por eso `currentSellerId()` devuelve ese id.
class PortalSession {
  PortalSession._();

  static SupabaseClient get _auth => SupabaseClients.auth;
  static SupabaseClient get _core => SupabaseClients.core;

  /// Cache simple por sesión para evitar consultas repetidas.
  static String? _cachedAuthUid;
  static Map<String, dynamic>? _cachedPortalRow;

  static void invalidateCache() {
    _cachedAuthUid = null;
    _cachedPortalRow = null;
  }

  /// Devuelve la fila de `profiles_portal` para el usuario actual.
  /// Usa la Edge Function puente `portal-seller` para evitar depender
  /// de sesión de usuario en el proyecto Core.
  static Future<Map<String, dynamic>?> currentPortalProfile({
    bool forceRefresh = false,
  }) async {
    final user = _auth.auth.currentUser;
    if (user == null) return null;

    if (!forceRefresh &&
        _cachedAuthUid == user.id &&
        _cachedPortalRow != null) {
      return _cachedPortalRow;
    }

    Map<String, dynamic>? row;
    try {
      final jwt = await SupabaseClients.getPortalAccessToken();
      if (jwt == null || jwt.isEmpty) return null;
      final res = await _core.functions.invoke(
        'portal-seller',
        body: {'action': 'get_store_profile'},
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (res.status == 200 && res.data is Map && res.data['data'] is Map) {
        row = Map<String, dynamic>.from(res.data['data'] as Map);
      }
    } catch (_) {
      row = null;
    }

    _cachedAuthUid = user.id;
    _cachedPortalRow = row;
    return row;
  }

  /// Identificador a usar para filtrar productos/pedidos.
  /// Devuelve `profiles_portal.id` (alineado con FK `products.seller_id`).
  static Future<String?> currentSellerId() async {
    final portal = await currentPortalProfile();
    final id = portal?['id']?.toString().trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  /// Identificador del registro en `profiles_portal` (si existe).
  static Future<String?> currentPortalProfileId() async {
    final portal = await currentPortalProfile();
    final id = portal?['id']?.toString().trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  /// Devuelve true si la cuenta tiene rol admin habilitado en `profiles_portal`.
  static Future<bool> isAdmin() async {
    final portal = await currentPortalProfile();
    return portal?['is_admin'] == true;
  }
}
