import 'package:flutter/material.dart';

import '../services/portal_orders_service.dart';
import '../services/supabase_clients.dart';
import '../widgets/portal/portal_empty_state.dart';
import '../widgets/portal/portal_haptics.dart';
import '../widgets/portal/portal_ios_segmented_control.dart';
import '../widgets/portal/portal_soft_card.dart';
import '../widgets/portal/portal_tokens.dart';
import '../widgets/portal_cached_image.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  String _segment = 'todos';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final jwt = await SupabaseClients.getPortalAccessToken();
      if (jwt == null || jwt.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final res = await SupabaseClients.core.functions.invoke(
        'portal-seller',
        body: {'action': 'list_orders'},
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (res.status != 200) {
        throw Exception((res.data is Map && res.data['error'] != null) ? res.data['error'].toString() : 'No se pudo cargar pedidos.');
      }
      final response = (res.data is Map && res.data['data'] is List) ? (res.data['data'] as List) : const [];

      final list = List<Map<String, dynamic>>.from(response);
      if (!mounted) return;
      setState(() {
        _allOrders = list;
        _applyFilter(_segment);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String seg) {
    setState(() {
      _segment = seg;
      if (seg == 'todos') {
        _filteredOrders = List<Map<String, dynamic>>.from(_allOrders);
      } else if (seg == 'pendientes') {
        _filteredOrders = _allOrders
            .where((o) => o['status'] != 'delivered' && o['status'] != 'cancelled')
            .toList();
      } else {
        _filteredOrders = _allOrders.where((o) => o['status'] == 'delivered').toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Pedidos', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              portalHapticLight();
              setState(() => _isLoading = true);
              _fetchOrders();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PortalTokens.space2,
                PortalTokens.space1,
                PortalTokens.space2,
                PortalTokens.space2,
              ),
              child: PortalIosSegmentedControl<String>(
                segments: const [
                  PortalSegment(value: 'todos', label: 'Todos'),
                  PortalSegment(value: 'pendientes', label: 'Pend.'),
                  PortalSegment(value: 'completados', label: 'Listos'),
                ],
                selected: _segment,
                onChanged: (v) {
                  portalHapticSelect();
                  _applyFilter(v);
                },
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: PortalTokens.motionNormal,
                child: _isLoading
                    ? Center(key: const ValueKey('l'), child: CircularProgressIndicator(color: scheme.primary))
                    : _filteredOrders.isEmpty
                        ? PortalEmptyState(
                            key: ValueKey('empty_$_segment'),
                            icon: Icons.receipt_long_outlined,
                            title: _emptyTitle(_segment),
                            subtitle: _emptySubtitle(_segment),
                          )
                        : ListView.builder(
                            key: ValueKey('list_$_segment'),
                            padding: const EdgeInsets.fromLTRB(
                              PortalTokens.space2,
                              0,
                              PortalTokens.space2,
                              PortalTokens.space4,
                            ),
                            itemCount: _filteredOrders.length,
                            itemBuilder: (context, index) {
                              final order = _filteredOrders[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: PortalTokens.space2),
                                child: _OrderCard(
                                  order: order,
                                  onChanged: () {
                                    setState(() => _isLoading = true);
                                    _fetchOrders();
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emptyTitle(String seg) {
    return switch (seg) {
      'pendientes' => 'Nada pendiente',
      'completados' => 'Sin pedidos completados',
      _ => 'Sin pedidos todavía',
    };
  }

  String _emptySubtitle(String seg) {
    return switch (seg) {
      'pendientes' => 'Cuando tengas pedidos activos, aparecerán aquí.',
      'completados' => 'Los pedidos entregados se listan en esta pestaña.',
      _ => 'Cuando recibas tu primera venta, la verás en esta lista.',
    };
  }
}

class _OrderCard extends StatefulWidget {
  const _OrderCard({
    required this.order,
    required this.onChanged,
  });

  final Map<String, dynamic> order;
  final VoidCallback onChanged;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PortalOrdersService.humanizeError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final o = widget.order;
    final status = o['status']?.toString() ?? 'pending';
    final deliveryStatus = o['delivery_status']?.toString() ?? '';
    final orderId = o['id']?.toString() ?? '';
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8) : orderId;
    final items = (o['order_items'] as List?) ?? const [];
    final buyer = (o['buyer_display_name']?.toString().trim().isNotEmpty == true)
        ? o['buyer_display_name'].toString().trim()
        : 'Cliente';
    final addr = o['dropoff_address']?.toString().trim() ?? '';
    final total = o['total'];
    final totalNum = total is num ? total.toDouble() : double.tryParse(total?.toString() ?? '0') ?? 0;

    String? firstImage;
    final names = <String>[];
    for (final it in items) {
      if (it is! Map) continue;
      final im = it['image_url']?.toString().trim();
      if (firstImage == null && im != null && im.isNotEmpty) firstImage = im;
      final n = it['name_snapshot']?.toString().trim();
      final q = it['quantity'];
      if (n != null && n.isNotEmpty) {
        names.add(q != null ? '$n ×$q' : n);
      }
    }
    final lines = names.isEmpty ? 'Productos' : names.take(3).join(' · ');

    final meta = _statusPresentation(status, deliveryStatus);

    final canReject = (status == 'pending' || status == 'confirmed') &&
        deliveryStatus != 'driver_assigned' &&
        deliveryStatus != 'picked_up' &&
        deliveryStatus != 'delivered' &&
        deliveryStatus != 'cancelled';

    final canMarkReady =
        status == 'confirmed' && deliveryStatus == 'awaiting_store_ready';

    return PortalSoftCard(
      padding: const EdgeInsets.all(PortalTokens.space2),
      radius: PortalTokens.radius2xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Orden #$shortId',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: meta.color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  meta.label,
                  style: TextStyle(color: meta.color, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: PortalTokens.space2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: firstImage != null
                      ? PortalCachedImage(imageUrl: firstImage, fit: BoxFit.cover, memCacheWidth: 256)
                      : ColoredBox(
                          color: scheme.surfaceContainerHigh,
                          child: Icon(Icons.shopping_bag_outlined, color: scheme.onSurfaceVariant),
                        ),
                ),
              ),
              const SizedBox(width: PortalTokens.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lines,
                      style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      buyer,
                      style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                    if (addr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        addr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                'Bs ${totalNum.toStringAsFixed(2)}',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (status == 'pending') ...[
            const SizedBox(height: PortalTokens.space2),
            Text(
              'Esperando confirmación de pago del cliente.',
              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (canMarkReady || canReject) ...[
            const SizedBox(height: PortalTokens.space2),
            Row(
              children: [
                if (canReject)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              portalHapticLight();
                              _run(() async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('¿Cancelar pedido?'),
                                    content: const Text(
                                      'El cliente verá el pedido como cancelado. No aplica si ya hay repartidor asignado.',
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Sí, cancelar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await PortalOrdersService.rejectOrder(orderId);
                                }
                              });
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error.withValues(alpha: 0.65)),
                      ),
                      child: const Text('Rechazar'),
                    ),
                  ),
                if (canMarkReady) ...[
                  if (canReject) const SizedBox(width: PortalTokens.space2),
                  Expanded(
                    flex: canReject ? 1 : 2,
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : () {
                              portalHapticLight();
                              _run(() => PortalOrdersService.markReadyForPickup(orderId));
                            },
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Listo para recoger'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  ({Color color, String label}) _statusPresentation(String status, String deliveryStatus) {
    if (status == 'cancelled' || deliveryStatus == 'cancelled') {
      return (color: const Color(0xFFEF4444), label: 'Cancelado');
    }
    if (status == 'delivered' || deliveryStatus == 'delivered') {
      return (color: const Color(0xFF22C55E), label: 'Entregado');
    }
    if (status == 'pending') {
      return (color: const Color(0xFFF59E0B), label: 'Pago pendiente');
    }
    return switch (deliveryStatus) {
      'awaiting_store_ready' => (color: const Color(0xFF3B82F6), label: 'Preparando'),
      'awaiting_driver' => (color: const Color(0xFF8B5CF6), label: 'Buscando repartidor'),
      'driver_assigned' => (color: const Color(0xFF06B6D4), label: 'Repartidor asignado'),
      'picked_up' => (color: const Color(0xFFA855F7), label: 'En camino'),
      _ => (color: const Color(0xFF8E8E93), label: status),
    };
  }
}
