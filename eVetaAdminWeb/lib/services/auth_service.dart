import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_clients.dart';

class AuthService {
  static SupabaseClient get _authClient => SupabaseClients.auth;
  static SupabaseClient get _coreClient => SupabaseClients.core;

  /// Columnas de tienda/partner viven en `profiles_portal`, no en `profiles`.
  /// Tras 064, `products.seller_id` referencia `profiles_portal.id`, así que
  /// `seller_id_for_products` es directamente el `id` del row Portal.
  /// Columnas base (sin `admin_portal_note`: falla si no corriste scripts/062).
  static const _portalPartnerColsCore =
      'id, auth_user_id, email, full_name, '
      'shop_name, shop_description, shop_logo_url, shop_banner_url, '
      'is_partner_verified, partner_display_order, is_seller, is_active';

  static const _portalPartnerColsWithNote = '$_portalPartnerColsCore, admin_portal_note';

  static String sellerProductsIdFromPortal(Map<String, dynamic> portalRow) {
    final id = portalRow['id']?.toString().trim();
    return id ?? '';
  }

  static String? get currentAuthUserId => _authClient.auth.currentUser?.id;
  static String? get currentAuthEmail => _authClient.auth.currentUser?.email;

  static Map<String, dynamic> decoratePortalPartnerRow(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    m['seller_id_for_products'] = sellerProductsIdFromPortal(m);
    return m;
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _authClient.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    if (response.user == null) {
      throw AuthException('No se pudo iniciar sesión.');
    }
  }

  static Future<void> signOut() async {
    await _authClient.auth.signOut();
  }

