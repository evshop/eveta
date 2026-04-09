import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// Altura barra inferior [MyHomePage] + safe area (el checkout queda pegado encima).
  double _mainTabBarReserve(BuildContext context) {
    return 65.0 + MediaQuery.paddingOf(context).bottom;
  }

  Widget _buildCheckoutPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final shipping = _deliveryFee ?? 0.0;
    final total = (_total + shipping).clamp(0.0, double.infinity);

    return Material(
      color: scheme.surfaceBright,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.14),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(EvetaShopDimens.radiusXl + 4)),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceBright,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(EvetaShopDimens.radiusXl + 4)),
          border: Border(
            top: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
            left: BorderSide(color: scheme.outline.withValues(alpha: 0.28)),
            right: BorderSide(color: scheme.outline.withValues(alpha: 0.28)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EvetaCouponField(
                controller: _promoController,
                onApply: _applyPromo,
              ),
              const SizedBox(height: 18),
              _summaryRow(context, 'Subtotal', 'Bs ${_total.toStringAsFixed(0)}'),
              const SizedBox(height: 10),
              _summaryRow(
                context,
                _distanceKm != null ? 'Envío (~${_distanceKm!.toStringAsFixed(1)} km)' : 'Envío',
                'Bs ${shipping.toStringAsFixed(0)}',
              ),
              const SizedBox(height: 10),
              _summaryRow(context, 'Descuento', 'Bs 0'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: scheme.outlineVariant),
              ),
              Row(
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
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _checkoutBusy ? null : _onCheckout,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    disabledBackgroundColor: scheme.surfaceContainerHigh,
                    disabledForegroundColor: scheme.onSurfaceVariant,
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
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
        Text(value, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomReserve = _mainTabBarReserve(context);
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
                            padding: EdgeInsets.only(bottom: 310 + bottomReserve),
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
                    bottom: bottomReserve,
                    child: _buildCheckoutPanel(context),
                  ),
              ],
            ),
    );
  }
}
