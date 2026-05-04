import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/admin_theme.dart';
import '../widgets/admin/eveta_skeleton.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Future<Map<String, int>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<Map<String, int>> _loadStats() async {
    final client = Supabase.instance.client;
    final products = await client.from('products').select('id');
    final categories = await client.from('categories').select('id');
    final orders = await client.from('orders').select('id');
    final sellers = await client.from('profiles_portal').select('id').eq('is_seller', true).eq('is_active', true);
    return {
      'Productos': (products as List).length,
      'Categorías': (categories as List).length,
      'Pedidos': (orders as List).length,
      'Tiendas': (sellers as List).length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<Map<String, int>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return LayoutBuilder(
            builder: (context, c) {
              final cross = c.maxWidth > 1000
                  ? 4
                  : c.maxWidth > 700
                      ? 2
                      : 1;
              return GridView.count(
                crossAxisCount: cross,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.45,
                children: List.generate(4, (_) => const EvetaMetricCardSkeleton()),
              );
            },
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'No se pudieron cargar las métricas.',
              style: TextStyle(color: scheme.error),
            ),
          );
        }
        final stats = snapshot.data!;
        final entries = stats.entries.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final cross = w > 1000
                      ? 4
                      : w > 700
                          ? 2
                          : 1;
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: w > 700 ? 1.5 : 1.35,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      return _MetricCard(title: e.key, value: e.value);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Actividad reciente',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                child: Row(
                  children: [
                    Icon(Icons.insights_outlined, color: scheme.primary, size: 26),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'El historial de actividad detallado se conectará en una próxima versión.',
                        style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatefulWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final int value;

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  bool _hover = false;

  IconData _iconFor(String t) {
    switch (t) {
      case 'Productos':
        return Icons.inventory_2_outlined;
      case 'Categorías':
        return Icons.category_outlined;
      case 'Pedidos':
        return Icons.receipt_long_outlined;
      case 'Tiendas':
        return Icons.storefront_outlined;
      default:
        return Icons.analytics_outlined;
    }
  }

  Color _softTone(String t, ColorScheme scheme) {
    switch (t) {
      case 'Pedidos':
        return const Color(0xFFFDA4AF);
      case 'Categorías':
        return const Color(0xFF93C5FD);
      case 'Tiendas':
        return const Color(0xFF86EFAC);
      default:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = _softTone(widget.title, scheme);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        offset: Offset(0, _hover ? -0.01 : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B1736).withValues(alpha: _hover ? 0.1 : 0.05),
                blurRadius: _hover ? 24 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
                            color: tone.withValues(alpha: 0.18),
                          ),
                          child: Icon(_iconFor(widget.title), color: tone, size: 22),
                        ),
                        const Spacer(),
                        Text(
                          '${widget.value}',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.9,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

