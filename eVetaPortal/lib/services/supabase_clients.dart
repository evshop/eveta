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

    await Supabase.initialize(url: coreUrl, anonKey: coreAnon);
    _coreClient = Supabase.instance.client;

    final authUrl = _env('PORTAL_AUTH_SUPABASE_URL').isNotEmpty ? _env('PORTAL_AUTH_SUPABASE_URL') : _env('NEXT_PUBLIC_SUPABASE_URL');
    final authAnon =
        _env('PORTAL_AUTH_SUPABASE_ANON_KEY').isNotEmpty ? _env('PORTAL_AUTH_SUPABASE_ANON_KEY') : _env('NEXT_PUBLIC_SUPABASE_ANON_KEY');
    if (authUrl.isEmpty || authAnon.isEmpty) {
      throw StateError('Missing Portal Auth Supabase config (PORTAL_AUTH_SUPABASE_URL/PORTAL_AUTH_SUPABASE_ANON_KEY).');
    }

    _authClient = SupabaseClient(
      authUrl,
      authAnon,
      authOptions: const AuthClientOptions(
        autoRefreshToken: true,
      ),
    );

    _initialized = true;
  }

  static SupabaseClient get core => _coreClient;
  static SupabaseClient get auth => _authClient;
}

