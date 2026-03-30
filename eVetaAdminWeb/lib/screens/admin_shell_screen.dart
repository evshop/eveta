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
    'Subir productos',
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
      backgroundColor: Colors.white,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E8EC)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) => setState(() => _index = value),
                  labelType: NavigationRailLabelType.all,
                  useIndicator: true,
                  minWidth: 76,
                  groupAlignment: -0.2,
                  leading: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 20),
                    child: Text(
                      'eVeta',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: -0.3,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.campaign_outlined),
                      selectedIcon: Icon(Icons.campaign_rounded),
                      label: Text('Promos'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2_rounded),
                      label: Text('Categorías'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.shopping_basket_outlined),
                      selectedIcon: Icon(Icons.shopping_basket_rounded),
                      label: Text('Subir'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.storefront_outlined),
                      selectedIcon: Icon(Icons.storefront_rounded),
                      label: Text('Tiendas'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: Text('Pedidos'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E8EC)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              _titles[_index],
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                                color: Colors.grey.shade900,
                              ),
                            ),
                            const Spacer(),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await AuthService.signOut();
                              },
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              label: const Text('Salir'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Panel de administración',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(child: sections[_index]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
