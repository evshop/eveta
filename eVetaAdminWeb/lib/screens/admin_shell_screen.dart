import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings.dart';
import '../services/auth_service.dart';
import '../theme/admin_theme.dart';
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;

  static const _titles = [
    'Dashboard',
    'Promociones',
    'Categorías',
    'Subir productos',
    'Tiendas',
    'Pedidos',
  ];

  static const _subtitles = [
    'Resumen y métricas',
    'Banners del inicio en la app',
    'Árbol de categorías y medios',
    'Catálogo de tu tienda oficial',
    'Tiendas verificadas y accesos',
    'Próximamente',
  ];

  List<Widget> get _sections => const [
        DashboardScreen(),
        HomePromotionBannersScreen(),
        CategoriesScreen(),
        ProductsScreen(),
        StoresHubScreen(),
        _OrdersPlaceholder(),
      ];

  int _bottomNavSelected() {
    switch (_index) {
      case 0:
        return 0;
      case 2:
        return 1;
      case 4:
        return 2;
      default:
        return 3;
    }
  }

  void _onBottomNav(int i) {
    if (i == 3) {
      _showMoreNavSheet();
      return;
    }
    setState(() {
      switch (i) {
        case 0:
          _index = 0;
          break;
        case 1:
          _index = 2;
          break;
        case 2:
          _index = 4;
          break;
        default:
          break;
      }
    });
  }

  void _showMoreNavSheet() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AdminTokens.radiusLg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.outline.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              _MoreTile(
                icon: Icons.campaign_rounded,
                label: 'Promociones',
                selected: _index == 1,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _index = 1);
                },
              ),
              _MoreTile(
                icon: Icons.shopping_basket_rounded,
                label: 'Subir productos',
                selected: _index == 3,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _index = 3);
                },
              ),
              _MoreTile(
                icon: Icons.receipt_long_rounded,
                label: 'Pedidos',
                selected: _index == 5,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _index = 5);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        if (w >= 1100) {
          return _DesktopShell(
            selectedIndex: _index,
            onSelect: (i) => setState(() => _index = i),
            titles: _titles,
            subtitles: _subtitles,
            child: _sections[_index],
          );
        }
        if (w >= 720) {
          return _TabletShell(
            selectedIndex: _index,
            onSelect: (i) => setState(() => _index = i),
            titles: _titles,
            subtitles: _subtitles,
            extended: w >= 960,
            child: _sections[_index],
          );
        }
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: scheme.surface,
          drawer: _AdminDrawer(
            selectedIndex: _index,
            onSelect: (i) {
              Navigator.of(context).pop();
              setState(() => _index = i);
            },
          ),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_titles[_index]),
                Text(
                  _subtitles[_index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Menú',
            ),
            actions: const [_ThemeToggleIcon(), _LogoutIconButton()],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey<int>(_index),
              child: _sections[_index],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _bottomNavSelected(),
            onDestinationSelected: _onBottomNav,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category_rounded),
                label: 'Catálogo',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Tiendas',
              ),
              NavigationDestination(
                icon: Icon(Icons.more_horiz_rounded),
                selectedIcon: Icon(Icons.more_horiz_rounded),
                label: 'Más',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrdersPlaceholder extends StatelessWidget {
  const _OrdersPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_rounded, size: 48, color: scheme.primary.withValues(alpha: 0.85)),
                const SizedBox(height: 16),
                Text(
                  'Pedidos globales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Este módulo se habilitará en una siguiente fase.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
      title: Text(
        label,
        style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
      ),
      trailing: selected ? Icon(Icons.check_rounded, color: scheme.primary) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminTokens.radiusSm)),
      onTap: onTap,
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const items = [
      (Icons.dashboard_rounded, 'Dashboard', 0),
      (Icons.campaign_rounded, 'Promociones', 1),
      (Icons.inventory_2_rounded, 'Categorías', 2),
      (Icons.shopping_basket_rounded, 'Subir productos', 3),
      (Icons.storefront_rounded, 'Tiendas', 4),
      (Icons.receipt_long_rounded, 'Pedidos', 5),
    ];
    return Drawer(
      backgroundColor: scheme.surfaceContainerHighest,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'eVeta',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: scheme.primary,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  for (final e in items)
                    ListTile(
                      leading: Icon(e.$1),
                      title: Text(e.$2),
                      selected: selectedIndex == e.$3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
                      ),
                      onTap: () => onSelect(e.$3),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                children: [
                  _ThemeToggleIcon(),
                  SizedBox(width: 8),
                  _LogoutIconButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.selectedIndex,
    required this.onSelect,
    required this.titles,
    required this.subtitles,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<String> titles;
  final List<String> subtitles;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sidebar(
            selectedIndex: selectedIndex,
            onSelect: onSelect,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 24, 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.65,
                  ),
                  borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 20, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titles[selectedIndex],
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.6,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitles[selectedIndex],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const _ThemeToggleIcon(),
                            const SizedBox(width: 4),
                            const _LogoutIconButton(),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: KeyedSubtree(
                              key: ValueKey<int>(selectedIndex),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _TabletShell extends StatelessWidget {
  const _TabletShell({
    required this.selectedIndex,
    required this.onSelect,
    required this.titles,
    required this.subtitles,
    required this.extended,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<String> titles;
  final List<String> subtitles;
  final bool extended;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final railWidth = extended ? 220.0 : 80.0;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: railWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: Text(
                      'eVeta',
                    textAlign: extended ? TextAlign.left : TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                      fontSize: extended ? 18 : 14,
                      letterSpacing: -0.4,
                      color: scheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: NavigationRail(
                    extended: extended,
                    minWidth: 72,
                    minExtendedWidth: 200,
                    labelType: extended
                        ? NavigationRailLabelType.all
                        : NavigationRailLabelType.none,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onSelect,
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
                        label: Text('Productos'),
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
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _ThemeToggleIcon(),
                      _LogoutIconButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: scheme.outline.withValues(alpha: 0.15)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titles[selectedIndex],
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              subtitles[selectedIndex],
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                        key: ValueKey<int>(selectedIndex),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      (Icons.dashboard_rounded, 'Dashboard', 0),
      (Icons.campaign_rounded, 'Promociones', 1),
      (Icons.inventory_2_rounded, 'Categorías', 2),
      (Icons.shopping_basket_rounded, 'Subir productos', 3),
      (Icons.storefront_rounded, 'Tiendas', 4),
      (Icons.receipt_long_rounded, 'Pedidos', 5),
    ];
    return Container(
      width: AdminTokens.sidebarWidth,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
      decoration: BoxDecoration(
        color: isDark ? AdminTokens.darkSurface : scheme.surfaceContainerHighest,
        border: Border(
          right: BorderSide(color: scheme.outline.withValues(alpha: 0.12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: scheme.primary.withValues(alpha: 0.15),
                  ),
                  child: Icon(Icons.shield_rounded, color: scheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'eVeta',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'ADMIN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, i) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final e = items[i];
                final sel = selectedIndex == e.$3;
                return _SidebarItem(
                  icon: e.$1,
                  label: e.$2,
                  selected: sel,
                  onTap: () => onSelect(e.$3),
                );
              },
            ),
          ),
          const Divider(height: 24),
          const _ThemeToggleTile(),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded, color: scheme.onSurfaceVariant),
            title: const Text('Cerrar sesión'),
            onTap: () => AuthService.signOut(),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminTokens.radiusSm)),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = widget.selected
        ? scheme.primary.withValues(alpha: 0.14)
        : (_hover ? scheme.onSurface.withValues(alpha: 0.06) : Colors.transparent);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 22,
                  color: widget.selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                      color: widget.selected ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleIcon extends StatelessWidget {
  const _ThemeToggleIcon();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final mode = settings.themeMode;
    IconData icon;
    String tip;
    switch (mode) {
      case ThemeMode.system:
        icon = Icons.brightness_auto_rounded;
        tip = 'Tema: sistema';
      case ThemeMode.light:
        icon = Icons.light_mode_rounded;
        tip = 'Tema: claro';
      case ThemeMode.dark:
        icon = Icons.dark_mode_rounded;
        tip = 'Tema: oscuro';
    }
    return IconButton(
      tooltip: tip,
      onPressed: () => settings.cycleTheme(),
      icon: Icon(icon),
    );
  }
}

class _ThemeToggleTile extends StatelessWidget {
  const _ThemeToggleTile();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.palette_outlined, color: scheme.onSurfaceVariant),
      title: const Text('Apariencia'),
      subtitle: Text(
        switch (settings.themeMode) {
          ThemeMode.system => 'Seguir sistema',
          ThemeMode.light => 'Claro',
          ThemeMode.dark => 'Oscuro',
        },
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      onTap: () => settings.cycleTheme(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminTokens.radiusSm)),
    );
  }
}

class _LogoutIconButton extends StatelessWidget {
  const _LogoutIconButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Salir',
      onPressed: () => AuthService.signOut(),
      icon: const Icon(Icons.logout_rounded),
    );
  }
}
