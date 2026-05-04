import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado de la verificación de acceso a la app Delivery.
class DeliveryGateResult {
  const DeliveryGateResult._({required this.allowed, this.errorMessage});

  final bool allowed;
  final String? errorMessage;

  static const DeliveryGateResult ok = DeliveryGateResult._(allowed: true);

  factory DeliveryGateResult.deny(String message) =>
      DeliveryGateResult._(allowed: false, errorMessage: message);
}

/// Centraliza el gate de acceso por app para eVetaDelivery.
///
/// Reglas:
/// - Bloquea cuentas Portal/Admin (existen en `profiles_portal`).
/// - Bloquea cuentas Shop puras (existen solo en `profiles` y no en `profiles_delivery`).
/// - Permite únicamente cuentas presentes y activas en `profiles_delivery`.
class DeliveryAuthGate {
  DeliveryAuthGate._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Verifica al usuario autenticado actualmente. Si no procede, hace `signOut`
  /// y devuelve un mensaje listo para mostrar al usuario.
  static Future<DeliveryGateResult> verifyCurrentSession() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return DeliveryGateResult.deny('No hay sesión activa.');
    }
    final uid = user.id;
    final email = user.email?.trim().toLowerCase();

    // 1) Bloquea cuentas Portal/Admin.
    final isPortal = await _existsIn('profiles_portal', uid: uid, email: email);
    if (isPortal) {
      await _signOut();
      return DeliveryGateResult.deny(
        'Esta cuenta es de Portal/Admin. Usa una cuenta Delivery separada.',
      );
    }

    // 2) Verifica membresía en profiles_delivery (uid + fallback por email).
    Map<String, dynamic>? delivery =
        await _findDeliveryProfile(uid: uid, email: email);

    // 2.b) Si no hay vínculo, intenta autolink (script 054).
    delivery ??= await _ensureDeliveryMembership();

    if (delivery == null) {
      await _signOut();
      return DeliveryGateResult.deny(
        'Esta cuenta no está vinculada a Delivery. Usa una cuenta Delivery separada.',
      );
    }
    final isActive = delivery['is_active'] == true;
    if (!isActive) {
      await _signOut();
      return DeliveryGateResult.deny(
        'Tu cuenta Delivery está inactiva. Contacta al administrador.',
      );
    }

    return DeliveryGateResult.ok;
  }

  static Future<Map<String, dynamic>?> _ensureDeliveryMembership() async {
    try {
      final ensured = await _client.rpc(
        'ensure_delivery_membership_for_current_user',
      );
      if (ensured is Map) {
        return Map<String, dynamic>.from(ensured);
      }
    } catch (_) {
      // RPC no disponible (script 054 aún no aplicado) o sin permisos.
    }
    return null;
  }

  static Future<bool> _existsIn(
    String table, {
    required String uid,
    String? email,
  }) async {
    try {
      final byUid = await _client
          .from(table)
          .select('id')
          .eq('auth_user_id', uid)
          .maybeSingle();
      if (byUid != null) return true;
      if (email != null && email.isNotEmpty) {
        final byEmail = await _client
            .from(table)
            .select('id')
            .ilike('email', email)
            .maybeSingle();
        if (byEmail != null) return true;
      }
    } on PostgrestException catch (_) {
      // Tabla/políticas no disponibles en entornos antiguos: no bloquea por error.
    }
    return false;
  }

  static Future<Map<String, dynamic>?> _findDeliveryProfile({
    required String uid,
    String? email,
  }) async {
    try {
      final byUid = await _client
          .from('profiles_delivery')
          .select('id, is_active, auth_user_id, email')
          .eq('auth_user_id', uid)
          .maybeSingle();
      if (byUid != null) return Map<String, dynamic>.from(byUid as Map);
      if (email != null && email.isNotEmpty) {
        final byEmail = await _client
            .from('profiles_delivery')
            .select('id, is_active, auth_user_id, email')
            .ilike('email', email)
            .maybeSingle();
        if (byEmail != null) return Map<String, dynamic>.from(byEmail as Map);
      }
    } on PostgrestException catch (_) {
      // Tabla/políticas no disponibles: no podemos verificar; tratamos como no encontrado.
    }
    return null;
  }

  static Future<void> _signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }
}
