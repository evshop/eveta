import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    if (response.user == null) {
      throw AuthException('No se pudo iniciar sesión.');
    }
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Envía el correo de recuperación de contraseña de Supabase Auth (no revela la contraseña actual).
  static Future<void> sendPasswordResetEmail(String email) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) throw AuthException('Correo vacío.');
    await _client.auth.resetPasswordForEmail(e);
  }

  static Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final rpcResult = await _client.rpc('profile_is_admin');
        if (rpcResult is bool) return rpcResult;
      } catch (_) {
        // Fallback below.
      }
      try {
        final profile = await _client
            .from('profiles')
            .select('id, is_admin')
            .eq('id', user.id)
            .maybeSingle();
        if (profile?['is_admin'] == true) return true;
      } catch (_) {
        // Retry once for transient startup/session timing.
      }
      try {
        final portal = await _client
            .from('profiles_portal')
            .select('is_admin')
            .eq('auth_user_id', user.id)
            .eq('is_active', true)
            .maybeSingle();
        if (portal?['is_admin'] == true) return true;
      } catch (_) {
        // Tabla o política ausente en proyectos antiguos.
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    return false;
  }

  static Future<bool> currentUserProfileExists() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final profile = await _client.from('profiles').select('id').eq('id', user.id).maybeSingle();
    return profile != null;
  }

  static Future<Map<String, dynamic>?> fetchMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select('id, full_name, email, shop_name, shop_description, shop_logo_url, shop_banner_url')
          .eq('id', user.id)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (e) {
      // Compatibilidad si la columna shop_banner_url aún no existe.
      if (e.toString().toLowerCase().contains('shop_banner_url')) {
        final row = await _client
            .from('profiles')
            .select('id, full_name, email, shop_name, shop_description, shop_logo_url, avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        if (row == null) return null;
        final m = Map<String, dynamic>.from(row);
        m['shop_banner_url'] = m['avatar_url'];
        return m;
      }
      rethrow;
    }
  }

  static Future<void> updateMyStoreProfile({
    required String shopName,
    required String shopDescription,
    String? shopLogoUrl,
    String? shopBannerUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw AuthException('No hay sesión activa');
    final row = {
      'shop_name': shopName.trim(),
      'shop_description': shopDescription.trim(),
      'shop_logo_url': shopLogoUrl,
      'shop_banner_url': shopBannerUrl,
      'is_seller': true,
    };
    try {
      final updated = await _client.from('profiles').update(row).eq('id', user.id).select('id');
      if ((updated as List).isEmpty) {
        throw AuthException(
          'La base de datos no aplicó el cambio (0 filas). Revisa políticas RLS en profiles para tu usuario.',
        );
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      if (e.toString().toLowerCase().contains('shop_banner_url')) {
        final updated = await _client.from('profiles').update({
          'shop_name': shopName.trim(),
          'shop_description': shopDescription.trim(),
          'shop_logo_url': shopLogoUrl,
          // Fallback temporal: avatar_url como banner
          'avatar_url': shopBannerUrl,
          'is_seller': true,
        }).eq('id', user.id).select('id');
        if ((updated as List).isEmpty) {
          throw AuthException(
            'La base de datos no aplicó el cambio (0 filas). Revisa políticas RLS en profiles.',
          );
        }
        return;
      }
      rethrow;
    }
  }

  static const _partnerColsBase =
      'id,email,full_name,shop_name,shop_description,shop_logo_url,shop_banner_url,is_partner_verified,partner_display_order';

  /// Otras tiendas verificadas (excluye al usuario actual).
  /// Incluye [admin_portal_note] si existe la columna en `profiles`.
  static Future<List<Map<String, dynamic>>> fetchVerifiedPartnerStores() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return [];
    try {
      final rows = await _client
          .from('profiles')
          .select('$_partnerColsBase,admin_portal_note')
          .eq('is_partner_verified', true)
          .neq('id', me)
          .order('partner_display_order', ascending: true)
          .order('shop_name', ascending: true);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('admin_portal_note')) {
        try {
          final rows = await _client
              .from('profiles')
              .select(_partnerColsBase)
              .eq('is_partner_verified', true)
              .neq('id', me)
              .order('partner_display_order', ascending: true)
              .order('shop_name', ascending: true);
          return List<Map<String, dynamic>>.from(rows as List);
        } catch (e2) {
          if (e2.toString().toLowerCase().contains('partner_display_order') ||
              e2.toString().toLowerCase().contains('is_partner_verified')) {
            return [];
          }
          rethrow;
        }
      }
      if (s.contains('partner_display_order') || s.contains('is_partner_verified')) {
        return [];
      }
      rethrow;
    }
  }

  /// Nota interna solo para admins (p. ej. contraseña o pista). Requiere columna `admin_portal_note` en Supabase.
  static Future<void> updateAdminPortalNoteForAdmin({
    required String profileId,
    required String? note,
  }) async {
    if (!await isCurrentUserAdmin()) {
      throw AuthException('Sin permisos de administrador.');
    }
    final trimmed = note?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    try {
      final updated = await _client
          .from('profiles')
          .update({'admin_portal_note': value})
          .eq('id', profileId)
          .select('id');
      if ((updated as List).isEmpty) {
        throw AuthException('No se actualizó la nota (0 filas).');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      if (e.toString().toLowerCase().contains('admin_portal_note')) {
        throw AuthException(
          'Falta la columna admin_portal_note en profiles. Ejecuta scripts/016_profiles_admin_portal_note.sql en Supabase.',
        );
      }
      rethrow;
    }
  }

  /// Tras crear partner: guarda contraseña inicial en nota admin (opcional, si la columna existe).
  static Future<void> trySaveInitialPortalNote({
    required String userId,
    required String email,
    required String password,
  }) async {
    if (!await isCurrentUserAdmin()) return;
    try {
      await _client.from('profiles').update({
        'admin_portal_note':
            'Contraseña definida al crear la cuenta ($email): $password',
      }).eq('id', userId);
    } catch (_) {
      // Columna ausente o política: ignorar.
    }
  }

  static Future<Map<String, dynamic>?> fetchProfileByIdForAdmin(String profileId) async {
    if (!await isCurrentUserAdmin()) return null;
    try {
      final row = await _client
          .from('profiles')
          .select(
            'id, full_name, email, shop_name, shop_description, shop_logo_url, shop_banner_url',
          )
          .eq('id', profileId)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (e) {
      if (e.toString().toLowerCase().contains('shop_banner_url')) {
        final row = await _client
            .from('profiles')
            .select(
              'id, full_name, email, shop_name, shop_description, shop_logo_url, avatar_url',
            )
            .eq('id', profileId)
            .maybeSingle();
        if (row == null) return null;
        final m = Map<String, dynamic>.from(row);
        m['shop_banner_url'] = m['avatar_url'];
        return m;
      }
      rethrow;
    }
  }

  static Future<void> updatePartnerStoreProfileForAdmin({
    required String profileId,
    required String shopName,
    required String shopDescription,
    String? shopLogoUrl,
    String? shopBannerUrl,
  }) async {
    if (!await isCurrentUserAdmin()) {
      throw AuthException('Sin permisos de administrador.');
    }
    final row = {
      'shop_name': shopName.trim(),
      'shop_description': shopDescription.trim(),
      'shop_logo_url': shopLogoUrl,
      'shop_banner_url': shopBannerUrl,
      'is_seller': true,
    };
    try {
      final updated = await _client.from('profiles').update(row).eq('id', profileId).select('id');
      if ((updated as List).isEmpty) {
        throw AuthException(
          'No se actualizó la tienda (0 filas). El admin necesita permiso UPDATE (y SELECT de respuesta) en profiles para ese vendedor.',
        );
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      if (e.toString().toLowerCase().contains('shop_banner_url')) {
        final updated = await _client.from('profiles').update({
          'shop_name': shopName.trim(),
          'shop_description': shopDescription.trim(),
          'shop_logo_url': shopLogoUrl,
          'avatar_url': shopBannerUrl,
          'is_seller': true,
        }).eq('id', profileId).select('id');
        if ((updated as List).isEmpty) {
          throw AuthException(
            'No se actualizó la tienda (0 filas). Revisa políticas RLS en profiles.',
          );
        }
        return;
      }
      rethrow;
    }
  }

  /// Crea usuario vendedor en Auth + perfil. Requiere Edge Function `create-partner-seller` desplegada.
  static Future<({String userId, String email})> createPartnerSellerAccount({
    required String email,
    required String password,
    required String fullName,
    required String shopName,
    String shopDescription = '',
  }) async {
    try {
      // La Edge Function requiere Authorization (JWT) para validar que el que crea es admin.
      var accessToken = _client.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        final refreshed = await _client.auth.refreshSession();
        accessToken = refreshed.session?.accessToken;
      }
      if (accessToken == null || accessToken.isEmpty) {
        throw AuthException('Tu sesión expiró. Vuelve a iniciar sesión e intenta de nuevo.');
      }
      accessToken = accessToken.replaceFirst(
        RegExp(r'^Bearer\s+', caseSensitive: false),
        '',
      );
      final tokenLooksLikeJwt = accessToken.split('.').length == 3;
      if (!tokenLooksLikeJwt) {
        // Evita mandar un token que el gateway va a rechazar con "Invalid JWT".
        throw AuthException(
          'Token de sesión inválido (no parece JWT). len=${accessToken.length}',
        );
      }

      final res = await _client.functions.invoke(
        'create-partner-seller',
        body: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'full_name': fullName.trim(),
          'shop_name': shopName.trim(),
          'shop_description': shopDescription.trim(),
          'access_token': accessToken,
        },
        // Con "Verify JWT with legacy secret" activado en Supabase,
        // el gateway rechaza si el JWT no es el de sesión del admin.
        headers: {
          'Authorization': 'Bearer $accessToken',
          'x-admin-access-token': accessToken,
        },
      );

      final status = res.status;
      final data = res.data;
      if (status != 200) {
        final msg = _extractFunctionError(data);
        throw AuthException(msg ?? 'Error al crear la cuenta (HTTP $status).');
      }
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        if (m['error'] != null) {
          throw AuthException(m['error'].toString());
        }
        final uid = m['user_id']?.toString();
        final em = m['email']?.toString() ?? email.trim().toLowerCase();
        if (uid != null && uid.isNotEmpty) {
          return (userId: uid, email: em);
        }
      }
      throw AuthException('Respuesta inesperada del servidor.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        'No se pudo crear la cuenta. ¿Desplegaste la Edge Function create-partner-seller? $e',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> fetchDeliveryDriversForAdmin() async {
    if (!await isCurrentUserAdmin()) return [];
    final rows = await _client
        .from('profiles_delivery')
        .select('id, auth_user_id, email, full_name, is_active, created_at, updated_at')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Crea usuario Delivery en Auth + profiles_delivery. Requiere Edge Function `create-delivery-driver`.
  static Future<({String userId, String email})> createDeliveryDriverAccount({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      var accessToken = _client.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        final refreshed = await _client.auth.refreshSession();
        accessToken = refreshed.session?.accessToken;
      }
      if (accessToken == null || accessToken.isEmpty) {
        throw AuthException('Tu sesión expiró. Vuelve a iniciar sesión e intenta de nuevo.');
      }
      accessToken = accessToken.replaceFirst(
        RegExp(r'^Bearer\s+', caseSensitive: false),
        '',
      );
      final tokenLooksLikeJwt = accessToken.split('.').length == 3;
      if (!tokenLooksLikeJwt) {
        throw AuthException('Token de sesión inválido (no parece JWT).');
      }

      final res = await _client.functions.invoke(
        'create-delivery-driver',
        body: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'full_name': fullName.trim(),
          'access_token': accessToken,
        },
        headers: {
          'Authorization': 'Bearer $accessToken',
          'x-admin-access-token': accessToken,
        },
      );

      final status = res.status;
      final data = res.data;
      if (status != 200) {
        final msg = _extractFunctionError(data);
        throw AuthException(msg ?? 'Error al crear la cuenta (HTTP $status).');
      }
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        if (m['error'] != null) {
          throw AuthException(m['error'].toString());
        }
        final uid = m['user_id']?.toString();
        final em = m['email']?.toString() ?? email.trim().toLowerCase();
        if (uid != null && uid.isNotEmpty) {
          return (userId: uid, email: em);
        }
      }
      throw AuthException('Respuesta inesperada del servidor.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('No se pudo crear la cuenta. ¿Desplegaste create-delivery-driver? $e');
    }
  }

  static String? _extractFunctionError(dynamic data) {
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    return null;
  }

  /// Quita la tienda del listado de verificadas, borra sus productos y limpia datos de tienda.
  /// No elimina el usuario en Auth (hace falta borrarlo en Supabase Dashboard si lo necesitas).
  static Future<void> deletePartnerStoreForAdmin(String profileId) async {
    if (!await isCurrentUserAdmin()) {
      throw AuthException('Sin permisos de administrador.');
    }
    final me = _client.auth.currentUser?.id;
    if (me != null && me == profileId) {
      throw AuthException('No puedes eliminar tu propia cuenta desde aquí.');
    }
    await _client.from('products').delete().eq('seller_id', profileId);

    Future<void> patchProfile(Map<String, dynamic> row) async {
      final updated = await _client.from('profiles').update(row).eq('id', profileId).select('id');
      if ((updated as List).isEmpty) {
        throw AuthException('No se actualizó el perfil (0 filas). Revisa RLS en profiles.');
      }
    }

    final core = <String, dynamic>{
      'is_partner_verified': false,
      'is_seller': false,
      'shop_name': '',
      'shop_description': '',
      'shop_logo_url': null,
    };

    try {
      await patchProfile({
        ...core,
        'shop_banner_url': null,
        'admin_portal_note': null,
      });
    } catch (e) {
      if (e is AuthException) rethrow;
      final msg = e.toString().toLowerCase();
      if (msg.contains('admin_portal_note')) {
        try {
          await patchProfile({...core, 'shop_banner_url': null});
        } catch (e2) {
          if (e2 is AuthException) rethrow;
          if (e2.toString().toLowerCase().contains('shop_banner_url')) {
            await patchProfile({...core, 'avatar_url': null});
          } else {
            rethrow;
          }
        }
      } else if (msg.contains('shop_banner_url')) {
        await patchProfile({...core, 'avatar_url': null});
      } else {
        rethrow;
      }
    }
  }
}
