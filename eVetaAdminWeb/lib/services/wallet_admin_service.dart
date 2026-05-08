import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'supabase_clients.dart';

class WalletAdminService {
  WalletAdminService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String _requireAdminJwt() {
    final jwt = SupabaseClients.auth.auth.currentSession?.accessToken;
    if (jwt == null || jwt.trim().isEmpty) {
      throw AuthException('No hay sesión activa. Vuelve a iniciar sesión.');
    }
    return jwt.trim();
  }

  static Future<Map<String, dynamic>> _adminWalletInvoke(
    String action, {
    Map<String, dynamic> body = const {},
  }) async {
    final jwt = _requireAdminJwt();
    final res = await _client.functions.invoke(
      'admin-wallet',
      body: {'action': action, ...body},
      headers: {
        'x-admin-access-token': jwt,
        'Authorization': 'Bearer $jwt',
      },
    );
    if (res.status != 200) {
      final data = res.data;
      final msg = data is Map ? data['error']?.toString() : null;
      throw AuthException(msg ?? 'Error del servidor (admin-wallet).');
    }
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return <String, dynamic>{'ok': true, 'data': res.data};
  }

  static Future<List<Map<String, dynamic>>> fetchTopups({
    String status = 'pending_review',
  }) async {
    final rows = await _client
        .from('wallet_topups')
        .select(
          'id, user_id, reference_code, amount, status, proof_url, proof_note, '
          'created_at, updated_at, reject_reason, reconciliation_hint, '
          'profiles:user_id(full_name, username, email), '
          'wallet_topup_qr_sources(provider, raw_qr_text, decoded_ok, decoded_at, created_at, image_url)',
        )
        .eq('status', status)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<List<Map<String, dynamic>>> fetchQrGenerationAudit({
    int limit = 40,
  }) async {
    final rows = await _client
        .from('wallet_topups')
        .select(
          'id, user_id, reference_code, amount, status, created_at, updated_at, '
          'reconciliation_hint, profiles:user_id(full_name, username, email), '
          'wallet_topup_qr_sources(provider, raw_qr_text, decoded_ok, decoded_at, created_at, image_url)',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<void> approveTopup(String topupId, {String? bankEventId}) async {
    await _adminWalletInvoke('approve_topup', body: {
      'topup_id': topupId,
      'event_id': bankEventId,
    });
  }

  static Future<void> rejectTopup(String topupId, {String? reason}) async {
    await _adminWalletInvoke('reject_topup', body: {
      'topup_id': topupId,
      'reason': reason,
    });
  }

  static Future<List<Map<String, dynamic>>> fetchWebhookTokens() async {
    final payload = await _adminWalletInvoke('list_webhook_tokens');
    final data = payload['data'];
    return List<Map<String, dynamic>>.from((data as List?) ?? const []);
  }

  static Future<List<Map<String, dynamic>>> fetchQrgenTokens() async {
    final payload = await _adminWalletInvoke('list_qrgen_tokens');
    final data = payload['data'];
    return List<Map<String, dynamic>>.from((data as List?) ?? const []);
  }

  static Future<List<Map<String, dynamic>>> fetchBankIncomingEvents({
    int limit = 80,
  }) async {
    final payload = await _adminWalletInvoke('list_bank_events', body: {'limit': limit});
    final data = payload['data'];
    return List<Map<String, dynamic>>.from((data as List?) ?? const []);
  }

  /// Peticiones pendientes elegibles para el mismo criterio que 046 (creadas <24h, no vencidas).
  static Future<List<Map<String, dynamic>>> fetchPendingTopupsForMatch({
    int limit = 60,
  }) async {
    final since = DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    // Sin embed a profiles: PostgREST exige FK explícita wallet_topups.user_id → profiles;
    // si no existe en tu DB, `profiles:user_id(...)` falla con PGRST200.
    final rows = await _client
        .from('wallet_topups')
        .select('id, user_id, reference_code, amount, status, created_at, expires_at')
        .inFilter('status', ['pending_review', 'pending_proof'])
        .gte('created_at', since)
        .gt('expires_at', nowIso)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Recargas aprobadas por flujo banco (hint con bank_match_status = confirmed), recientes.
  static Future<List<Map<String, dynamic>>> fetchRecentlyAutoBankApprovedTopups({
    int hours = 72,
    int fetchCap = 80,
    int limit = 25,
  }) async {
    final since = DateTime.now().toUtc().subtract(Duration(hours: hours)).toIso8601String();
    final rows = await _client
        .from('wallet_topups')
        .select(
          'id, user_id, reference_code, amount, requested_amount, verification_delta, '
          'approved_at, reconciliation_hint',
        )
        .eq('status', 'approved')
        .gte('approved_at', since)
        .order('approved_at', ascending: false)
        .limit(fetchCap);
    final list = List<Map<String, dynamic>>.from(rows as List);
    bool bankAuto(Map<String, dynamic> t) {
      final h = t['reconciliation_hint'];
      if (h is! Map) return false;
      return h['bank_match_status']?.toString() == 'confirmed';
    }

    return list.where(bankAuto).take(limit).toList();
  }

  /// Re-ejecuta match_wallet_topups_with_bank_event (046) para un evento; requiere script 047 en Supabase.
  static Future<List<Map<String, dynamic>>> adminRetryMatchBankEvent(String eventId) async {
    final payload = await _adminWalletInvoke('retry_match_bank_event', body: {'event_id': eventId});
    final data = payload['data'];
    return List<Map<String, dynamic>>.from((data as List?) ?? const []);
  }

  /// Código EV de la recarga: relación embebida o columna opcional tras script 039.
  static String? matchedTopupReferenceFromBankEvent(Map<String, dynamic> e) {
    final col = e['matched_reference_code']?.toString().trim();
    if (col != null && col.isNotEmpty) return col;
    final w = e['wallet_topups'];
    if (w is Map) {
      final r = w['reference_code']?.toString().trim();
      if (r != null && r.isNotEmpty) return r;
    }
    if (w is List && w.isNotEmpty) {
      final first = w.first;
      if (first is Map) {
        final r = first['reference_code']?.toString().trim();
        if (r != null && r.isNotEmpty) return r;
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> createWebhookToken({String? label}) async {
    final payload = await _adminWalletInvoke('create_webhook_token', body: {'label': label});
    final data = payload['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    throw AuthException('No se pudo crear el token.');
  }

  static Future<Map<String, dynamic>> createQrgenToken({String? label}) async {
    final payload = await _adminWalletInvoke('create_qrgen_token', body: {'label': label});
    final data = payload['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    throw AuthException('No se pudo crear el token.');
  }

  static Future<void> revokeWebhookToken(String tokenId) async {
    await _adminWalletInvoke('revoke_webhook_token', body: {'token_id': tokenId});
  }

  static Future<void> revokeQrgenToken(String tokenId) async {
    await _adminWalletInvoke('revoke_qrgen_token', body: {'token_id': tokenId});
  }

  static Future<Map<String, dynamic>> decodeAndAttachTopupQr({
    required String topupId,
    required String imageUrl,
    String provider = 'yape',
  }) async {
    final resp = await _client.functions.invoke(
      'decode-wallet-qr',
      body: {
        'topup_id': topupId,
        'image_url': imageUrl,
        'provider': provider,
      },
    );
    if (resp.status != 200) {
      final data = resp.data;
      final msg = data is Map ? data['error']?.toString() : null;
      throw AuthException(msg ?? 'No se pudo procesar QR.');
    }
    return Map<String, dynamic>.from(resp.data as Map);
  }

  static Future<Map<String, dynamic>> uploadAndDecodeTopupQr({
    required String topupId,
    required Uint8List fileBytes,
    required String fileName,
    String mimeType = 'image/png',
    String provider = 'yape',
  }) async {
    final resp = await _client.functions.invoke(
      'decode-wallet-qr-upload',
      body: {
        'topup_id': topupId,
        'provider': provider,
        'file_name': fileName,
        'mime_type': mimeType,
        'file_base64': base64Encode(fileBytes),
      },
    );
    if (resp.status != 200) {
      final data = resp.data;
      final msg = data is Map ? data['error']?.toString() : null;
      throw AuthException(msg ?? 'No se pudo procesar QR por archivo.');
    }
    return Map<String, dynamic>.from(resp.data as Map);
  }
}
