import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/utils/cart_service.dart';
import 'package:eveta/utils/events_service.dart';
import 'package:eveta/screens/my_tickets_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Future<Map<String, dynamic>?> _eventFuture;
  late Future<List<Map<String, dynamic>>> _typesFuture;

  @override
  void initState() {
    super.initState();
    _eventFuture = EventsService.getEventById(widget.eventId);
    _typesFuture = EventsService.getTicketTypesByEvent(widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del evento')),
      backgroundColor: scheme.surface,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _eventFuture,
        builder: (context, eventSnap) {
          if (eventSnap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (eventSnap.data == null) {
            return const Center(child: Text('Evento no disponible.'));
          }
          final event = eventSnap.data!;
          final bannerUrl = event['banner_url']?.toString().trim() ?? '';
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _typesFuture,
            builder: (context, typesSnap) {
              final types = typesSnap.data ?? const [];
              return ListView(
                padding: const EdgeInsets.all(EvetaShopDimens.spaceLg),
                children: [
                  if (bannerUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(bannerUrl, fit: BoxFit.cover),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    event['name']?.toString() ?? 'Evento',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event['description']?.toString() ?? '',
                    style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${event['location'] ?? 'Ubicación por confirmar'} · ${_fmtDate(event['starts_at']?.toString())}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: scheme.primary),
                  ),
                  const SizedBox(height: 18),
                  const Text('Tipos de entrada', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (typesSnap.connectionState != ConnectionState.done)
                    const Center(child: CircularProgressIndicator())
                  else if (types.isEmpty)
                    const Text('No hay entradas habilitadas por ahora.')
                  else
                    ...types.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            title: Text(t['name']?.toString() ?? 'Entrada'),
                            subtitle: Text(
                              '${t['people_count'] ?? 1} persona(s) por ticket',
                            ),
                            trailing: Text(
                              'Bs ${t['price']}',
                              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
                            ),
                            onTap: () => _openPurchaseOptions(context, event, t),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addTicketTypeToCart(
    BuildContext context,
    Map<String, dynamic> event,
    Map<String, dynamic> ticketType,
  ) async {
    final client = Supabase.instance.client;
    final product = await client
        .from('products')
        .select('id, name, price, images, stock')
        .eq('event_ticket_type_id', ticketType['id'])
        .maybeSingle();
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrada no disponible para compra aún.')),
      );
      return;
    }

    await CartService.addToCart(
      CartItem(
        productId: product['id'].toString(),
        name: product['name']?.toString() ?? 'Entrada ${event['name']}',
        price: product['price']?.toString() ?? ticketType['price']?.toString() ?? '0',
        imageUrl: '',
        quantity: 1,
        stock: (product['stock'] as num?)?.toInt() ?? 999,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrada agregada al carrito')),
    );
  }

  Future<void> _openPurchaseOptions(
    BuildContext context,
    Map<String, dynamic> event,
    Map<String, dynamic> ticketType,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Comprar ${ticketType['name']}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('Elige cómo quieres continuar con esta entrada.'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, 'test'),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Confirmar compra (modo prueba sin pagar)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, 'cart'),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Enviar al carrito normal'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == 'cart') {
      await _addTicketTypeToCart(context, event, ticketType);
      return;
    }
    await _confirmTestPurchase(context, ticketType);
  }

  Future<void> _confirmTestPurchase(
    BuildContext context,
    Map<String, dynamic> ticketType,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar compra de prueba'),
        content: const Text(
          'Esta acción genera tu entrada al instante sin pasar por pago. Solo para pruebas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await EventsService.testPurchaseTicketType(ticketType['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrada creada con éxito (modo prueba).')),
      );
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const MyTicketsScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo confirmar la compra: $e')),
      );
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Fecha por confirmar';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Fecha por confirmar';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
