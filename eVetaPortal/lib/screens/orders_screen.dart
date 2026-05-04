import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/portal_session.dart';
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
  List<dynamic> _allOrders = [];
  List<dynamic> _filteredOrders = [];
  String _segment = 'todos';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final sellerId = await PortalSession.currentSellerId();
      if (sellerId == null) return;

      final response = await Supabase.instance.client
          .from('order_items')
          .select('*, orders(status, created_at, buyer_id), products(name, images)')
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _allOrders = response as List<dynamic>;
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
        _filteredOrders = List<dynamic>.from(_allOrders);
      } else if (seg == 'pendientes') {
        _filteredOrders = _allOrders.where((item) => item['orders']?['status'] == 'pending').toList();
      } else {
        _filteredOrders = _allOrders.where((item) => item['orders']?['status'] == 'delivered').toList();
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
                              final item = _filteredOrders[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: PortalTokens.space2),
                                child: _OrderCard(item: item),
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
      'pendientes' => 'Cuando tengas pedidos por confirmar, aparecerán aquí.',
      'completados' => 'Los pedidos entregados se listan en esta pestaña.',
      _ => 'Cuando recibas tu primera venta, la verás en esta lista.',
    };
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.item});

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final status = item['orders']?['status'] ?? 'pending';
    final isPending = status == 'pending';
    final productName = item['products']?['name'] ?? 'Producto';
    final quantity = item['quantity'] ?? 1;
    final total = (item['total'] ?? 0) as num;
    final orderId = item['order_id']?.toString() ?? '';
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8) : orderId;
    final images = item['products']?['images'] as List<dynamic>?;
    final imageUrl = (images != null && images.isNotEmpty) ? images[0] as String : null;

    final meta = _statusMeta(status);

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
                  child: imageUrl != null
                      ? PortalCachedImage(imageUrl: imageUrl, fit: BoxFit.cover, memCacheWidth: 256)
                      : ColoredBox(
                          color: scheme.surfaceContainerHigh,
                          child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
                        ),
                ),
              ),
              const SizedBox(width: PortalTokens.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$productName ×$quantity',
                      style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total',
                      style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                'Bs ${total.toStringAsFixed(2)}',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: PortalTokens.space2),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => portalHapticLight(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error.withValues(alpha: 0.65)),
                    ),
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: PortalTokens.space2),
                Expanded(
                  child: FilledButton(
                    onPressed: () => portalHapticLight(),
                    child: const Text('Aceptar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  ({Color color, String label}) _statusMeta(String status) {
    return switch (status) {
      'pending' => (color: const Color(0xFFF59E0B), label: 'Pendiente'),
      'confirmed' => (color: const Color(0xFF3B82F6), label: 'Confirmado'),
      'shipped' => (color: const Color(0xFFA855F7), label: 'Enviado'),
      'delivered' => (color: const Color(0xFF22C55E), label: 'Entregado'),
      'cancelled' => (color: const Color(0xFFEF4444), label: 'Cancelado'),
      _ => (color: const Color(0xFF8E8E93), label: status.toString()),
    };
  }
}
