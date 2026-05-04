import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

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

  static Map<String, dynamic> decoratePortalPartnerRow(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    m['seller_id_for_products'] = sellerProductsIdFromPortal(m);
    return m;
  }

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

  /// Existe cualquier perfil Portal activo (admin o seller) para debugging/mensajes.
  static Future<bool> currentPortalProfileExists() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final portal = await _client
        .from('profiles_portal')
        .select('id')
        .eq('auth_user_id', user.id)
        .eq('is_active', true)
        .maybeSingle();
    return portal != null;
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

    Map<String, dynamic>? shop;
    try {
      final raw = await _client
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
        final raw = await _client
            .from('profiles_portal')
            .select(_portalPartnerColsWithNote)
            .eq('auth_user_id', user.id)
            .eq('is_active', true)
            .maybeSingle();
        if (raw != null) portalRaw = Map<String, dynamic>.from(raw as Map);
      } catch (_) {
        final raw = await _client
            .from('profiles_portal')
            .select(_portalPartnerColsCore)
            .eq('auth_user_id', user.id)
            .eq('is_active', true)
            .maybeSingle();
        if (raw != null) portalRaw = Map<String, dynamic>.from(raw as Map);
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
    final user = _client.auth.currentUser;
    if (user == null) throw AuthException('No hay sesión activa');

    final row = <String, dynamic>{
      'shop_name': shopName.trim(),
      'shop_description': shopDescription.trim(),
      'shop_logo_url': shopLogoUrl,
      'shop_banner_url': shopBannerUrl,
      'is_seller': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    Map<String, dynamic>? updatedPortal;
    try {
      updatedPortal = await _client
          .from('profiles_portal')
          .update(row)
          .eq('auth_user_id', user.id)
          .select('id')
          .maybeSingle();
    } catch (e) {
      if (e.toString().toLowerCase().contains('shop_banner_url')) {
        row.remove('shop_banner_url');
        updatedPortal = await _client
            .from('profiles_portal')
            .update(row)
            .eq('auth_user_id', user.id)
            .select('id')
            .maybeSingle();
      } else {
        rethrow;
      }
    }

    if (updatedPortal == null) {
      throw AuthException(
        'No se encontró profiles_portal para tu usuario (o políticas RLS). Ejecutá scripts/058 y 061 en Supabase.',
      );
    }
  }

  /// Tiendas verificadas para el panel admin.
  /// Vive en `profiles_portal` (la tienda pública viene de ahí para Shop/Delivery).
  static Future<List<Map<String, dynamic>>> fetchVerifiedPartnerStores() async {
    Future<List<Map<String, dynamic>>> load(String cols) async {
      final rows = await _client
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
      final updated = await _client
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
      await _client.from('profiles_portal').update({
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
      final row = await _client
          .from('profiles_portal')
          .select(_portalPartnerColsWithNote)
          .eq('id', partnerPortalProfileId)
          .maybeSingle();
      return row == null ? null : decoratePortalPartnerRow(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      final row = await _client
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
    final row = {
      'shop_name': shopName.trim(),
      'shop_description': shopDescription.trim(),
      'shop_logo_url': shopLogoUrl,
      'shop_banner_url': shopBannerUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'is_seller': true,
    };

    try {
      final updated = await _client
          .from('profiles_portal')
          .update(row)
          .eq('id', profileId)
          .select('id');
      if ((updated as List).isEmpty) {
        throw AuthException(
          'No se actualizó la tienda (0 filas). Revisa RLS/admin policy en profiles_portal (061).',
        );
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      if (e.toString().toLowerCase().contains('shop_banner_url')) {
        row.remove('shop_banner_url');
        final updated = await _client.from('profiles_portal').update({
          ...row,
        }).eq('id', profileId).select('id');
        if ((updated as List).isEmpty) {
          throw AuthException(
            'No se actualizó la tienda (0 filas). Revisa políticas RLS en profiles_portal.',
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
  static Future<void> deletePartnerStoreForAdmin(String partnerPortalProfileId) async {
    if (!await isCurrentUserAdmin()) {
      throw AuthException('Sin permisos de administrador.');
    }

    final portalRow = await _client
        .from('profiles_portal')
        .select(_portalPartnerColsCore)
        .eq('id', partnerPortalProfileId)
        .maybeSingle();
    if (portalRow == null) throw AuthException('No se encontró la tienda (profiles_portal).');

    final m = decoratePortalPartnerRow(Map<String, dynamic>.from(portalRow as Map));
    final sellerId = m['seller_id_for_products']?.toString() ?? '';
    if (sellerId.isEmpty) {
      throw AuthException('No se pudo resolver seller_id para borrar catálogo.');
    }

    final meUid = _client.auth.currentUser?.id;
    if (meUid != null &&
        ((m['auth_user_id']?.toString() == meUid) || (sellerId == meUid))) {
      throw AuthException('No puedes eliminar tu propia cuenta/tienda desde aquí.');
    }

    await _client.from('products').delete().eq('seller_id', sellerId);

    final cleared = await _client
        .from('profiles_portal')
        .update({
          'shop_name': null,
          'shop_description': null,
          'shop_logo_url': null,
          'shop_banner_url': null,
          'shop_border_color': null,
          'shop_address': null,
          'shop_lat': null,
          'shop_lng': null,
          'shop_location_photos': [],
          'is_partner_verified': false,
          'partner_display_order': 0,
          'admin_portal_note': null,
          'is_seller': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', partnerPortalProfileId)
        .select('id');

    if ((cleared as List).isEmpty) {
      throw AuthException('No se pudo actualizar profiles_portal (0 filas). Revisa RLS (061).');
    }
  }
}
