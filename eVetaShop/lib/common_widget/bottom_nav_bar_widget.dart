import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:eveta/animation_navbar/home.dart';
import 'package:eveta/theme/shop_system_ui.dart';
import 'package:eveta/utils/cart_service.dart';

class BottomNavBarWidget extends StatefulWidget {
  const BottomNavBarWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
    /// Solo la barra principal (`MyHomePage`) debe usar la key global del carrito
    /// para la animación fly-to-cart. Otra instancia (p. ej. tienda vendedor) rompe el icono al volver.
    this.useCartFlyTargetKey = true,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool useCartFlyTargetKey;

  // Key global para el icono de carrito para la animación
  static final GlobalKey cartKey = GlobalKey();

  /// Altura del contenedor de la barra (indicador + fila + safe area). Útil cuando el `Scaffold` usa [extendBody].
  static double totalHeight(BuildContext context) {
    return 65.0 + MediaQuery.paddingOf(context).bottom;
  }

  @override
  State<BottomNavBarWidget> createState() => _BottomNavBarWidgetState();
}

class _BottomNavBarWidgetState extends State<BottomNavBarWidget>
    with TickerProviderStateMixin {
  late final AnimationController _homeController;

  final List<({IconData icon, String label})> _items = const [
    (icon: Icons.home_outlined, label: 'Inicio'),
    (icon: Icons.grid_view, label: 'Categorías'),
    (icon: Icons.favorite_border, label: 'Favoritos'),
    (icon: Icons.shopping_cart_outlined, label: 'Carrito'),
    (icon: Icons.menu, label: 'Menú'),
  ];

  @override
  void initState() {
    super.initState();
    _homeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
      value: widget.currentIndex == 0 ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant BottomNavBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    final becameSelected = oldWidget.currentIndex != 0 && widget.currentIndex == 0;
    final becameDeselected = oldWidget.currentIndex == 0 && widget.currentIndex != 0;
    if (becameSelected) {
      _homeController.forward();
    } else if (becameDeselected) {
      _homeController.reverse();
    }
  }

  @override
  void dispose() {
    _homeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final indicatorColor =
        Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIconColor = isDark ? Colors.white : Colors.black;
    final unselectedIconColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.72 : 0.55);
    final n = _items.length;
    final width = MediaQuery.sizeOf(context).width;
    final tabW = width / n;
    final lineW = (tabW * 0.48).clamp(28.0, 52.0);
    final rawLeft = tabW * (widget.currentIndex + 0.5) - lineW / 2;
    final left = rawLeft.clamp(6.0, width - lineW - 6.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: evetaShopShellOverlayStyle(scheme),
      child: Container(
      height: 65 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 3,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    left: left,
                    top: 0,
                    width: lineW,
                    height: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: indicatorColor,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: List.generate(_items.length, (index) {
                  final isSelected = widget.currentIndex == index;
                  final isCart = index == 3;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onTap(index),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 6),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: _navIcon(
                                  index: index,
                                  isSelected: isSelected,
                                  primary: primary,
                                  onSurfaceVariant: scheme.onSurfaceVariant,
                                  selectedIconColor: selectedIconColor,
                                  unselectedIconColor: unselectedIconColor,
                                  key: isCart && widget.useCartFlyTargetKey ? BottomNavBarWidget.cartKey : null,
                                ),
                              ),
                              if (isCart)
                                Positioned(
                                  top: -6,
                                  right: -8,
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: CartService.cartCountNotifier,
                                    builder: (context, count, child) {
                                      if (count == 0) return const SizedBox.shrink();
                                      return Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerHighest,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: selectedIconColor, width: 1.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$count',
                                            style: TextStyle(
                                              color: selectedIconColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _navIcon({
    required int index,
    required bool isSelected,
    required Color primary,
    required Color onSurfaceVariant,
    required Color selectedIconColor,
    required Color unselectedIconColor,
    Key? key,
  }) {
    if (index == 0) {
      return AnimatedBuilder(
        animation: _homeController,
        builder: (_, __) {
          return NavbarHomeIcon(
            key: key,
            progress: _homeController.value,
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
            size: 26,
          );
        },
      );
    }
    if (index == 1) {
      return SvgPicture.asset(
        isSelected ? 'assets/images/category_select.svg' : 'assets/images/category.svg',
        width: 25,
        height: 25,
        colorFilter: ColorFilter.mode(
          isSelected ? selectedIconColor : unselectedIconColor,
          BlendMode.srcIn,
        ),
      );
    }
    if (index == 2) {
      return SvgPicture.asset(
        isSelected ? 'assets/images/favorite_selected.svg' : 'assets/images/favorite_outline.svg',
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(
          isSelected ? selectedIconColor : unselectedIconColor,
          BlendMode.srcIn,
        ),
      );
    }
    return Icon(
      _items[index].icon,
      color: isSelected ? selectedIconColor : unselectedIconColor,
      size: 24,
      key: key,
    );
  }
}
