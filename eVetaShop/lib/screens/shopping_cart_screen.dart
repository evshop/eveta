import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eveta/common_widget/bottom_nav_bar_widget.dart';
import 'package:eveta/common_widget/eveta_blur_confirm_sheet.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/common_widget/eveta_swipe_reveal_delete.dart';
import 'package:eveta/screens/checkout_payment_screen.dart';
import 'package:eveta/screens/location_onboarding_screen.dart';
import 'package:eveta/screens/login_screen.dart';
import 'package:eveta/screens/product_detail_screen.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/eveta_cart_item_tile.dart';
import 'package:eveta/ui/shop/eveta_coupon_field.dart';
import 'package:eveta/ui/shop/eveta_empty_state.dart';
import 'package:eveta/utils/cart_service.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';
import 'package:eveta/utils/delivery_location_prefs.dart';
import 'package:eveta/utils/delivery_pricing.dart';
import 'package:eveta/utils/order_service.dart';

class ShoppingCartScreen extends StatefulWidget {
  const ShoppingCartScreen({super.key, this.onProductTap});

  /// Si viene de [MyHomePage], abre el detalle como overlay y mantiene la barra inferior.
  final ValueChanged<String>? onProductTap;

  @override
  State<ShoppingCartScreen> createState() => _ShoppingCartScreenState();
}

class _ShoppingCartScreenState extends State<ShoppingCartScreen> {
  List<CartItem> _items = [];
  bool _isLoading = true;
  bool _checkoutBusy = false;
  double _total = 0;
  double? _deliveryFee;
  double? _distanceKm;
  String _deliveryAddress = '';
  String? _openSwipeProductId;
  final TextEditingController _promoController = TextEditingController();
  final DraggableScrollableController _checkoutSheetCtrl = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  @override
  void dispose() {
    _checkoutSheetCtrl.dispose();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _loadCart({bool showLoadingIndicator = true}) async {
    if (showLoadingIndicator && mounted) {
      setState(() => _isLoading = true);
    }
    final items = await CartService.getCartItems();
    final total = await CartService.getCartTotal();
    final loc = await DeliveryLocationPrefs.load();
    double? fee;
    double? km;
    if (loc.lat != null && loc.lng != null) {
      final drop = LatLng(loc.lat!, loc.lng!);
      km = DeliveryPricing.haversineKm(DeliveryPricing.defaultPickup, drop);
      fee = DeliveryPricing.feeForDistanceKm(km);
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _total = total;
      _deliveryFee = fee;
      _distanceKm = km;
      _deliveryAddress = (loc.lat != null && loc.lng != null)
          ? (loc.displayLabel.trim().isNotEmpty ? loc.displayLabel.trim() : loc.address.trim())
          : '';
      _isLoading = false;
      if (_openSwipeProductId != null && !items.any((e) => e.productId == _openSwipeProductId)) {
        _openSwipeProductId = null;
      }
    });
  }

