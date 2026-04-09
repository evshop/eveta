import 'package:flutter/material.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      appBar: AppBar(
        title: const Text('Panel Admin', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _AdminItem(
            icon: Icons.store_mall_directory_outlined,
            title: 'Gestión de tiendas',
            subtitle: 'Crear cuentas de tiendas y activar/desactivar acceso',
          ),
          _AdminItem(
            icon: Icons.inventory_2_outlined,
            title: 'Productos globales',
            subtitle: 'Ver y moderar productos de todas las tiendas',
          ),
          _AdminItem(
            icon: Icons.receipt_long_outlined,
            title: 'Pedidos globales',
            subtitle: 'Revisar pedidos del sistema y su estado',
          ),
          _AdminItem(
            icon: Icons.local_shipping_outlined,
            title: 'Delivery',
            subtitle: 'Asignar repartidores y monitorear entregas',
          ),
          _AdminItem(
            icon: Icons.insights_outlined,
            title: 'Reportes',
            subtitle: 'Métricas generales de ventas y operación',
          ),
        ],
      ),
    );
  }
}

class _AdminItem extends StatelessWidget {
  const _AdminItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF09CB6B).withValues(alpha: 0.15),
          child: Icon(icon, color: const Color(0xFF09CB6B)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Próximo módulo: $title')),
          );
        },
      ),
    );
  }
}
