import 'package:flutter/material.dart';

import '../services/events_service.dart';
import '../theme/admin_theme.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = EventsService.fetchEvents();
  }

  Future<void> _reload() async {
    setState(() => _future = EventsService.fetchEvents());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _openEventForm(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo evento'),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No hay eventos creados.'))
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final e = rows[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: scheme.primary.withValues(alpha: 0.12),
                              child: Icon(Icons.event_rounded, color: scheme.primary),
                            ),
                            title: Text(
                              e['name']?.toString() ?? 'Evento',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(e['location']?.toString() ?? 'Ubicación'),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Entradas',
                                  onPressed: () => _openTicketTypes(context, e),
                                  icon: const Icon(Icons.confirmation_number_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Editar',
                                  onPressed: () => _openEventForm(context, existing: e),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  onPressed: () async {
                                    await EventsService.deleteEvent(e['id'].toString());
                                    await _reload();
                                  },
                                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEventForm(BuildContext context, {Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final location = TextEditingController(text: existing?['location']?.toString() ?? '');
    final description = TextEditingController(text: existing?['description']?.toString() ?? '');
    final banner = TextEditingController(text: existing?['banner_url']?.toString() ?? '');
    var active = existing?['is_active'] == true;
    DateTime startsAt = DateTime.tryParse(existing?['starts_at']?.toString() ?? '') ?? DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Nuevo evento' : 'Editar evento'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 8),
                TextField(controller: location, decoration: const InputDecoration(labelText: 'Ubicación')),
                const SizedBox(height: 8),
                TextField(controller: description, decoration: const InputDecoration(labelText: 'Descripción')),
                const SizedBox(height: 8),
                TextField(controller: banner, decoration: const InputDecoration(labelText: 'Banner URL')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('Inicio: ${startsAt.toLocal()}')),
                    OutlinedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                          initialDate: startsAt,
                        );
                        if (date == null) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(startsAt),
                        );
                        if (time == null) return;
                        setLocal(() {
                          startsAt = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                      child: const Text('Elegir'),
                    ),
                  ],
                ),
                if (existing != null)
                  SwitchListTile(
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                    title: const Text('Activo'),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (existing == null) {
                  await EventsService.createEvent(
                    name: name.text,
                    location: location.text,
                    startsAt: startsAt,
                    description: description.text,
                    bannerUrl: banner.text,
                  );
                } else {
                  await EventsService.updateEvent(
                    existing['id'].toString(),
                    name: name.text,
                    location: location.text,
                    startsAt: startsAt,
                    description: description.text,
                    bannerUrl: banner.text,
                    isActive: active,
                  );
                }
                if (!mounted) return;
                Navigator.pop(ctx);
                await _reload();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTicketTypes(BuildContext context, Map<String, dynamic> event) async {
    final eventId = event['id'].toString();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AdminTokens.radiusLg)),
      ),
      builder: (ctx) => _TicketTypesSheet(eventId: eventId, eventName: event['name']?.toString() ?? 'Evento'),
    );
    await _reload();
  }
}

class _TicketTypesSheet extends StatefulWidget {
  const _TicketTypesSheet({required this.eventId, required this.eventName});

  final String eventId;
  final String eventName;

  @override
  State<_TicketTypesSheet> createState() => _TicketTypesSheetState();
}

class _TicketTypesSheetState extends State<_TicketTypesSheet> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = EventsService.fetchTicketTypes(widget.eventId);
  }

  Future<void> _reload() async {
    setState(() => _future = EventsService.fetchTicketTypes(widget.eventId));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            final rows = snapshot.data ?? const [];
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Entradas · ${widget.eventName}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => _openTypeForm(context),
                      child: const Text('Agregar'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: rows.isEmpty
                      ? const Center(child: Text('Sin tipos de entrada.'))
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, i) {
                            final t = rows[i];
                            return Card(
                              child: ListTile(
                                title: Text(t['name']?.toString() ?? 'Entrada'),
                                subtitle: Text(
                                  'Bs ${t['price']} · ${t['people_count']} personas · vendidos ${t['sold_count'] ?? 0}',
                                ),
                                trailing: IconButton(
                                  onPressed: () async {
                                    await EventsService.deleteTicketType(t['id'].toString());
                                    await _reload();
                                  },
                                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                                ),
                                onTap: () => _openTypeForm(context, existing: t),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openTypeForm(BuildContext context, {Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final price = TextEditingController(text: existing?['price']?.toString() ?? '0');
    final people = TextEditingController(text: existing?['people_count']?.toString() ?? '1');
    final stock = TextEditingController(text: existing?['stock']?.toString() ?? '100');
    final benefitsRaw = TextEditingController(
      text: existing?['benefits']?.toString() ?? '[{"type":"bebida","total":1}]',
    );
    var active = existing?['is_active'] != false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Tipo de entrada' : 'Editar entrada'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 8),
                TextField(controller: price, decoration: const InputDecoration(labelText: 'Precio')),
                const SizedBox(height: 8),
                TextField(controller: people, decoration: const InputDecoration(labelText: 'Personas por ticket')),
                const SizedBox(height: 8),
                TextField(controller: stock, decoration: const InputDecoration(labelText: 'Stock')),
                const SizedBox(height: 8),
                TextField(
                  controller: benefitsRaw,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Beneficios JSON'),
                ),
                SwitchListTile(
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                  title: const Text('Activo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                await EventsService.upsertTicketType(
                  id: existing?['id']?.toString(),
                  eventId: widget.eventId,
                  name: name.text,
                  price: double.tryParse(price.text) ?? 0,
                  peopleCount: int.tryParse(people.text) ?? 1,
                  stock: int.tryParse(stock.text) ?? 0,
                  benefits: const [],
                  isActive: active,
                );
                if (!mounted) return;
                Navigator.pop(ctx);
                await _reload();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
