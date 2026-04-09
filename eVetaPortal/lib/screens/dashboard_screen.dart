import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Fetch products count
      final productsResponse = await Supabase.instance.client
          .from('products')
          .select('id')
          .eq('seller_id', user.id);
          
      final productsCount = (productsResponse as List).length;
      
      // Fetch order items (to calculate revenue and get recent orders)
      // Since orders are tied to buyers, sellers see their sales through order_items
      final orderItemsResponse = await Supabase.instance.client
          .from('order_items')
          .select('*, orders(status, created_at, buyer_id), products(name)')
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);

      double revenue = 0;
      int pending = 0;
      List<dynamic> items = orderItemsResponse as List<dynamic>;
      
      // We need to count unique orders, not just items
      final Set<String> uniqueOrderIds = {};

      for (var item in items) {
        final orderStatus = item['orders']?['status'];
        if (orderStatus != 'cancelled') {
          revenue += (item['total'] ?? 0);
        }
        if (orderStatus == 'pending') {
          pending++;
        }
        if (item['order_id'] != null) {
          uniqueOrderIds.add(item['order_id'].toString());
        }
      }

      setState(() {
        _totalProducts = productsCount;
        _totalRevenue = revenue;
        _totalOrders = uniqueOrderIds.length;
        _pendingOrders = pending;
        _recentOrders = items.take(5).toList(); // Show top 5 recent items
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchDashboardData();
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF09CB6B)))
        : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen de tu tienda',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatCard('Ingresos', '\$${_totalRevenue.toStringAsFixed(2)}', Icons.attach_money, Colors.green)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Pedidos', '$_totalOrders', Icons.shopping_bag, Colors.blue)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatCard('Pendientes', '$_pendingOrders', Icons.pending_actions, Colors.orange)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Productos', '$_totalProducts', Icons.inventory_2, Colors.purple)),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Ventas Recientes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRecentOrderList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrderList() {
    if (_recentOrders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('Aún no tienes ventas recientes.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentOrders.length,
      itemBuilder: (context, index) {
        final item = _recentOrders[index];
        final productName = item['products']?['name'] ?? 'Producto';
        final status = item['orders']?['status'] ?? 'pending';
        final total = item['total'] ?? 0;
        final orderId = item['order_id']?.toString().substring(0, 8) ?? '---';
        
        Color statusColor = Colors.orange;
        String statusText = 'Pendiente';
        
        if (status == 'delivered') {
          statusColor = Colors.green;
          statusText = 'Entregado';
        } else if (status == 'cancelled') {
          statusColor = Colors.red;
          statusText = 'Cancelado';
        } else if (status == 'confirmed') {
          statusColor = Colors.blue;
          statusText = 'Confirmado';
        } else if (status == 'shipped') {
          statusColor = Colors.purple;
          statusText = 'Enviado';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long, color: statusColor),
            ),
            title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Orden #$orderId', style: const TextStyle(fontSize: 12)),
                Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            trailing: Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        );
      },
    );
  }
}
