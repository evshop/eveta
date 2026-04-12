import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eveta/common_widget/bottom_nav_bar_widget.dart';
import 'package:eveta/common_widget/eveta_blur_confirm_sheet.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/common_widget/eveta_swipe_reveal_delete.dart';
import 'package:eveta/screens/add_location_screen.dart';
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
  const ShoppingCartScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  @override
  void dispose() {
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
      _deliveryAddress = (loc.lat != null && loc.lng != null) ? loc.address : '';
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
      await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const AddLocationScreen()));
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

    setState(() => _checkoutBusy = true);
    try {
      await OrderService.placeOrdersFromCart(
        dropoffLat: loc.lat!,
        dropoffLng: loc.lng!,
        dropoffAddress: loc.address.isEmpty ? 'Entrega' : loc.address,
      );
      if (!mounted) return;
      await _loadCart();
      if (!mounted) return;
      final primary = Theme.of(context).colorScheme.primary;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Pedido registrado! Buscamos repartidor.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
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
                Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
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

  /// Espacio inferior del listado para no quedar tapado por el panel fijo (cupón + resumen + CTA + entrega).
  static const double _checkoutPanelScrollPadding = 380;

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
                      Icon(Icons.place_outlined, color: scheme.primary, size: 22),
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
                          color: selected ? scheme.primary.withValues(alpha: 0.12) : scheme.surfaceContainerHigh,
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
                                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                                    size: 22,
                                  ),
                                  const SizedBox(width: EvetaShopDimens.spaceMd),
                                  Expanded(
                                    child: Text(
                                      loc.address.trim().isEmpty ? 'Ubicación en mapa' : loc.address.trim(),
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
                        await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const AddLocationScreen()));
                        if (mounted) await _loadCart(showLoadingIndicator: false);
                      },
                      icon: Icon(Icons.add_location_alt_outlined, color: scheme.primary, size: 20),
                      label: Text(
                        'Otra ubicación en el mapa',
                        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary),
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

  Widget _buildCheckoutPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shipping = _deliveryFee ?? 0.0;
    final total = (_total + shipping).clamp(0.0, double.infinity);
    final hasDropoff = _distanceKm != null;
    final sheetBg = scheme.surfaceContainerHighest;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(EvetaShopDimens.radiusXl + 8)),
      child: Material(
        color: sheetBg,
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: sheetBg,
            border: Border(
              top: BorderSide(color: scheme.outline.withValues(alpha: isDark ? 0.55 : 0.4)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(EvetaShopDimens.spaceLg, 10, EvetaShopDimens.spaceLg, EvetaShopDimens.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: EvetaShopDimens.spaceMd),
                Text(
                  'Resumen del pedido',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
                ),
                const SizedBox(height: EvetaShopDimens.spaceSm),
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: EvetaShopDimens.spaceMd),
                  child: Divider(height: 1, thickness: 1, color: scheme.outline.withValues(alpha: 0.35)),
                ),
                Row(
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
                ),
                const SizedBox(height: EvetaShopDimens.spaceLg),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _checkoutBusy ? null : _onCheckout,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      disabledBackgroundColor: scheme.surfaceContainerHigh,
                      disabledForegroundColor: scheme.onSurfaceVariant,
                      elevation: 0,
                    ),
                    child: _checkoutBusy
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: scheme.onPrimary),
                          )
                        : Text(
                            'Confirmar pedido',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: scheme.onPrimary),
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
                            padding: EdgeInsets.only(bottom: _checkoutPanelScrollPadding + _bottomBarInset(context)),
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
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(builder: (_) => ProductDetailScreen(productId: item.productId)),
                                        );
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
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _bottomBarInset(context),
                    child: _buildCheckoutPanel(context),
                  ),
              ],
            ),
    );
  }
}
