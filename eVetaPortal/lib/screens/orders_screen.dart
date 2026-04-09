import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _isLoading = true;
  List<dynamic> _allOrders = [];
  List<dynamic> _filteredOrders = [];
  String _currentFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Fetch order items and their related order and product data
      final response = await Supabase.instance.client
          .from('order_items')
          .select('*, orders(status, created_at, buyer_id), products(name, images)')
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _allOrders = response as List<dynamic>;
        _applyFilter(_currentFilter);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _currentFilter = filter;
      if (filter == 'Todos') {
        _filteredOrders = _allOrders;
      } else if (filter == 'Pendientes') {
        _filteredOrders = _allOrders.where((item) => item['orders']?['status'] == 'pending').toList();
      } else if (filter == 'Completados') {
        _filteredOrders = _allOrders.where((item) => item['orders']?['status'] == 'delivered').toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pedidos', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchOrders();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(child: _buildFilterChip('Todos', _currentFilter == 'Todos')),
                const SizedBox(width: 8),
                Expanded(child: _buildFilterChip('Pendientes', _currentFilter == 'Pendientes')),
                const SizedBox(width: 8),
                Expanded(child: _buildFilterChip('Completados', _currentFilter == 'Completados')),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF09CB6B)))
          : _filteredOrders.isEmpty
              ? Center(
                  child: Text(
                    'No hay pedidos ${_currentFilter.toLowerCase()}.',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredOrders.length,
                  itemBuilder: (context, index) {
                    final item = _filteredOrders[index];
                    final status = item['orders']?['status'] ?? 'pending';
                    final isPending = status == 'pending';
                    final productName = item['products']?['name'] ?? 'Producto Desconocido';
                    final quantity = item['quantity'] ?? 1;
                    final total = item['total'] ?? 0;
                    final orderId = item['order_id']?.toString().substring(0, 8) ?? '---';
                    final images = item['products']?['images'] as List<dynamic>?;
                    final imageUrl = (images != null && images.isNotEmpty) ? images[0] : null;

                    Color statusColor = Colors.grey;
                    String statusText = status.toString().toUpperCase();
                    
                    if (status == 'pending') { statusColor = Colors.orange; statusText = 'Pendiente'; }
                    else if (status == 'confirmed') { statusColor = Colors.blue; statusText = 'Confirmado'; }
                    else if (status == 'shipped') { statusColor = Colors.purple; statusText = 'Enviado'; }
                    else if (status == 'delivered') { statusColor = Colors.green; statusText = 'Entregado'; }
                    else if (status == 'cancelled') { statusColor = Colors.red; statusText = 'Cancelado'; }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Orden #$orderId',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: imageUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(imageUrl, fit: BoxFit.cover),
                                        )
                                      : const Icon(Icons.image, color: Colors.grey),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('$productName x$quantity', style: const TextStyle(fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      Text('Total a recibir:', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\$${total.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            if (isPending) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {},
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                      ),
                                      child: const Text('Rechazar'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {},
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Aceptar'),
                                    ),
                                  ),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => _applyFilter(label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF09CB6B) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
