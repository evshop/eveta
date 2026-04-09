import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_panel_screen.dart';
import 'dashboard_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isAdmin = false;
  bool _isReady = false;

  final List<Widget> _basePages = const [
    DashboardScreen(),
    OrdersScreen(),
    ProductsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _bootstrapRole();
  }

  Future<void> _bootstrapRole() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedIsAdmin = prefs.getBool('isAdmin');
    bool resolvedIsAdmin = cachedIsAdmin ?? false;

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null) {
        resolvedIsAdmin = profile['is_admin'] == true;
        await prefs.setBool('isAdmin', resolvedIsAdmin);
      }
    }
    if (!mounted) return;
    setState(() {
      _isAdmin = resolvedIsAdmin;
      _isReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF09CB6B)),
        ),
      );
    }

    final pages = <Widget>[
      ..._basePages,
      if (_isAdmin) const AdminPanelScreen(),
    ];
    final tabItems = <TabItem>[
      const TabItem(icon: Icons.dashboard, title: 'Dashboard'),
      const TabItem(icon: Icons.receipt_long, title: 'Pedidos'),
      const TabItem(icon: Icons.inventory_2, title: 'Productos'),
      const TabItem(icon: Icons.person, title: 'Perfil'),
      if (_isAdmin) const TabItem(icon: Icons.admin_panel_settings, title: 'Admin'),
    ];

    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: pages[_currentIndex],
      ),
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.reactCircle,
        backgroundColor: Colors.white,
        activeColor: const Color(0xFF09CB6B),
        color: Colors.grey,
        curveSize: 80,
        elevation: 2,
        items: tabItems,
        initialActiveIndex: _currentIndex,
        onTap: (int i) {
          setState(() {
            _currentIndex = i;
          });
        },
      ),
    );
  }
}
