import 'package:supabase_flutter/supabase_flutter.dart';

import 'env_config.dart';

class SupabaseClients {
  SupabaseClients._();

  static late final SupabaseClient _authClient;
  static late final SupabaseClient _coreClient;

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    final coreUrl = EnvConfig.required('NEXT_PUBLIC_SUPABASE_URL');
    final coreAnonKey = EnvConfig.required('NEXT_PUBLIC_SUPABASE_ANON_KEY');
    await Supabase.initialize(
      url: coreUrl,
      anonKey: coreAnonKey,
    );

    _coreClient = Supabase.instance.client;

    final portalAuthUrl = EnvConfig.optional(
      'PORTAL_AUTH_SUPABASE_URL',
      fallback: coreUrl,
    );
    final portalAuthAnonKey = EnvConfig.optional(
      'PORTAL_AUTH_SUPABASE_ANON_KEY',
      fallback: coreAnonKey,
    );

    _authClient = SupabaseClient(
      portalAuthUrl,
      portalAuthAnonKey,
      authOptions: const AuthClientOptions(
        autoRefreshToken: true,
      ),
    );

    _initialized = true;
  }

  static SupabaseClient get auth => _authClient;
  static SupabaseClient get core => _coreClient;
}
