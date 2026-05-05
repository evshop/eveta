import 'package:flutter_dotenv/flutter_dotenv.dart';

String _stripOuterQuotes(String s) {
  var t = s.trim();
  if (t.length >= 2) {
    if ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'"))) {
      t = t.substring(1, t.length - 1).trim();
    }
  }
  return t;
}

/// Quita BOM, espacios y saltos que suelen colarse al copiar `.env` y provocan
/// `Failed host lookup` (el hostname ya no coincide con DNS).
String supabaseUrlFromEnv() {
  var raw = (dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ?? '').trim();
  raw = _stripOuterQuotes(raw);
  raw = raw.replaceAll(RegExp(r'[\uFEFF\u200B-\u200D\u2060]'), '');
  raw = raw.replaceAll(RegExp(r'\s+'), '');
  return raw;
}

/// JWT anon: sin espacios ni saltos de línea.
String supabaseAnonKeyFromEnv() {
  var raw = (dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ?? '').trim();
  raw = _stripOuterQuotes(raw);
  raw = raw.replaceAll(RegExp(r'[\uFEFF\u200B-\u200D\u2060\r\n\t ]'), '');
  return raw;
}
