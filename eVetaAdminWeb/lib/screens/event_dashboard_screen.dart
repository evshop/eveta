import 'package:flutter/material.dart';

import '../services/events_service.dart';

class EventDashboardScreen extends StatefulWidget {
  const EventDashboardScreen({super.key});

  @override
  State<EventDashboardScreen> createState() => _EventDashboardScreenState();
}

class _EventDashboardScreenState extends State<EventDashboardScreen> {
  late Future<List<Map<String, dynamic>>> _eventsFuture;
  String? _selectedEventId;

  @override
  void initState() {
    super.initState();
    _eventsFuture = EventsService.fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final events = snapshot.data ?? const [];
        if (events.isEmpty) return const Center(child: Text('No hay eventos para analizar.'));
        _selectedEventId ??= events.first['id'].toString();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedEventId,
              items: events
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e['id'].toString(),
                      child: Text(e['name']?.toString() ?? 'Evento'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedEventId = v),
              decoration: const InputDecoration(labelText: 'Evento'),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: FutureBuilder<Map<String, int>>(
                future: EventsService.fetchEventStats(_selectedEventId!),
                builder: (context, statsSnap) {
                  if (statsSnap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final stats = statsSnap.data ??
                      {
                        'ticketsSold': 0,
                        'peopleEntered': 0,
                        'benefitsRedeemed': 0,
                        'scanLogs': 0,
                      };
                  return GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.7,
                    children: [
                      _StatCard(
                        title: 'Tickets vendidos',
                        value: '${stats['ticketsSold']}',
                        color: scheme.primary,
                      ),
                      _StatCard(
                        title: 'Personas ingresadas',
                        value: '${stats['peopleEntered']}',
                        color: Colors.green,
                      ),
                      _StatCard(
                        title: 'Beneficios canjeados',
                        value: '${stats['benefitsRedeemed']}',
                        color: Colors.orange,
                      ),
                      _StatCard(
                        title: 'Historial de escaneos',
                        value: '${stats['scanLogs']}',
                        color: Colors.purple,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
