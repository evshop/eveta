import 'package:supabase_flutter/supabase_flutter.dart';

import 'env_config.dart';

class SupabaseClients {
  SupabaseClients._();

  static late final SupabaseClient _authClient;
  static late final SupabaseClient _coreClient;

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    final coreUrl = EnvConfig.coreUrl;
    final coreAnonKey = EnvConfig.coreAnonKey;
    if (coreUrl.isEmpty || coreAnonKey.isEmpty) {
      throw StateError('Missing Core Supabase config (URL/ANON KEY).');
    }
    await Supabase.initialize(
      url: coreUrl,
      anonKey: coreAnonKey,
    );

    _coreClient = Supabase.instance.client;

    final portalAuthUrl =
        EnvConfig.portalAuthUrl.isNotEmpty ? EnvConfig.portalAuthUrl : coreUrl;
    final portalAuthAnonKey =
        EnvConfig.portalAuthAnonKey.isNotEmpty ? EnvConfig.portalAuthAnonKey : coreAnonKey;

    _authClient = SupabaseClient(
      portalAuthUrl,
      portalAuthAnonKey,
      authOptions: const AuthClientOptions(
        autoRefreshToken: true,
        // Avoid collisions with the Core client's auth storage on web.
        storageKey: 'eveta_admin_portal_auth',
      ),
    );

    _initialized = true;
  }

  static SupabaseClient get auth => _authClient;
  static SupabaseClient get core => _coreClient;
}
