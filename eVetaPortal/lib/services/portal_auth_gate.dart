import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_clients.dart';

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
/// Usa la Edge Function `portal-seller` (`verify_gate`) para validar contra
/// Core con service role, sin depender de JWT del proyecto Core en PostgREST.
///
/// - Bloquea solo si existe `profiles_delivery` con el mismo **auth_user_id**
///   del usuario en Portal Auth (no basta el mismo correo).
/// - Permite cuentas activas en `profiles_portal` con `is_admin` o `is_seller`.
class PortalAuthGate {
  PortalAuthGate._();

  static SupabaseClient get _auth => SupabaseClients.auth;
  static SupabaseClient get _core => SupabaseClients.core;

  static Future<PortalGateResult> verifyCurrentSession() async {
    final user = _auth.auth.currentUser;
    if (user == null) {
      return PortalGateResult.deny('No hay sesión activa.');
    }
    final jwt = await SupabaseClients.getPortalAccessToken();
    if (jwt == null || jwt.isEmpty) {
      return PortalGateResult.deny('No hay sesión activa.');
    }

    try {
      final res = await _core.functions.invoke(
        'portal-seller',
        body: {'action': 'verify_gate'},
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (res.status == 401) {
        await _signOut();
        return PortalGateResult.deny('No hay sesión activa.');
      }

      if (res.status == 403) {
        final err = (res.data is Map && res.data['error'] != null)
            ? res.data['error'].toString()
            : '';
        if (err == 'forbidden_delivery_account') {
          await _signOut();
          return PortalGateResult.deny(
            'Esta cuenta es de Delivery. Usa una cuenta Portal separada.',
          );
        }
        await _signOut();
        return PortalGateResult.deny(
          'Tu cuenta no está vinculada a Portal. Usa una cuenta Portal separada.',
        );
      }

      if (res.status != 200 || res.data is! Map) {
        await _signOut();
        return PortalGateResult.deny(
          'Tu cuenta no está vinculada a Portal. Usa una cuenta Portal separada.',
        );
      }
      final raw = res.data['data'];
      if (raw is! Map) {
        await _signOut();
        return PortalGateResult.deny(
          'Tu cuenta no está vinculada a Portal. Usa una cuenta Portal separada.',
        );
      }
      final profile = Map<String, dynamic>.from(raw);
      return PortalGateResult.allow(profile);
    } catch (_) {
      await _signOut();
      return PortalGateResult.deny(
        'Tu cuenta no está vinculada a Portal. Usa una cuenta Portal separada.',
      );
    }
  }

  static Future<void> _signOut() async {
    try {
      await _auth.auth.signOut();
    } catch (_) {}
  }
}
