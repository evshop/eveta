import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/portal_auth_gate.dart';
import '../widgets/portal/portal_haptics.dart';
import '../widgets/portal/portal_tokens.dart';
import 'admin_panel_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
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
    var resolvedIsAdmin = cachedIsAdmin ?? false;

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Gate estricto: si la cuenta es Delivery o no tiene perfil portal activo,
      // cierra sesión y vuelve al login.
      final gate = await PortalAuthGate.verifyCurrentSession();
      if (!gate.allowed) {
        await prefs.remove('isLoggedIn');
        await prefs.remove('userEmail');
        await prefs.remove('isAdmin');
        await prefs.remove('isSeller');
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }
      final profile = gate.profile ?? const <String, dynamic>{};
      resolvedIsAdmin = profile['is_admin'] == true;
      await prefs.setBool('isAdmin', resolvedIsAdmin);
      await prefs.setBool('isSeller', profile['is_seller'] == true);
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
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: scheme.primary)),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    final pages = <Widget>[
      ..._basePages,
      if (_isAdmin) const AdminPanelScreen(),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: 'Inicio',
      ),
      const NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long_rounded),
        label: 'Pedidos',
      ),
      const NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2_rounded),
        label: 'Productos',
      ),
      const NavigationDestination(
        icon: Icon(Icons.storefront_outlined),
        selectedIcon: Icon(Icons.storefront_rounded),
        label: 'Mi tienda',
      ),
      if (_isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings_rounded),
          label: 'Admin',
        ),
    ];

    final navIndex = _currentIndex >= pages.length ? 0 : _currentIndex;
    if (navIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = navIndex);
      });
    }

    return Scaffold(
      body: AnimatedSwitcher(
        duration: PortalTokens.motionNormal,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offset = Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(navIndex),
          child: pages[navIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (i) {
          portalHapticSelect();
          setState(() => _currentIndex = i);
        },
        destinations: destinations,
        backgroundColor: scheme.surfaceContainerHighest,
        indicatorColor: scheme.primary.withValues(alpha: 0.2),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
