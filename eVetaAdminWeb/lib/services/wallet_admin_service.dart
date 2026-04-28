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
}
