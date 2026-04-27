import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:eveta/common_widget/eveta_circular_back_button.dart';
import 'package:eveta/utils/order_service.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = OrderService.fetchMyOrders();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = OrderService.fetchMyOrders();
    });
    await _future;
  }

  String _labelDelivery(String? s) {
    switch (s) {
      case 'awaiting_driver':
        return 'Buscando repartidor';
      case 'driver_assigned':
        return 'Repartidor asignado';
      case 'picked_up':
        return 'En camino';
      case 'delivered':
        return 'Entregado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return s ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        leading: EvetaCircularBackButton(
          variant: Theme.of(context).brightness == Brightness.dark
              ? EvetaCircularBackVariant.tonalSurface
              : EvetaCircularBackVariant.onLightBackground,
        ),
        title: Text(
          'Mis pedidos',
          style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text('Inicia sesión para ver tus pedidos.'))
          : RefreshIndicator(
              color: scheme.primary,
              onRefresh: _refresh,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: scheme.primary));
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  final rows = snap.data ?? [];
                  if (rows.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey),
                        SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Aún no tienes pedidos',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final o = rows[i];
                      final id = o['id']?.toString() ?? '';
                      final total = o['total'];
                      final dist = o['distance_km'];
                      final addr = o['dropoff_address']?.toString() ?? '';
                      final ds = o['delivery_status']?.toString();
                      final statusColor = switch (ds) {
                        'delivered' => Colors.blueGrey,
                        'cancelled' => Colors.redAccent,
                        _ => scheme.onSurfaceVariant,
                      };
                      return Material(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {},
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Pedido ${id.length > 8 ? id.substring(0, 8) : id}…',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _labelDelivery(ds),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  addr.isEmpty ? 'Sin dirección' : addr,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      dist != null
                                          ? '${(dist is num ? dist.toDouble() : double.tryParse(dist.toString()) ?? 0).toStringAsFixed(1)} km'
                                          : '— km',
                                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                                    ),
                                    Text(
                                      'Bs ${total?.toString() ?? '0'}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ],
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
            ),
    );
  }
}
