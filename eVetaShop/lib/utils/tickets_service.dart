import 'package:supabase_flutter/supabase_flutter.dart';

class TicketsService {
  TicketsService._();

  static final _client = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getMyTickets() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('event_tickets')
        .select('''
          id,
          qr_token,
          people_count,
          used_people,
          status,
          purchased_at,
          events(name, starts_at, location, banner_url),
          ticket_benefits(id, benefit_type, total, used, state)
        ''')
        .eq('user_id', user.id)
        .order('purchased_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }
}
