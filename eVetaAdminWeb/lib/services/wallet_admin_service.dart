import 'package:supabase_flutter/supabase_flutter.dart';

class WalletAdminService {
  WalletAdminService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchTopups({
    String status = 'pending_review',
  }) async {
    final rows = await _client
        .from('wallet_topups')
        .select(
          'id, user_id, reference_code, amount, status, proof_url, proof_note, '
          'created_at, updated_at, reject_reason, reconciliation_hint, '
          'profiles:user_id(full_name, username, email)',
        )
        .eq('status', status)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<void> approveTopup(String topupId, {String? bankEventId}) async {
    await _client.rpc('confirm_wallet_topup_match_and_approve', params: {
      'p_topup_id': topupId,
      'p_event_id': bankEventId,
    });
  }

  static Future<void> rejectTopup(String topupId, {String? reason}) async {
    await _client.rpc('reject_wallet_topup', params: {
      'p_topup_id': topupId,
      'p_reason': reason,
    });
  }

  static Future<List<Map<String, dynamic>>> fetchWebhookTokens() async {
    final rows = await _client.rpc('list_wallet_webhook_tokens');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<Map<String, dynamic>> createWebhookToken({String? label}) async {
    final rows = await _client.rpc('create_wallet_webhook_token', params: {
      'p_label': label,
    });
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) {
      throw AuthException('No se pudo crear el token.');
    }
    return list.first;
  }

  static Future<void> revokeWebhookToken(String tokenId) async {
    await _client.rpc('revoke_wallet_webhook_token', params: {
      'p_token_id': tokenId,
    });
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
}
