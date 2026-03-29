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

  static Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final profile = await _client
        .from('profiles')
        .select('is_admin')
        .eq('id', user.id)
        .maybeSingle();
    return profile?['is_admin'] == true;
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
      await _client.from('profiles').update(row).eq('id', user.id);
    } catch (e) {
      if (e.toString().toLowerCase().contains('shop_banner_url')) {
        await _client.from('profiles').update({
          'shop_name': shopName.trim(),
          'shop_description': shopDescription.trim(),
          'shop_logo_url': shopLogoUrl,
          // Fallback temporal: avatar_url como banner
          'avatar_url': shopBannerUrl,
          'is_seller': true,
        }).eq('id', user.id);
        return;
      }
      rethrow;
    }
  }

  /// Otras tiendas verificadas (excluye al usuario actual).
  static Future<List<Map<String, dynamic>>> fetchVerifiedPartnerStores() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return [];
    try {
      final rows = await _client
          .from('profiles')
          .select(
            'id,email,full_name,shop_name,shop_description,shop_logo_url,shop_banner_url,is_partner_verified,partner_display_order',
          )
          .eq('is_partner_verified', true)
          .neq('id', me)
          .order('partner_display_order', ascending: true)
          .order('shop_name', ascending: true);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      if (e.toString().toLowerCase().contains('partner_display_order') ||
          e.toString().toLowerCase().contains('is_partner_verified')) {
        // Ejecuta scripts/015_profiles_partner_stores.sql para listar solo partners.
        return [];
      }
      rethrow;
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
      await _client.from('profiles').update(row).eq('id', profileId);
    } catch (e) {
      if (e.toString().toLowerCase().contains('shop_banner_url')) {
        await _client.from('profiles').update({
          'shop_name': shopName.trim(),
          'shop_description': shopDescription.trim(),
          'shop_logo_url': shopLogoUrl,
          'avatar_url': shopBannerUrl,
          'is_seller': true,
        }).eq('id', profileId);
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

  static String? _extractFunctionError(dynamic data) {
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    return null;
  }
}
