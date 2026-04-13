import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/portal/portal_dashboard_skeleton.dart';
import '../widgets/portal/portal_haptics.dart';
import '../widgets/portal/portal_sales_chart.dart';
import '../widgets/portal/portal_section_header.dart';
import '../widgets/portal/portal_soft_card.dart';
import '../widgets/portal/portal_tokens.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  double _totalRevenue = 0;
  int _totalOrders = 0;
  int _pendingOrders = 0;
  int _totalProducts = 0;
  List<dynamic> _recentOrders = [];
  List<double> _salesByDay = List.filled(7, 0);
  List<String> _chartLabels = [];

  static const _wd = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _fetchDashboardData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final productsResponse = await Supabase.instance.client.from('products').select('id').eq('seller_id', user.id);

      final productsCount = (productsResponse as List).length;

      final orderItemsResponse = await Supabase.instance.client
          .from('order_items')
          .select('*, orders(status, created_at, buyer_id), products(name)')
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);

      double revenue = 0;
      int pending = 0;
      final items = orderItemsResponse as List<dynamic>;
      final uniqueOrderIds = <String>{};
      final now = DateTime.now();
      final salesByDay = List<double>.filled(7, 0);
      final labels = List<String>.generate(7, (b) {
        final ref = _dateOnly(now.subtract(Duration(days: 6 - b)));
        return _wd[ref.weekday - 1];
      });

      for (final item in items) {
        final orderStatus = item['orders']?['status'];
        if (orderStatus != 'cancelled') {
          revenue += ((item['total'] ?? 0) as num).toDouble();
        }
        if (orderStatus == 'pending') {
          pending++;
        }
        if (item['order_id'] != null) {
          uniqueOrderIds.add(item['order_id'].toString());
        }

        if (orderStatus == 'cancelled') continue;
        final rawCreated = item['created_at'];
        if (rawCreated == null) continue;
        try {
          final d = _dateOnly(DateTime.parse(rawCreated.toString()).toLocal());
          for (var b = 0; b < 7; b++) {
            final ref = _dateOnly(now.subtract(Duration(days: 6 - b)));
            if (d == ref) {
              salesByDay[b] += ((item['total'] ?? 0) as num).toDouble();
              break;
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _totalProducts = productsCount;
        _totalRevenue = revenue;
        _totalOrders = uniqueOrderIds.length;
        _pendingOrders = pending;
        _recentOrders = items.take(5).toList();
        _salesByDay = salesByDay;
        _chartLabels = labels;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              portalHapticLight();
              setState(() => _isLoading = true);
              _fetchDashboardData();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: PortalTokens.motionNormal,
          child: _isLoading
              ? const PortalDashboardSkeleton(key: ValueKey('sk'))
              : SingleChildScrollView(
                  key: const ValueKey('data'),
                  padding: const EdgeInsets.fromLTRB(
                    PortalTokens.space2,
                    PortalTokens.space1,
                    PortalTokens.space2,
                    PortalTokens.space4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumen de tu tienda',
                        style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Métricas y actividad reciente',
                        style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: PortalTokens.space3),
                      _MetricGrid(
                        revenue: _totalRevenue,
                        orders: _totalOrders,
                        pending: _pendingOrders,
                        products: _totalProducts,
                      ),
                      const SizedBox(height: PortalTokens.space3),
                      const PortalSectionHeader(
                        title: 'Ventas (7 días)',
                        subtitle: 'Total por día en tu moneda',
                      ),
                      PortalSalesChart(labels: _chartLabels, values: _salesByDay),
                      const SizedBox(height: PortalTokens.space3),
                      const PortalSectionHeader(
                        title: 'Ventas recientes',
                        subtitle: 'Últimos movimientos en tu tienda',
                      ),
                      _RecentBlock(orders: _recentOrders),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.revenue,
    required this.orders,
    required this.pending,
    required this.products,
  });

  final double revenue;
  final int orders;
  final int pending;
  final int products;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _PastelMetricCard(
                title: 'Ingresos',
                value: 'Bs ${revenue.toStringAsFixed(2)}',
                icon: Icons.payments_rounded,
                tint: const Color(0xFF34D399),
                background: scheme.primary.withValues(alpha: 0.14),
              ),
            ),
            const SizedBox(width: PortalTokens.space2),
            Expanded(
              child: _PastelMetricCard(
                title: 'Pedidos',
                value: '$orders',
                icon: Icons.shopping_bag_rounded,
                tint: const Color(0xFF60A5FA),
                background: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
        const SizedBox(height: PortalTokens.space2),
        Row(
          children: [
            Expanded(
              child: _PastelMetricCard(
                title: 'Pendientes',
                value: '$pending',
                icon: Icons.schedule_rounded,
                tint: const Color(0xFFFB923C),
                background: const Color(0xFFF97316).withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(width: PortalTokens.space2),
            Expanded(
              child: _PastelMetricCard(
                title: 'Productos',
                value: '$products',
                icon: Icons.inventory_2_rounded,
                tint: const Color(0xFFA78BFA),
                background: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PastelMetricCard extends StatelessWidget {
  const _PastelMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
    required this.background,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tint;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return PortalSoftCard(
      padding: const EdgeInsets.all(PortalTokens.space2 + 4),
      radius: PortalTokens.radius2xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(PortalTokens.radiusMd),
            ),
            child: Icon(icon, color: tint, size: 26),
          ),
          const SizedBox(height: PortalTokens.space2),
          Text(
            value,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _RecentBlock extends StatelessWidget {
  const _RecentBlock({required this.orders});

  final List<dynamic> orders;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (orders.isEmpty) {
      return PortalSoftCard(
        padding: const EdgeInsets.all(PortalTokens.space3),
        child: Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: scheme.onSurfaceVariant.withValues(alpha: 0.5), size: 40),
            const SizedBox(width: PortalTokens.space2),
            Expanded(
              child: Text(
                'Aún no tienes ventas recientes. Cuando vendas, aparecerán aquí.',
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final item in orders) _RecentTile(item: item),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.item});

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final productName = item['products']?['name'] ?? 'Producto';
    final status = item['orders']?['status'] ?? 'pending';
    final total = (item['total'] ?? 0) as num;
    final orderId = item['order_id']?.toString() ?? '';
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8) : orderId;

    final meta = _statusMeta(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: PortalTokens.space2),
      child: PortalSoftCard(
        padding: const EdgeInsets.all(PortalTokens.space2),
        radius: PortalTokens.radiusXl,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(PortalTokens.radiusMd),
              ),
              child: Icon(Icons.receipt_rounded, color: meta.color, size: 24),
            ),
            const SizedBox(width: PortalTokens.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('Orden #$shortId', style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      meta.label,
                      style: TextStyle(color: meta.color, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
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
      ),
    );
  }

  ({Color color, String label}) _statusMeta(String status) {
    return switch (status) {
      'delivered' => (color: const Color(0xFF22C55E), label: 'Entregado'),
      'cancelled' => (color: const Color(0xFFEF4444), label: 'Cancelado'),
      'confirmed' => (color: const Color(0xFF3B82F6), label: 'Confirmado'),
      'shipped' => (color: const Color(0xFFA855F7), label: 'Enviado'),
      _ => (color: const Color(0xFFF59E0B), label: 'Pendiente'),
    };
  }
}
