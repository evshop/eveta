import 'package:supabase_flutter/supabase_flutter.dart';

class EventsService {
  EventsService._();

  static final _client = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getAvailableEvents() async {
    final now = DateTime.now().toIso8601String();
    final rows = await _client
        .from('events')
        .select('id, name, description, banner_url, location, starts_at, ends_at')
        .eq('is_active', true)
        .gte('starts_at', now)
        .order('starts_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<Map<String, dynamic>?> getEventById(String eventId) async {
    final row = await _client
        .from('events')
        .select('id, name, description, banner_url, location, starts_at, ends_at, is_active')
        .eq('id', eventId)
        .eq('is_active', true)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  static Future<List<Map<String, dynamic>>> getTicketTypesByEvent(String eventId) async {
    final rows = await _client
        .from('event_ticket_types')
        .select('id, name, description, price, people_count, benefits, stock, sold_count')
        .eq('event_id', eventId)
        .eq('is_active', true)
        .order('price');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<int> testPurchaseTicketType(String ticketTypeId, {int quantity = 1}) async {
    final result = await _client.rpc('test_purchase_event_ticket', params: {
      'p_ticket_type_id': ticketTypeId,
      'p_quantity': quantity < 1 ? 1 : quantity,
    });
    if (result is int) return result;
    if (result is num) return result.toInt();
    return 0;
  }
}
