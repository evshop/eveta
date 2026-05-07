import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClients {
  SupabaseClients._();

  static late final SupabaseClient _authClient;
  static late final SupabaseClient _coreClient;

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    final coreUrl = dotenv.env['NEXT_PUBLIC_SUPABASE_URL']!;
    final coreAnonKey = dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY']!;
    await Supabase.initialize(
      url: coreUrl,
      anonKey: coreAnonKey,
    );

    _coreClient = Supabase.instance.client;

    final portalAuthUrl =
        dotenv.env['PORTAL_AUTH_SUPABASE_URL'] ?? coreUrl;
    final portalAuthAnonKey =
        dotenv.env['PORTAL_AUTH_SUPABASE_ANON_KEY'] ?? coreAnonKey;

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
