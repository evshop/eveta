import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado de la verificación de acceso a la app Portal/Admin.
class PortalGateResult {
  const PortalGateResult._({
    required this.allowed,
    this.errorMessage,
    this.profile,
  });

  final bool allowed;
  final String? errorMessage;
  final Map<String, dynamic>? profile;

  factory PortalGateResult.allow(Map<String, dynamic> profile) =>
      PortalGateResult._(allowed: true, profile: profile);

  factory PortalGateResult.deny(String message) =>
      PortalGateResult._(allowed: false, errorMessage: message);
}

/// Centraliza el gate de acceso por app para eVetaPortal/Admin.
///
/// Reglas:
/// - Bloquea cuentas Delivery (existen en `profiles_delivery`).
/// - Permite únicamente cuentas activas en `profiles_portal` con
///   `is_admin` o `is_seller` en true (admin como rol de la misma cuenta).
/// - Usa el RPC `ensure_portal_membership_for_current_user` para autovincular
///   cuentas legacy (script 051) y cae a consulta directa si no está disponible.
class PortalAuthGate {
  PortalAuthGate._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<PortalGateResult> verifyCurrentSession() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return PortalGateResult.deny('No hay sesión activa.');
    }
    final uid = user.id;
    final email = user.email?.trim().toLowerCase();

    // 1) Cuentas Delivery no pueden entrar a Portal/Admin.
    final deliveryRow = await _findDelivery(uid: uid, email: email);
    if (deliveryRow != null) {
      await _signOut();
      return PortalGateResult.deny(
        'Esta cuenta es de Delivery. Usa una cuenta Portal separada.',
      );
    }

    // 2) Asegura/vincula membresía en profiles_portal.
    Map<String, dynamic>? portalProfile = await _ensurePortalMembership();
    portalProfile ??= await _findPortal(uid: uid, email: email);

    if (portalProfile == null) {
      await _signOut();
      return PortalGateResult.deny(
        'Tu cuenta no está vinculada a Portal. Usa una cuenta Portal separada.',
      );
    }

    final isActive = portalProfile['is_active'] == true;
    final isAdmin = portalProfile['is_admin'] == true;
    final isSeller = portalProfile['is_seller'] == true;
    if (!isActive || (!isAdmin && !isSeller)) {
      await _signOut();
      return PortalGateResult.deny(
        'Tu cuenta no está vinculada a Portal. Usa una cuenta Portal separada.',
      );
    }

    return PortalGateResult.allow(portalProfile);
  }

  static Future<Map<String, dynamic>?> _ensurePortalMembership() async {
    try {
      final ensured = await _client.rpc(
        'ensure_portal_membership_for_current_user',
      );
      if (ensured is Map) {
        return Map<String, dynamic>.from(ensured);
      }
    } catch (_) {
      // RPC no disponible o error: usar consulta directa.
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _findPortal({
    required String uid,
    String? email,
  }) async {
    try {
      final byUid = await _client
          .from('profiles_portal')
          .select('id, is_admin, is_seller, is_active')
          .eq('auth_user_id', uid)
          .maybeSingle();
      if (byUid != null) return Map<String, dynamic>.from(byUid as Map);
      if (email != null && email.isNotEmpty) {
        final byEmail = await _client
            .from('profiles_portal')
            .select('id, is_admin, is_seller, is_active')
            .ilike('email', email)
            .maybeSingle();
        if (byEmail != null) return Map<String, dynamic>.from(byEmail as Map);
      }
    } on PostgrestException catch (_) {
      // Tabla/políticas no disponibles: tratar como no encontrado.
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _findDelivery({
    required String uid,
    String? email,
  }) async {
    try {
      final byUid = await _client
          .from('profiles_delivery')
          .select('id, is_active')
          .eq('auth_user_id', uid)
          .maybeSingle();
      if (byUid != null) return Map<String, dynamic>.from(byUid as Map);
      if (email != null && email.isNotEmpty) {
        final byEmail = await _client
            .from('profiles_delivery')
            .select('id, is_active')
            .ilike('email', email)
            .maybeSingle();
        if (byEmail != null) return Map<String, dynamic>.from(byEmail as Map);
      }
    } on PostgrestException catch (_) {
      // Tabla/políticas no disponibles: ignora.
    }
    return null;
  }

  static Future<void> _signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }
}
