import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'categories_screen.dart';
import 'dashboard_screen.dart';
import 'home_promotion_banners_screen.dart';
import 'stores_hub_screen.dart';
import 'products_screen.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _index = 0;
  static const _titles = [
    'Dashboard',
    'Promociones',
    'Categorías',
    'Productos',
    'Tiendas',
    'Pedidos',
  ];

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      const DashboardScreen(),
      const HomePromotionBannersScreen(),
      const CategoriesScreen(),
      const ProductsScreen(),
      const StoresHubScreen(),
      const Center(child: Text('Módulo de pedidos globales (siguiente fase)')),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.campaign_outlined),
                selectedIcon: Icon(Icons.campaign),
                label: Text('Promociones'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Categorías'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shopping_basket_outlined),
                selectedIcon: Icon(Icons.shopping_basket),
                label: Text('Productos'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.store_mall_directory_outlined),
                selectedIcon: Icon(Icons.store_mall_directory),
                label: Text('Tiendas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Pedidos'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        _titles[_index],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await AuthService.signOut();
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: sections[_index]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
