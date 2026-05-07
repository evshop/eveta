import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClients {
  SupabaseClients._();

  static late final SupabaseClient _authClient;
  static late final SupabaseClient _coreClient;

  static bool _initialized = false;

  static String _env(String key) => (dotenv.env[key] ?? '').trim();

  static Future<void> initialize() async {
    if (_initialized) return;

    final coreUrl = _env('CORE_SUPABASE_URL');
    final coreAnon = _env('CORE_SUPABASE_ANON_KEY');
    if (coreUrl.isEmpty || coreAnon.isEmpty) {
      throw StateError('Missing Core Supabase config (CORE_SUPABASE_URL/CORE_SUPABASE_ANON_KEY).');
    }

    final authUrl = _env('PORTAL_AUTH_SUPABASE_URL').isNotEmpty ? _env('PORTAL_AUTH_SUPABASE_URL') : _env('NEXT_PUBLIC_SUPABASE_URL');
    final authAnon =
        _env('PORTAL_AUTH_SUPABASE_ANON_KEY').isNotEmpty ? _env('PORTAL_AUTH_SUPABASE_ANON_KEY') : _env('NEXT_PUBLIC_SUPABASE_ANON_KEY');
    if (authUrl.isEmpty || authAnon.isEmpty) {
      throw StateError('Missing Portal Auth Supabase config (PORTAL_AUTH_SUPABASE_URL/PORTAL_AUTH_SUPABASE_ANON_KEY).');
    }

    /// Portal Auth debe ser el cliente principal: `Supabase.initialize` aplica
    /// almacenamiento Flutter (SharedPreferences / web) y restaura la sesión al arrancar.
    await Supabase.initialize(
      url: authUrl,
      anonKey: authAnon,
      authOptions: const FlutterAuthClientOptions(),
    );
    _authClient = Supabase.instance.client;

    /// Core solo se usa con anon + invocaciones a Edge Functions (JWT de Portal en header).
    _coreClient = SupabaseClient(
      coreUrl,
      coreAnon,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
      ),
    );

    _initialized = true;
  }

  static SupabaseClient get core => _coreClient;
  static SupabaseClient get auth => _authClient;

  /// JWT de Portal para funciones del Core. Refresca si está a punto de expirar.
  static Future<String?> getPortalAccessToken() async {
    var session = _authClient.auth.currentSession;
    if (session == null) return null;

    final exp = session.expiresAt;
    if (exp != null) {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (exp <= nowSec + 120) {
        final res = await _authClient.auth.refreshSession();
        session = res.session;
      }
    }
    return session?.accessToken;
  }
}

