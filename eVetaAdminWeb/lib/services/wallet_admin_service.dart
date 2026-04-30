import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';

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
          'profiles:user_id(full_name, username, email), '
          'wallet_topup_qr_sources(provider, raw_qr_text, decoded_ok, decoded_at, created_at, image_url)',
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

  static Future<List<Map<String, dynamic>>> fetchQrgenTokens() async {
    final rows = await _client.rpc('list_wallet_qrgen_tokens');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<List<Map<String, dynamic>>> fetchBankIncomingEvents({
    int limit = 30,
  }) async {
    final rows = await _client
        .from('bank_incoming_events')
        .select(
          'id, source, bank_app, title, body, detected_amount, detected_reference, '
          'detected_sender, detected_at, received_at, match_status, matched_topup_id, raw_payload',
        )
        .order('received_at', ascending: false)
        .limit(limit);
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

  static Future<Map<String, dynamic>> createQrgenToken({String? label}) async {
    final rows = await _client.rpc('create_wallet_qrgen_token', params: {
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

  static Future<void> revokeQrgenToken(String tokenId) async {
    await _client.rpc('revoke_wallet_qrgen_token', params: {
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
