import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  static bool _isEmail(String value) => value.contains('@');

  static String? get currentUserEmail => _client.auth.currentUser?.email;

  static Future<void> persistSessionUser(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userEmail', value);
  }

  static Future<void> _upsertCurrentProfile({
    String? username,
    String? phone,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final payload = <String, dynamic>{
      'id': user.id,
      'email': user.email,
      if (username != null && username.trim().isNotEmpty) 'username': username.trim(),
      if (username != null && username.trim().isNotEmpty) 'full_name': username.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _client.from('profiles').upsert(payload);
  }

  static Future<Map<String, dynamic>?> findProfileByIdentifier(String identifier) async {
    final normalized = identifier.trim().toLowerCase();
    if (_isEmail(normalized)) {
      return await _client
          .from('profiles')
          .select('id, email, phone, username')
          .ilike('email', normalized)
          .maybeSingle();
    }

    final rawPhone = identifier.trim();
    final normalizedPhone = rawPhone.startsWith('+591') ? rawPhone : '+591$rawPhone';

    final byNormalized = await _client
        .from('profiles')
        .select('id, email, phone, username')
        .eq('phone', normalizedPhone)
        .maybeSingle();
    if (byNormalized != null) return byNormalized;

    final byRaw = await _client
        .from('profiles')
        .select('id, email, phone, username')
        .eq('phone', rawPhone)
        .maybeSingle();
    if (byRaw != null) return byRaw;

    // Cuentas antiguas que guardaron solo los 8 dígitos locales.
    final localEight = RegExp(r'^\+591(\d{8})$').firstMatch(normalizedPhone)?.group(1);
    if (localEight != null) {
      final byLocal = await _client
          .from('profiles')
          .select('id, email, phone, username')
          .eq('phone', localEight)
          .maybeSingle();
      if (byLocal != null) return byLocal;
    }

    return null;
  }

  static Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.user == null) {
      throw AuthException('No se pudo iniciar sesión.');
    }
    await _enforceShopOnlyAccess();
    await _upsertCurrentProfile();
    await persistSessionUser(email.trim());
  }

  static bool _isGoogleSession(User user) {
    final provider = user.appMetadata['provider']?.toString().toLowerCase();
    if (provider == 'google') return true;
    final providers = user.appMetadata['providers'];
    if (providers is List) {
      return providers.map((e) => e.toString().toLowerCase()).contains('google');
    }
    return false;
  }

  static bool _hasEmailProvider(User user) {
    final provider = user.appMetadata['provider']?.toString().toLowerCase();
    if (provider == 'email') return true;
    final providers = user.appMetadata['providers'];
    if (providers is List) {
      return providers.map((e) => e.toString().toLowerCase()).contains('email');
    }
    return false;
  }

  /// Comprueba si el perfil actual necesita completar datos (username, phone).
  static Future<bool> profileNeedsCompletion() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    // Solo forzamos "Completa tu cuenta" para sesiones OAuth de Google.
    if (!_isGoogleSession(user)) return false;
    // Si la cuenta ya tiene proveedor email, asumimos cuenta existente (no forzar completar).
    if (_hasEmailProvider(user)) return false;

    final profile = await _client
        .from('profiles')
        .select('username, phone')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      final email = user.email?.trim().toLowerCase();
      if (email == null || email.isEmpty) return true;
      // Si existe un perfil previo con el mismo correo, reutiliza datos para no bloquear.
      final existing = await _client
          .from('profiles')
          .select('id, username, phone, full_name')
          .ilike('email', email)
          .neq('id', user.id)
          .maybeSingle();
      if (existing != null) {
        final username = existing['username']?.toString().trim();
        final phone = existing['phone']?.toString().trim();
        if (username != null && username.isNotEmpty && phone != null && phone.isNotEmpty) {
          await _client.from('profiles').upsert({
            'id': user.id,
            'email': email,
            'username': username,
            'full_name': existing['full_name']?.toString().trim().isNotEmpty == true
                ? existing['full_name']
                : username,
            'phone': phone,
            'updated_at': DateTime.now().toIso8601String(),
          });
          return false;
        }
      }
      return true;
    }
    final username = profile['username']?.toString().trim();
    final phone = profile['phone']?.toString().trim();
    return username == null ||
        username.isEmpty ||
        phone == null ||
        phone.isEmpty;
  }

  /// Completa el perfil tras Google y establece contraseña para login email/número.
  static Future<void> completeProfileFromGoogle({
    required String username,
    required String phone,
    required String password,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw AuthException('No hay sesión activa.');

    await _upsertCurrentProfile(username: username, phone: phone);
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  static Future<void> registerWithEmail({
    required String email,
    required String password,
    required String username,
    required String phone,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {
        'full_name': username.trim(),
        'phone': phone.trim(),
      },
    );

    if (response.user == null) {
      throw AuthException('No se pudo crear la cuenta.');
    }

    await _upsertCurrentProfile(username: username, phone: phone);
  }

  static Future<void> sendWhatsappOtp({
    required String phone,
  }) async {
    final response = await _client.functions.invoke(
      'send-whatsapp-otp',
      body: {
        'phone': phone.trim(),
      },
    );

    if (response.status != 200) {
      final error = response.data is Map<String, dynamic>
          ? (response.data['error']?.toString() ?? 'No se pudo enviar el código.')
          : 'No se pudo enviar el código.';
      throw AuthException(error);
    }
  }

  static Future<void> verifyWhatsappOtp({
    required String phone,
    required String code,
  }) async {
    final response = await _client.functions.invoke(
      'verify-whatsapp-otp',
      body: {
        'phone': phone.trim(),
        'code': code.trim(),
      },
    );

    if (response.status != 200) {
      final message = response.data is Map<String, dynamic>
          ? (response.data['reason']?.toString() ??
              response.data['error']?.toString() ??
              'Código inválido.')
          : 'Código inválido.';
      throw AuthException(message);
    }
  }

  /// Inicia flujo OAuth de Google en navegador/sistema.
  /// En mobile, la sesión se completa al volver por deep link.
  static Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.eveta.eveta://login-callback/',
      );
    } catch (e) {
      throw AuthException('No se pudo iniciar el flujo de Google: $e');
    }
  }

  /// Evita que cuentas de Portal/Delivery entren a eVetaShop.
  static Future<void> _enforceShopOnlyAccess() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final portal = await _client
          .from('profiles_portal')
          .select('id')
          .eq('auth_user_id', uid)
          .maybeSingle();
      if (portal != null) {
        await _client.auth.signOut();
        throw AuthException('Esta cuenta es de Portal. Usa tu cuenta de eVetaShop.');
      }
    } catch (_) {
      // ignore (tabla puede no existir aún en dev)
    }
    try {
      final delivery = await _client
          .from('profiles_delivery')
          .select('id')
          .eq('auth_user_id', uid)
          .maybeSingle();
      if (delivery != null) {
        await _client.auth.signOut();
        throw AuthException('Esta cuenta es de Delivery. Usa tu cuenta de eVetaShop.');
      }
    } catch (_) {
      // ignore
    }
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('userEmail');
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim().toLowerCase());
  }

  static Future<void> requestPhoneOtp(String phoneE164) async {
    await _client.auth.signInWithOtp(
      phone: phoneE164.trim(),
      shouldCreateUser: true,
    );
  }

  static Future<void> requestPhoneOtpRecovery(String phoneE164) async {
    await _client.auth.signInWithOtp(
      phone: phoneE164.trim(),
      shouldCreateUser: false,
    );
  }

  static Future<AuthResponse> verifyPhoneOtp({
    required String phoneE164,
    required String token,
  }) async {
    return _client.auth.verifyOTP(
      phone: phoneE164.trim(),
      token: token.trim(),
      type: OtpType.sms,
    );
  }

  static Future<void> resendSignupEmailOtp(String email) async {
    await sendEmailOtp(
      email: email,
      purpose: EmailOtpPurpose.signup,
    );
  }

  static Future<Map<String, dynamic>> verifySignupEmailOtp({
    required String email,
    required String token,
  }) async {
    return verifyEmailOtp(
      email: email,
      token: token,
      purpose: EmailOtpPurpose.signup,
    );
  }

  static Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  static Future<void> sendEmailOtp({
    required String email,
    required EmailOtpPurpose purpose,
  }) async {
    final e = email.trim().toLowerCase();
    final response = await _client.functions.invoke(
      'send-email-otp',
      body: {
        'email': e,
        'purpose': purpose.value,
      },
    );
    if (response.status != 200) {
      final msg = response.data is Map<String, dynamic>
          ? (response.data['error']?.toString() ?? 'No se pudo enviar el código por correo.')
          : 'No se pudo enviar el código por correo.';
      throw AuthException(msg);
    }
  }

  static Future<Map<String, dynamic>> verifyEmailOtp({
    required String email,
    required String token,
    required EmailOtpPurpose purpose,
  }) async {
    final e = email.trim().toLowerCase();
    final response = await _client.functions.invoke(
      'verify-email-otp',
      body: {
        'email': e,
        'code': token.trim(),
        'purpose': purpose.value,
      },
    );
    if (response.status != 200) {
      final msg = response.data is Map<String, dynamic>
          ? (response.data['error']?.toString() ??
              response.data['reason']?.toString() ??
              'Código inválido.')
          : 'Código inválido.';
      throw AuthException(msg);
    }
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  static String? _edgeFunctionErrorMessage(Object e) {
    try {
      final dynamic ex = e;
      final details = ex.details;
      if (details is Map && details['error'] != null) {
        return details['error'].toString();
      }
    } catch (_) {}
    return null;
  }

  static Future<void> completeEmailOtpPasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'complete-email-otp-password-reset',
        body: {
          'email': email.trim().toLowerCase(),
          'reset_token': resetToken.trim(),
          'new_password': newPassword,
        },
      );
      if (response.status != 200) {
        final msg = response.data is Map<String, dynamic>
            ? (response.data['error']?.toString() ?? 'No se pudo restablecer la contraseña.')
            : 'No se pudo restablecer la contraseña.';
        throw AuthException(msg);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      final fromBody = _edgeFunctionErrorMessage(e);
      if (fromBody != null && fromBody.isNotEmpty) {
        throw AuthException(fromBody);
      }
      final s = e.toString().toLowerCase();
      if (s.contains('404') || s.contains('functionexception')) {
        throw AuthException(
          'No hay cuenta con ese correo o el servicio no respondió. Verifica el correo e intenta de nuevo.',
        );
      }
      throw AuthException('No se pudo guardar la contraseña. Intenta de nuevo.');
    }
  }

  /// Registro solo con email (username derivado del correo).
  static Future<AuthResponse> registerEmailOnly({
    required String email,
    required String password,
  }) async {
    final e = email.trim().toLowerCase();
    final local = e.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final username = local.length >= 3 ? local : 'user_$local';

    final response = await _client.auth.signUp(
      email: e,
      password: password,
      data: {'full_name': username},
    );

    if (response.session != null && response.user != null) {
      await _upsertCurrentProfile(username: username, phone: null);
    }
    return response;
  }

  /// Tras registro por teléfono + OTP, fija contraseña y teléfono en perfil.
  static Future<void> finalizePhoneSignup({
    required String phoneE164,
    required String password,
  }) async {
    await _client.auth.updateUser(UserAttributes(password: password));
    final username = 'user_${phoneE164.replaceAll(RegExp(r'\D'), '')}';
    await _upsertCurrentProfile(username: username, phone: phoneE164.trim());
  }
}

enum EmailOtpPurpose {
  signup('signup'),
  passwordReset('password_reset');

  const EmailOtpPurpose(this.value);
  final String value;
}