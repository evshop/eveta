import 'package:supabase_flutter/supabase_flutter.dart';

/// Centraliza el acceso a la cuenta Portal del usuario actual.
///
/// Reglas:
/// - Toda lectura/escritura de tienda se hace contra `profiles_portal`.
/// - Para querys de productos/pedidos cuyos seller_id apuntan a `profiles.id`
///   (esquema legacy), usamos `legacy_profile_id` cuando esté disponible.
/// - Si no hay legacy_profile_id (cuenta Portal nueva), caemos a `auth.uid()`.
class PortalSession {
  PortalSession._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Cache simple por sesión para evitar consultas repetidas.
  static String? _cachedAuthUid;
  static Map<String, dynamic>? _cachedPortalRow;

  static void invalidateCache() {
    _cachedAuthUid = null;
    _cachedPortalRow = null;
  }

  /// Devuelve la fila de `profiles_portal` para el usuario actual.
  /// Si no existe, intenta autovincular con `ensure_portal_membership_for_current_user`.
  static Future<Map<String, dynamic>?> currentPortalProfile({
    bool forceRefresh = false,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    if (!forceRefresh &&
        _cachedAuthUid == user.id &&
        _cachedPortalRow != null) {
      return _cachedPortalRow;
    }

    Map<String, dynamic>? row;
    try {
      final raw = await _client
          .from('profiles_portal')
          .select(
            'id, auth_user_id, legacy_profile_id, email, full_name, '
            'avatar_url, phone, address, username, '
            'shop_name, shop_description, shop_logo_url, shop_banner_url, '
            'shop_border_color, shop_address, shop_lat, shop_lng, '
            'shop_location_photos, is_admin, is_seller, is_active',
          )
          .eq('auth_user_id', user.id)
          .maybeSingle();
      if (raw != null) row = Map<String, dynamic>.from(raw as Map);
    } on PostgrestException {
      row = null;
    }

    // Autovincula si aún no existe pero hay legacy en profiles.
    if (row == null) {
      try {
        final ensured =
            await _client.rpc('ensure_portal_membership_for_current_user');
        if (ensured is Map) {
          row = Map<String, dynamic>.from(ensured);
        }
      } catch (_) {
        // RPC no disponible: nada que hacer.
      }
    }

    _cachedAuthUid = user.id;
    _cachedPortalRow = row;
    return row;
  }

  /// Identificador a usar para filtrar productos/pedidos cuyos `seller_id`
  /// referencian a `profiles.id` (esquema legacy).
  /// - Si hay `legacy_profile_id` en `profiles_portal`, lo usa.
  /// - En caso contrario, usa `auth.uid()`.
  static Future<String?> currentSellerId() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final portal = await currentPortalProfile();
    final legacy = portal?['legacy_profile_id']?.toString().trim();
    if (legacy != null && legacy.isNotEmpty) return legacy;
    return user.id;
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
