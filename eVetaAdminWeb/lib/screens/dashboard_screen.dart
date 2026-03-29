import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<Map<String, int>> _loadStats() async {
    final client = Supabase.instance.client;
    final products = await client.from('products').select('id');
    final categories = await client.from('categories').select('id');
    final orders = await client.from('orders').select('id');
    final sellers = await client.from('profiles').select('id').eq('is_seller', true);
    return {
      'Productos': (products as List).length,
      'Categorías': (categories as List).length,
      'Pedidos': (orders as List).length,
      'Tiendas': (sellers as List).length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _loadStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snapshot.data!;
        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: stats.entries
              .map(
                (e) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${e.value}',
                          style: const TextStyle(
                            fontSize: 22,
                            color: Color(0xFF09CB6B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
