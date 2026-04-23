import 'package:supabase_flutter/supabase_flutter.dart';

class EventsService {
  EventsService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchEvents() async {
    final rows = await _client
        .from('events')
        .select('id, name, location, starts_at, is_active')
        .order('starts_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<void> createEvent({
    required String name,
    required String location,
    required DateTime startsAt,
    String? description,
    String? bannerUrl,
  }) async {
    await _client.from('events').insert({
      'name': name.trim(),
      'location': location.trim(),
      'starts_at': startsAt.toIso8601String(),
      'description': description?.trim(),
      'banner_url': bannerUrl?.trim(),
    });
  }

  static Future<void> updateEvent(
    String id, {
    required String name,
    required String location,
    required DateTime startsAt,
    required bool isActive,
    String? description,
    String? bannerUrl,
  }) async {
    await _client.from('events').update({
      'name': name.trim(),
      'location': location.trim(),
      'starts_at': startsAt.toIso8601String(),
      'is_active': isActive,
      'description': description?.trim(),
      'banner_url': bannerUrl?.trim(),
    }).eq('id', id);
  }

  static Future<void> deleteEvent(String id) async {
    await _client.from('events').delete().eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> fetchTicketTypes(String eventId) async {
    final rows = await _client
        .from('event_ticket_types')
        .select('id, name, price, people_count, stock, sold_count, benefits, is_active')
        .eq('event_id', eventId)
        .order('price');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<void> upsertTicketType({
    String? id,
    required String eventId,
    required String name,
    required double price,
    required int peopleCount,
    required int stock,
    required List<Map<String, dynamic>> benefits,
    required bool isActive,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw AuthException('Debes iniciar sesión para gestionar entradas.');
    }

    final payload = {
      'event_id': eventId,
      'name': name.trim(),
      'price': price,
      'people_count': peopleCount,
      'stock': stock,
      'benefits': benefits,
      'is_active': isActive,
    };
    String ticketTypeId;
    if (id == null) {
      final inserted = await _client.from('event_ticket_types').insert(payload).select('id').single();
      ticketTypeId = inserted['id'].toString();
    } else {
      await _client.from('event_ticket_types').update(payload).eq('id', id);
      ticketTypeId = id;
    }

    await _syncTicketTypeProduct(
      sellerId: user.id,
      eventId: eventId,
      ticketTypeId: ticketTypeId,
      name: name,
      price: price,
      stock: stock,
      isActive: isActive,
    );
  }

  static Future<void> deleteTicketType(String id) async {
    await _client.from('products').delete().eq('event_ticket_type_id', id);
    await _client.from('event_ticket_types').delete().eq('id', id);
  }

  static Future<Map<String, int>> fetchEventStats(String eventId) async {
    final tickets = await _client.from('event_tickets').select('id, used_people').eq('event_id', eventId);
    final benefits = await _client
        .from('ticket_benefits')
        .select('id, used, event_tickets!inner(event_id)')
        .eq('event_tickets.event_id', eventId);
    final logs = await _client
        .from('ticket_action_logs')
        .select('id, action_type, event_tickets!inner(event_id)')
        .eq('event_tickets.event_id', eventId);

    final ticketRows = List<Map<String, dynamic>>.from(tickets as List);
    final benefitRows = List<Map<String, dynamic>>.from(benefits as List);
    final logRows = List<Map<String, dynamic>>.from(logs as List);
    final entered = ticketRows.fold<int>(0, (sum, row) => sum + ((row['used_people'] as num?)?.toInt() ?? 0));
    final redeemed = benefitRows.fold<int>(0, (sum, row) => sum + ((row['used'] as num?)?.toInt() ?? 0));
    return {
      'ticketsSold': ticketRows.length,
      'peopleEntered': entered,
      'benefitsRedeemed': redeemed,
      'scanLogs': logRows.length,
    };
  }

  static Future<void> _syncTicketTypeProduct({
    required String sellerId,
    required String eventId,
    required String ticketTypeId,
    required String name,
    required double price,
    required int stock,
    required bool isActive,
  }) async {
    final event = await _client.from('events').select('name').eq('id', eventId).maybeSingle();
    final eventName = event?['name']?.toString() ?? 'Evento';
    final categories = await _client.from('categories').select('id').limit(1);
    final fallbackCategoryId = (categories as List).isNotEmpty ? categories.first['id']?.toString() : null;

    final productName = 'Entrada $eventName · ${name.trim()}';
    final existing = await _client
        .from('products')
        .select('id')
        .eq('event_ticket_type_id', ticketTypeId)
        .maybeSingle();

    final row = {
      'seller_id': sellerId,
      'category_id': fallbackCategoryId,
      'name': productName,
      'description': 'Entrada digital para $eventName',
      'price': price,
      'stock': stock < 0 ? 0 : stock,
      'unit': 'entrada',
      'is_active': isActive,
      'is_featured': false,
      'images': <String>[],
      'tags': <String>['evento', 'entrada'],
      'event_ticket_type_id': ticketTypeId,
    };

    if (existing == null) {
      await _client.from('products').insert(row);
    } else {
      await _client.from('products').update(row).eq('id', existing['id']);
    }
  }
}
