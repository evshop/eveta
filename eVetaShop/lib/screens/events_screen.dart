import 'package:eveta/screens/event_detail_screen.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/utils/events_service.dart';
import 'package:flutter/material.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Future<List<Map<String, dynamic>>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = EventsService.getAvailableEvents();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      backgroundColor: scheme.surface,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudieron cargar los eventos.'));
          }
          final events = snapshot.data ?? const [];
          if (events.isEmpty) {
            return const Center(child: Text('No hay eventos disponibles por ahora.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(EvetaShopDimens.spaceLg),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final event = events[index];
              final bannerUrl = event['banner_url']?.toString().trim() ?? '';
              return Card(
                child: InkWell(
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => EventDetailScreen(eventId: event['id'].toString()),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (bannerUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(bannerUrl, fit: BoxFit.cover),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          event['name']?.toString() ?? 'Evento',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          event['location']?.toString() ?? 'Ubicación por confirmar',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fmtDate(event['starts_at']?.toString()),
                          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Fecha por confirmar';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Fecha por confirmar';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
