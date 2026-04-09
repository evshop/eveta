import 'package:flutter/material.dart';
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

  @override
  State<BottomNavBarWidget> createState() => _BottomNavBarWidgetState();
}

class _BottomNavBarWidgetState extends State<BottomNavBarWidget> {
  final List<({IconData icon, String label})> _items = const [
    (icon: Icons.home_outlined, label: 'Inicio'),
    (icon: Icons.grid_view, label: 'Categorías'),
    (icon: Icons.favorite_border, label: 'Favoritos'),
    (icon: Icons.shopping_cart_outlined, label: 'Carrito'),
    (icon: Icons.menu, label: 'Menú'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final n = _items.length;
    final width = MediaQuery.sizeOf(context).width;
    final tabW = width / n;
    final lineW = (tabW * 0.48).clamp(28.0, 52.0);
    final rawLeft = tabW * (widget.currentIndex + 0.5) - lineW / 2;
    final left = rawLeft.clamp(6.0, width - lineW - 6.0);

    return Container(
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
                        color: primary,
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
                                child: Icon(
                                  _items[index].icon,
                                  color: isSelected ? primary : scheme.onSurfaceVariant.withValues(alpha: 0.45),
                                  size: 24,
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
                                          border: Border.all(color: primary, width: 1.5),
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
                                              color: primary,
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
                          const SizedBox(height: 4),
                          Text(
                            _items[index].label,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected ? primary : scheme.onSurfaceVariant.withValues(alpha: 0.45),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 6),
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
    );
  }
}