  Future<void> _onCheckout() async {
    if (_items.isEmpty) return;

    var user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Inicia sesión para realizar el pedido.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        return;
      }
    }

    var loc = await DeliveryLocationPrefs.load();
    if (loc.lat == null || loc.lng == null) {
      if (!mounted) return;
      await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const LocationOnboardingScreen()));
      await _loadCart();
      loc = await DeliveryLocationPrefs.load();
      if (loc.lat == null || loc.lng == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Confirma una ubicación de entrega en el mapa.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        return;
      }
    }

    final grandTotal = _total + (_deliveryFee ?? 0);
    setState(() => _checkoutBusy = true);
    try {
      final orderIds = await OrderService.placeOrdersFromCart(
        dropoffLat: loc.lat!,
        dropoffLng: loc.lng!,
        dropoffAddress: loc.address.isEmpty ? 'Entrega' : loc.address,
      );
      if (!mounted) return;
      await _loadCart();
      if (!mounted) return;
      if (orderIds.isEmpty) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => CheckoutPaymentScreen(
            orderIds: orderIds,
            amountLabel: 'Bs ${grandTotal.toStringAsFixed(0)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(OrderService.humanizeOrderError(e)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _checkoutBusy = false);
    }
  }

  Future<void> _updateQuantity(String productId, int delta) async {
    final item = _items.firstWhere((i) => i.productId == productId);
    final newQty = item.quantity + delta;
    if (newQty <= 0) {
      await CartService.removeFromCart(productId);
    } else if (newQty <= item.stock) {
      await CartService.updateQuantity(productId, newQty);
    }
    await _loadCart();
  }

  Future<void> _removeItem(String productId) async {
    setState(() => _openSwipeProductId = null);
    await CartService.removeFromCart(productId);
    await _loadCart();
  }

  Future<void> _confirmRemoveItem(CartItem item) async {
    final lineTotal = double.parse(item.price) * item.quantity;
    final scheme = Theme.of(context).colorScheme;
    final ok = await showEvetaBlurConfirmSheet(
      context,
      title: '¿Quitar del carrito?',
      preview: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
            child: SizedBox(
              width: 72,
              height: 72,
              child: item.imageUrl.isNotEmpty
                  ? EvetaCachedImage(
                      imageUrl: item.imageUrl,
                      delivery: EvetaImageDelivery.card,
                      fit: BoxFit.cover,
                      memCacheWidth: 240,
                    )
                  : ColoredBox(color: scheme.surfaceContainerHigh, child: Icon(Icons.image, color: scheme.onSurfaceVariant)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
                ),
                const SizedBox(height: 6),
                Text('Bs ${lineTotal.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary)),
              ],
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      await _removeItem(item.productId);
    } else {
      _onSwipeClosed(item.productId);
    }
  }

  void _onSwipeOpened(String productId) {
    setState(() => _openSwipeProductId = productId);
  }

  void _onSwipeClosed(String productId) {
    if (_openSwipeProductId == productId) {
      setState(() => _openSwipeProductId = null);
    }
  }

  void _applyPromo() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _promoController.text.trim().isEmpty ? 'Escribe un código' : 'Cupones próximamente',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  /// Altura máxima del panel (~ mitad de pantalla) + barra inferior: padding del listado del carrito.
  double _cartListBottomPadding(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return (h * 0.62).clamp(360.0, 720.0) + _bottomBarInset(context);
  }

  /// [MyHomePage] usa `extendBody: true`; el cuerpo llega detrás de la barra — inset igual a [BottomNavBarWidget].
  double _bottomBarInset(BuildContext context) {
    return BottomNavBarWidget.totalHeight(context);
  }

  Future<void> _openDeliveryLocation() async {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final saved = await DeliveryLocationPrefs.loadSaved();
    final activeId = await DeliveryLocationPrefs.loadActiveId();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(sheetContext).top + 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(EvetaShopDimens.radiusXl + 8)),
              border: Border(top: BorderSide(color: scheme.outline.withValues(alpha: 0.35))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(EvetaShopDimens.spaceLg, EvetaShopDimens.spaceLg, EvetaShopDimens.spaceLg, 8),
                  child: Row(
                    children: [
                      Icon(Icons.place_outlined, color: scheme.onSurface, size: 22),
                      const SizedBox(width: EvetaShopDimens.spaceSm),
                      Expanded(
                        child: Text(
                          'Ubicaciones guardadas',
                          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                if (saved.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(EvetaShopDimens.spaceLg, 0, EvetaShopDimens.spaceLg, EvetaShopDimens.spaceMd),
                    child: Text(
                      'Cuando confirmes una dirección en el mapa, quedará aquí para elegirla más rápido.',
                      style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                if (saved.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.42,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceLg),
                      physics: const BouncingScrollPhysics(),
                      itemCount: saved.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final loc = saved[i];
                        final selected = loc.id == activeId;
                        return Material(
                          color: selected ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await DeliveryLocationPrefs.selectSaved(loc.id);
                              if (mounted) await _loadCart(showLoadingIndicator: false);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceMd, vertical: EvetaShopDimens.spaceMd),
                              child: Row(
                                children: [
                                  Icon(
                                    selected ? Icons.check_circle_rounded : Icons.place_outlined,
                                    color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                                    size: 22,
                                  ),
                                  const SizedBox(width: EvetaShopDimens.spaceMd),
                                  Expanded(
                                    child: Text(
                                      loc.displayTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(EvetaShopDimens.spaceLg),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        if (!mounted) return;
                        await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const LocationOnboardingScreen()));
                        if (mounted) await _loadCart(showLoadingIndicator: false);
                      },
                      icon: Icon(Icons.add_location_alt_outlined, color: scheme.onSurface, size: 20),
                      label: Text(
                        'Agregar otra ubicación',
                        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragHandle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRow(BuildContext context, double total) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Total',
          style: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        Text(
          'Bs ${total.toStringAsFixed(0)}',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: scheme.primary,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shipping = _deliveryFee ?? 0.0;
    final total = (_total + shipping).clamp(0.0, double.infinity);
    final hasDropoff = _distanceKm != null;
    final sheetBg = scheme.surfaceContainerHighest;

    final topR = const BorderRadius.vertical(top: Radius.circular(28));
    final navInset = _bottomBarInset(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    const confirmH = 56.0;
    final confirmBottomInset = navInset + 3.0;
    final contentBottomPad = confirmBottomInset + confirmH + safeBottom + 10;
    final dynamicMaxChildSize = ((screenH - (confirmBottomInset + confirmH + 118.0)) / screenH).clamp(0.50, 0.66);

    return DraggableScrollableSheet(
      controller: _checkoutSheetCtrl,
      initialChildSize: dynamicMaxChildSize,
      minChildSize: 0.34,
      maxChildSize: dynamicMaxChildSize,
      snap: true,
      snapSizes: [dynamicMaxChildSize],
      snapAnimationDuration: const Duration(milliseconds: 260),
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: topR,
          child: Material(
            color: sheetBg,
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.34 : 0.12),
            shape: RoundedRectangleBorder(borderRadius: topR),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDragHandle(context),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      EvetaShopDimens.spaceLg,
                      4,
                      EvetaShopDimens.spaceLg,
                      contentBottomPad + EvetaShopDimens.spaceLg,
                    ),
                    children: [
                      Text(
                        'Resumen del pedido',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: EvetaShopDimens.spaceMd),
                      Material(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _openDeliveryLocation,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceMd, vertical: EvetaShopDimens.spaceMd),
                            child: Row(
                              children: [
                                Icon(Icons.place_outlined, size: 22, color: hasDropoff ? scheme.primary : scheme.onSurfaceVariant),
                                const SizedBox(width: EvetaShopDimens.spaceMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hasDropoff ? 'Entrega' : 'Ubicación de entrega',
                                        style: tt.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        hasDropoff
                                            ? (_deliveryAddress.trim().isEmpty ? 'Punto en el mapa' : _deliveryAddress.trim())
                                            : 'Toca para elegir en el mapa',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: tt.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: hasDropoff ? scheme.onSurface : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 22),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: EvetaShopDimens.spaceLg),
                      EvetaCouponField(
                        controller: _promoController,
                        onApply: _applyPromo,
                      ),
                      const SizedBox(height: EvetaShopDimens.spaceLg),
                      _summaryRow(context, 'Subtotal', 'Bs ${_total.toStringAsFixed(0)}'),
                      const SizedBox(height: EvetaShopDimens.spaceSm + 2),
                      _summaryRow(
                        context,
                        hasDropoff ? 'Envío (~${_distanceKm!.toStringAsFixed(1)} km)' : 'Envío',
                        'Bs ${shipping.toStringAsFixed(0)}',
                      ),
                      const SizedBox(height: EvetaShopDimens.spaceSm + 2),
                      _summaryRow(context, 'Descuento', '—', valueMuted: true),
                      SizedBox(height: EvetaShopDimens.spaceLg + 4),
                      Divider(height: 1, thickness: 1, color: scheme.outline.withValues(alpha: 0.35)),
                      const SizedBox(height: EvetaShopDimens.spaceMd),
                      _buildTotalRow(context, total),
                      const SizedBox(height: EvetaShopDimens.spaceMd),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value, {bool valueMuted = false}) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final valueStyle = tt.bodyLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: valueMuted ? scheme.onSurfaceVariant : scheme.onSurface,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: EvetaShopDimens.spaceMd),
        Text(value, style: valueStyle),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final w = MediaQuery.sizeOf(context).width;

    return Scaffold(
      extendBody: true,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text('Carrito', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : Stack(
              children: [
                Positioned.fill(
                  child: RefreshIndicator(
                    color: scheme.primary,
                    onRefresh: () => _loadCart(showLoadingIndicator: false),
                    child: _items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
                              EvetaEmptyState(
                                icon: Icons.shopping_bag_outlined,
                                title: 'Tu carrito está vacío',
                                subtitle: 'Explora el inicio y agrega productos con un toque',
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: EdgeInsets.only(bottom: _cartListBottomPadding(context)),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final lineTotal = double.parse(item.price) * item.quantity;
                              final isOpen = _openSwipeProductId == item.productId;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  EvetaSwipeRevealDelete(
                                    key: ValueKey(item.productId),
                                    screenWidth: w,
                                    isOpen: isOpen,
                                    onOpen: () => _onSwipeOpened(item.productId),
                                    onClose: () => _onSwipeClosed(item.productId),
                                    onDelete: () => _confirmRemoveItem(item),
                                    child: EvetaCartItemTile(
                                      item: item,
                                      lineTotal: lineTotal,
                                      onProductTap: () {
                                        if (widget.onProductTap != null) {
                                          widget.onProductTap!(item.productId);
                                        } else {
                                          Navigator.push<void>(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) => ProductDetailScreen(productId: item.productId),
                                            ),
                                          );
                                        }
                                      },
                                      onDecrement: item.quantity > 1 ? () => _updateQuantity(item.productId, -1) : null,
                                      onIncrement: item.quantity < item.stock ? () => _updateQuantity(item.productId, 1) : null,
                                      onDeleteTap: () => _confirmRemoveItem(item),
                                    ),
                                  ),
                                  Divider(height: 1, indent: 16, endIndent: 16, color: scheme.outlineVariant),
                                ],
                              );
                            },
                          ),
                  ),
                ),
                if (_items.isNotEmpty)
                  Positioned.fill(
                    child: _buildCheckoutPanel(context),
                  ),
                if (_items.isNotEmpty)
                  Positioned(
                    left: EvetaShopDimens.spaceLg,
                    right: EvetaShopDimens.spaceLg,
                    bottom: (_bottomBarInset(context) - 4).clamp(0.0, 9999.0),
                    child: SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: _checkoutBusy ? null : _onCheckout,
                        style: FilledButton.styleFrom(
                          backgroundColor: EvetaShopColors.brand,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: scheme.surfaceContainerHigh,
                          disabledForegroundColor: scheme.onSurfaceVariant,
                          elevation: 8,
                          shape: const StadiumBorder(),
                        ),
                        child: _checkoutBusy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Confirmar pedido',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Colors.white,
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
