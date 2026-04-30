import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class WalletService {
  WalletService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _proofBucket = 'wallet-topup-proofs';

  static Future<double> getBalance() async {
    final result = await _client.rpc('get_wallet_balance');
    if (result is num) return result.toDouble();
    return double.tryParse(result?.toString() ?? '0') ?? 0;
  }

  static Future<Map<String, dynamic>> createTopupRequest({
    required double amount,
  }) async {
    final result = await _client.rpc(
      'create_wallet_topup_request',
      params: {'p_amount': amount},
    );
    final list = List<Map<String, dynamic>>.from(result as List);
    return list.isEmpty ? <String, dynamic>{} : list.first;
  }

  static Future<List<Map<String, dynamic>>> getMyTopups() async {
    final rows = await _client
        .from('wallet_topups')
        .select(
          'id, reference_code, amount, status, proof_url, proof_note, '
          'created_at, updated_at, approved_at, rejected_at, reject_reason, '
          'wallet_topup_qr_sources(provider, raw_qr_text, decoded_at)',
        )
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Texto del campo “mensaje” en Yape; debe coincidir con lo que usa el worker Termux/adb.
  static String suggestedYapeMessage(String referenceCode) => 'VETA2 $referenceCode';

  /// Texto EMV/plano del QR de pago (Yape, etc.) cuando el worker ya lo subió y decodificó.
  static String? rawQrTextFromTopup(Map<String, dynamic> topup) {
    final nested = topup['wallet_topup_qr_sources'];
    if (nested is List && nested.isNotEmpty) {
      for (final item in nested) {
        if (item is Map) {
          final raw = item['raw_qr_text']?.toString().trim();
          if (raw != null && raw.isNotEmpty) return raw;
        }
      }
    }
    if (nested is Map) {
      final raw = nested['raw_qr_text']?.toString().trim();
      if (raw != null && raw.isNotEmpty) return raw;
    }
    return null;
  }

  static Future<void> submitTopupProof({
    required String topupId,
    required String proofUrl,
    String? note,
    Map<String, dynamic>? hint,
  }) async {
    await _client.rpc(
      'submit_wallet_topup_proof',
      params: {
        'p_topup_id': topupId,
        'p_proof_url': proofUrl,
        'p_proof_note': note,
        'p_reconciliation_hint': hint ?? <String, dynamic>{},
      },
    );
  }

  static Future<String> uploadProofImage({
    required Uint8List bytes,
    required String extension,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw AuthException('Debes iniciar sesión.');
    }
    final safeExt = extension.toLowerCase().replaceAll('.', '');
    final path =
        '$uid/${DateTime.now().millisecondsSinceEpoch}_${_randomKey(6)}.$safeExt';

    await _client.storage.from(_proofBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    return _client.storage.from(_proofBucket).getPublicUrl(path);
  }

  static String _randomKey(int len) {
    final ms = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    if (ms.length >= len) return ms.substring(ms.length - len);
    return ms.padLeft(len, '0');
  }
}
