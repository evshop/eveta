import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._();

  // NOTE: `String.fromEnvironment()` requires a *literal* key (const),
  // so we expose explicit getters per variable.

  static String _pick(String defineValue, String envValue, {String fallback = ''}) {
    final d = defineValue.trim();
    if (d.isNotEmpty) return d;
    final e = envValue.trim();
    if (e.isNotEmpty) return e;
    return fallback;
  }

  static String get coreUrl => _pick(
        const String.fromEnvironment('NEXT_PUBLIC_SUPABASE_URL', defaultValue: ''),
        dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ?? '',
      );

  static String get coreAnonKey => _pick(
        const String.fromEnvironment('NEXT_PUBLIC_SUPABASE_ANON_KEY', defaultValue: ''),
        dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ?? '',
      );

  static String get portalAuthUrl => _pick(
        const String.fromEnvironment('PORTAL_AUTH_SUPABASE_URL', defaultValue: ''),
        dotenv.env['PORTAL_AUTH_SUPABASE_URL'] ?? '',
      );

  static String get portalAuthAnonKey => _pick(
        const String.fromEnvironment('PORTAL_AUTH_SUPABASE_ANON_KEY', defaultValue: ''),
        dotenv.env['PORTAL_AUTH_SUPABASE_ANON_KEY'] ?? '',
      );
}