  /// Envía el correo de recuperación de contraseña de Supabase Auth (no revela la contraseña actual).
  static Future<void> sendPasswordResetEmail(String email) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) throw AuthException('Correo vacío.');
    await _authClient.auth.resetPasswordForEmail(e);
  }

  static Future<bool> isCurrentUserAdmin() async {
    final user = _authClient.auth.currentUser;
    if (user == null) return false;
    final userEmail = user.email?.trim().toLowerCase();
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final rpcResult = await _coreClient.rpc('profile_is_admin');
        if (rpcResult is bool) return rpcResult;
      } catch (_) {
        // Fallback below.
      }
      try {
        Map<String, dynamic>? portal;
        portal = await _coreClient
            .from('profiles_portal')
            .select('is_admin')
            .eq('auth_user_id', user.id)
            .eq('is_active', true)
            .maybeSingle();
        if (portal == null && userEmail != null && userEmail.isNotEmpty) {
          portal = await _coreClient
              .from('profiles_portal')
              .select('is_admin')
              .ilike('email', userEmail)
              .eq('is_active', true)
              .maybeSingle();
        }
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

  /// Existe cualquier perfil Portal activo (admin o seller) para debugging/mensajes.
  static Future<bool> currentPortalProfileExists() async {
    final user = _authClient.auth.currentUser;
    if (user == null) return false;
    final userEmail = user.email?.trim().toLowerCase();
    dynamic portal = await _coreClient
        .from('profiles_portal')
        .select('id')
        .eq('auth_user_id', user.id)
        .eq('is_active', true)
        .maybeSingle();
    if (portal == null && userEmail != null && userEmail.isNotEmpty) {
      portal = await _coreClient
          .from('profiles_portal')
          .select('id')
          .ilike('email', userEmail)
          .eq('is_active', true)
          .maybeSingle();
    }
    return portal != null;
  }

  static Future<bool> currentUserProfileExists() async {
    final user = _authClient.auth.currentUser;
    if (user == null) return false;
    final profile = await _coreClient.from('profiles').select('id').eq('id', user.id).maybeSingle();
    return profile != null;
  }

  static Future<Map<String, dynamic>?> fetchMyProfile() async {
    final user = _authClient.auth.currentUser;
    if (user == null) return null;
    final userEmail = user.email?.trim().toLowerCase();

    Map<String, dynamic>? shop;
    try {
      final raw = await _coreClient
          .from('profiles')
          .select('id, full_name, email')
          .eq('id', user.id)
          .maybeSingle();
      if (raw != null) shop = Map<String, dynamic>.from(raw as Map);
    } catch (_) {}

    Map<String, dynamic>? portal;
    try {
      Map<String, dynamic>? portalRaw;
      try {
        final raw = await _coreClient
            .from('profiles_portal')
            .select(_portalPartnerColsWithNote)
            .eq('auth_user_id', user.id)
            .eq('is_active', true)
            .maybeSingle();
        if (raw != null) portalRaw = Map<String, dynamic>.from(raw as Map);
      } catch (_) {
        final raw = await _coreClient
            .from('profiles_portal')
            .select(_portalPartnerColsCore)
            .eq('auth_user_id', user.id)
            .eq('is_active', true)
            .maybeSingle();
        if (raw != null) portalRaw = Map<String, dynamic>.from(raw as Map);
      }
      if (portalRaw == null && userEmail != null && userEmail.isNotEmpty) {
        try {
          final raw = await _coreClient
              .from('profiles_portal')
              .select(_portalPartnerColsWithNote)
              .ilike('email', userEmail)
              .eq('is_active', true)
              .maybeSingle();
          if (raw != null) portalRaw = Map<String, dynamic>.from(raw as Map);
        } catch (_) {
          final raw = await _coreClient
              .from('profiles_portal')
              .select(_portalPartnerColsCore)
              .ilike('email', userEmail)
              .eq('is_active', true)
              .maybeSingle();
          if (raw != null) portalRaw = Map<String, dynamic>.from(raw as Map);
        }
      }
      portal = portalRaw;
    } catch (_) {}

    if (portal == null) return shop;

    final merged = decoratePortalPartnerRow(portal);

    final fnShop = shop?['full_name']?.toString().trim();
    if (fnShop != null && fnShop.isNotEmpty) {
      merged.putIfAbsent('full_name', () => fnShop);
    }
    merged.putIfAbsent('email', () => merged['email'] ?? user.email);
    // `merged['id']` ya es `profiles_portal.id` (lo que `products.seller_id` espera).
    return merged;
  }

  static Future<void> updateMyStoreProfile({
    required String shopName,
    required String shopDescription,
    String? shopLogoUrl,
    String? shopBannerUrl,
  }) async {
    final user = _authClient.auth.currentUser;
    if (user == null) throw AuthException('No hay sesión activa');
    final me = await fetchMyProfile();
    final profileId = me?['id']?.toString().trim() ?? '';
    if (profileId.isEmpty) {
      throw AuthException('Tu cuenta no está vinculada a Portal (profiles_portal).');
    }

    var accessToken = _authClient.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      final refreshed = await _authClient.auth.refreshSession();
      accessToken = refreshed.session?.accessToken;
    }
    if (accessToken == null || accessToken.isEmpty) {
      throw AuthException('Tu sesión expiró. Vuelve a iniciar sesión e intenta de nuevo.');
    }
    accessToken = accessToken.replaceFirst(RegExp(r'^Bearer\\s+', caseSensitive: false), '');

    final res = await _coreClient.functions.invoke(
      'admin-upsert-store-profile',
      body: {
        'profile_id': profileId,
        'shop_name': shopName.trim(),
        'shop_description': shopDescription.trim(),
        'shop_logo_url': shopLogoUrl,
        'shop_banner_url': shopBannerUrl,
      },
      headers: {
        'Authorization': 'Bearer $accessToken',
        'x-admin-access-token': accessToken,
      },
    );
    if (res.status != 200) {
      final msg = _extractFunctionError(res.data) ?? 'No se pudo actualizar la tienda.';
      throw AuthException(msg);
    }
  }

  /// Tiendas verificadas para el panel admin.
  /// Vive en `profiles_portal` (la tienda pública viene de ahí para Shop/Delivery).
  static Future<List<Map<String, dynamic>>> fetchVerifiedPartnerStores() async {
    Future<List<Map<String, dynamic>>> load(String cols) async {
      final rows = await _coreClient
          .from('profiles_portal')
          .select(cols)
          .eq('is_active', true)
          .or('is_seller.eq.true,is_partner_verified.eq.true')
          .order('partner_display_order', ascending: true)
          .order('shop_name', ascending: true);
      return List<Map<String, dynamic>>.from(rows as List);
    }

    try {
      try {
        final list = await load(_portalPartnerColsWithNote);
        return list.map(decoratePortalPartnerRow).toList();
      } catch (e1) {
        debugPrint('fetchVerifiedPartnerStores (con admin_portal_note): $e1');
        final list = await load(_portalPartnerColsCore);
        return list.map(decoratePortalPartnerRow).toList();
      }
    } catch (e2, st) {
      debugPrint('fetchVerifiedPartnerStores: $e2\n$st');
      return [];
    }
  }

  /// Nota interna solo para admins (p. ej. contraseña o pista).
  /// Vive en `profiles_portal.admin_portal_note` (script 062).
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
      final updated = await _coreClient
          .from('profiles_portal')
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
          'Falta la columna admin_portal_note en profiles_portal. Ejecuta scripts/062_admin_portal_note_on_profiles_portal.sql en Supabase.',
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
      await _coreClient.from('profiles_portal').update({
        'admin_portal_note':
            'Contraseña definida al crear la cuenta ($email): $password',
      }).eq('auth_user_id', userId);
    } catch (_) {
      // Columna ausente o política: ignorar.
    }
  }

  /// [partnerPortalProfileId] es profiles_portal.id (no auth.users.id).
  static Future<Map<String, dynamic>?> fetchProfileByIdForAdmin(String partnerPortalProfileId) async {
    if (!await isCurrentUserAdmin()) return null;
    try {
      final row = await _coreClient
          .from('profiles_portal')
          .select(_portalPartnerColsWithNote)
          .eq('id', partnerPortalProfileId)
          .maybeSingle();
      return row == null ? null : decoratePortalPartnerRow(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      final row = await _coreClient
          .from('profiles_portal')
          .select(_portalPartnerColsCore)
          .eq('id', partnerPortalProfileId)
          .maybeSingle();
      return row == null ? null : decoratePortalPartnerRow(Map<String, dynamic>.from(row as Map));
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
    var accessToken = _authClient.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      final refreshed = await _authClient.auth.refreshSession();
      accessToken = refreshed.session?.accessToken;
    }
    if (accessToken == null || accessToken.isEmpty) {
      throw AuthException('Tu sesión expiró. Vuelve a iniciar sesión e intenta de nuevo.');
    }
    accessToken = accessToken.replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '');

    final res = await _coreClient.functions.invoke(
      'admin-upsert-store-profile',
      body: {
        'profile_id': profileId,
        'shop_name': shopName.trim(),
        'shop_description': shopDescription.trim(),
        'shop_logo_url': shopLogoUrl,
        'shop_banner_url': shopBannerUrl,
      },
      headers: {
        'Authorization': 'Bearer $accessToken',
        'x-admin-access-token': accessToken,
      },
    );
    if (res.status != 200) {
      final msg = _extractFunctionError(res.data) ?? 'No se pudo actualizar la tienda.';
      throw AuthException(msg);
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
      var accessToken = _authClient.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        final refreshed = await _authClient.auth.refreshSession();
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

      final res = await _coreClient.functions.invoke(
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
    } on FunctionException catch (e) {
      throw AuthException(_messageFromFunctionException(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('No se pudo crear la cuenta de vendedor: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchDeliveryDriversForAdmin() async {
    if (!await isCurrentUserAdmin()) return [];
    final rows = await _coreClient
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
      var accessToken = _authClient.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        final refreshed = await _authClient.auth.refreshSession();
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

      final res = await _coreClient.functions.invoke(
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
    } on FunctionException catch (e) {
      throw AuthException(_messageFromFunctionException(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('No se pudo crear la cuenta de delivery: $e');
    }
  }

  static String? _extractFunctionError(dynamic data) {
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    return null;
  }

  /// Cuerpo JSON de una Edge Function cuando `invoke` lanza [FunctionException] (HTTP ≠ 2xx).
  static String _messageFromFunctionException(FunctionException e) {
    final fromPayload = _extractFunctionError(e.details);
    if (fromPayload != null && fromPayload.trim().isNotEmpty) {
      return _humanizeEdgeFunctionError(fromPayload);
    }
    if (e.details is String && (e.details as String).trim().isNotEmpty) {
      return _humanizeEdgeFunctionError((e.details as String).trim());
    }
    return 'Error del servidor (HTTP ${e.status}).';
  }

  static String _humanizeEdgeFunctionError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('already been registered') ||
        lower.contains('already registered') ||
        lower.contains('user already registered')) {
      return 'Ese correo ya tiene una cuenta en Supabase Auth. '
          'Usa otro email o elimina ese usuario en Dashboard → Authentication → Users '
          '(si era una prueba). Luego vuelve a crear el repartidor.';
    }
    return raw;
  }

  /// Quita la tienda del listado de verificadas, borra sus productos y limpia datos de tienda.
  /// No elimina el usuario en Auth (hace falta borrarlo en Supabase Dashboard si lo necesitas).
  static Future<void> deletePartnerStoreForAdmin(String partnerPortalProfileId) async {
    if (!await isCurrentUserAdmin()) {
      throw AuthException('Sin permisos de administrador.');
    }
    var accessToken = _authClient.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      final refreshed = await _authClient.auth.refreshSession();
      accessToken = refreshed.session?.accessToken;
    }
    if (accessToken == null || accessToken.isEmpty) {
      throw AuthException('Tu sesión expiró. Vuelve a iniciar sesión e intenta de nuevo.');
    }
    accessToken = accessToken.replaceFirst(RegExp(r'^Bearer\\s+', caseSensitive: false), '');

    final res = await _coreClient.functions.invoke(
      'admin-delete-store',
      body: {'profile_id': partnerPortalProfileId},
      headers: {
        'Authorization': 'Bearer $accessToken',
        'x-admin-access-token': accessToken,
      },
    );
    if (res.status != 200) {
      final msg = _extractFunctionError(res.data) ?? 'No se pudo eliminar la tienda.';
      throw AuthException(msg);
    }
  }
}
