import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:eveta_delivery/mapbox_env.dart';
import 'package:eveta_delivery/services/delivery_api.dart';
import 'package:eveta_delivery/services/mapbox_directions.dart';
import 'package:eveta_delivery/widgets/delivery_offer_sheet.dart';
import 'delivery_login_screen.dart';

const LatLng _kCenter = LatLng(-16.9167, -62.6167);
const double _kPickupMaxKm = 3.5;

class DeliveryShellScreen extends StatefulWidget {
  const DeliveryShellScreen({super.key});

  @override
  State<DeliveryShellScreen> createState() => _DeliveryShellScreenState();
}

class _DeliveryShellScreenState extends State<DeliveryShellScreen> {
  Timer? _poll;
  List<Map<String, dynamic>> _pool = [];
  List<Map<String, dynamic>> _mine = [];
  bool _loading = true;
  String? _actionError;
  LatLng? _driverPos;
  final MapController _mapController = MapController();
  List<LatLng>? _offerRoutePoints;
  List<LatLng>? _activeOrderRoute;

  int _homePeriod = 0; // 0 = hoy, 1 = mes

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 12), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      await _ensureDriverPosition(silent: silent);
      final pool = await DeliveryApi.fetchPool();
      final mine = await DeliveryApi.fetchMine();

      List<LatLng>? activeRoute;
      if (mine.isNotEmpty) {
        final o = mine.first;
        final pu = _pickupPoint(o);
        final dr = _dropoffPoint(o);
        if (pu != null && dr != null) {
          activeRoute = await MapboxDirections.fetchDrivingRoute(pu, dr);
        }
      }

      if (!mounted) return;
      setState(() {
        _pool = pool;
        _mine = mine;
        _loading = false;
        _actionError = null;
        _activeOrderRoute = activeRoute;
      });

      final fitPts = activeRoute;
      if (fitPts != null && fitPts.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _mapController.fitCamera(
            CameraFit.coordinates(
              coordinates: fitPts,
              padding: const EdgeInsets.fromLTRB(36, 120, 36, 140),
            ),
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _actionError = '$e';
      });
    }
  }

  Future<void> _ensureDriverPosition({bool silent = false}) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!silent) DeliveryApi.debugLog('GPS desactivado');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent) DeliveryApi.debugLog('Permiso de ubicación denegado');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _driverPos = LatLng(pos.latitude, pos.longitude);
      });
    } catch (e) {
      if (!silent) DeliveryApi.debugLog('No se pudo obtener ubicación: $e');
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute<void>(builder: (_) => const DeliveryLoginScreen()),
      (_) => false,
    );
  }

  Future<void> _accept(String orderId) async {
    try {
      await DeliveryApi.acceptOrder(orderId);
      await _refresh();
      if (!mounted) return;
      _showCupertinoNotice('Pedido aceptado');
    } catch (e) {
      if (!mounted) return;
      _showCupertinoNotice('No se pudo aceptar');
    }
  }

  Future<void> _advance(String orderId, String next) async {
    try {
      await DeliveryApi.advanceStatus(orderId, next);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showCupertinoNotice('Error al actualizar');
    }
  }

  void _showCupertinoNotice(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        activeColor: CupertinoColors.systemPink,
        inactiveColor: CupertinoColors.systemGrey,
        backgroundColor:
            CupertinoColors.systemBackground.resolveFrom(context).withAlpha(210),
        border: const Border(
          top: BorderSide(color: CupertinoColors.separator, width: 0.0),
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.map),
            label: 'Maps',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) {
            switch (index) {
              case 0:
                return _HomeTab(
                  period: _homePeriod,
                  onPeriodChanged: (v) => setState(() => _homePeriod = v),
                  onRefresh: _refresh,
                );
              case 1:
                return _MapsTab(
                  mapController: _mapController,
                  routePolyline: _offerRoutePoints ?? _activeOrderRoute,
                  loading: _loading,
                  pool: _pool,
                  mine: _mine,
                  driverPos: _driverPos,
                  actionError: _actionError,
                  onDismissError: () => setState(() => _actionError = null),
                  onAccept: _accept,
                  onShowMine: _showMineSheet,
                  onShowOffer: _showOfferSheet,
                  onOpenChatMine: () => _showChatComingSoon(context),
                );
              case 2:
                return const _ChatsTab();
              case 3:
                return _SettingsTab(
                  onSignOut: _signOut,
                  onOnlineChanged: () => _refresh(silent: true),
                );
              default:
                return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  Future<void> _showOfferSheet(Map<String, dynamic> o) async {
    final id = o['id']?.toString() ?? '';
    final pickup = _pickupPoint(o);
    final drop = _dropoffPoint(o);
    final nearKm = _driverPos == null || pickup == null
        ? null
        : _distanceKm(_driverPos!, pickup);
    final canAccept = nearKm == null || nearKm <= _kPickupMaxKm;

    setState(() => _offerRoutePoints = null);
    _loadOfferRouteForPreview(pickup, drop);

    final storeName = (o['store_name']?.toString().trim().isNotEmpty == true)
        ? o['store_name'].toString().trim()
        : 'Tienda';
    final productLine = _productNamesSummary(o);
    final buyer = (o['buyer_display_name']?.toString().trim().isNotEmpty == true)
        ? o['buyer_display_name'].toString().trim()
        : 'Cliente';
    final fee = o['delivery_fee'];
    final feeStr = fee is num ? fee.toStringAsFixed(0) : (fee?.toString() ?? '—');
    final dist = o['distance_km'];
    final distStr = dist is num
        ? '${dist.toStringAsFixed(1)} km (tienda → entrega)'
        : '—';

    if (!mounted) return;
    await showDeliveryOfferBottomSheet(
      context,
      productLine: productLine,
      storeName: storeName,
      buyerName: buyer,
      deliveryEarningsLabel: 'Bs $feeStr',
      storeToHomeKmLabel: distStr,
      driverToPickupKmLabel: nearKm == null
          ? null
          : 'Hasta el recojo: ${nearKm.toStringAsFixed(2)} km (máx. ${_kPickupMaxKm.toStringAsFixed(1)} km)',
      canAccept: canAccept,
      onAccept: () => _accept(id),
      onChat: () => _showChatComingSoon(context),
    );
    if (mounted) setState(() => _offerRoutePoints = null);
  }

  void _loadOfferRouteForPreview(LatLng? pickup, LatLng? drop) {
    if (pickup == null || drop == null) return;
    MapboxDirections.fetchDrivingRoute(pickup, drop).then((pts) {
      if (!mounted) return;
      setState(() => _offerRoutePoints = pts);
      final fit = pts;
      if (fit == null || fit.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: fit,
            padding: const EdgeInsets.fromLTRB(36, 120, 36, 160),
          ),
        );
      });
    });
  }

  void _showChatComingSoon(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Chat'),
        content: const Text(
          'Pronto podrás conversar con el cliente desde la app de reparto.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _productNamesSummary(Map<String, dynamic> o) {
    final items = o['order_items'];
    if (items is! List || items.isEmpty) return 'Pedido';
    final names = <String>[];
    for (final it in items) {
      if (it is Map) {
        final n = it['name_snapshot']?.toString().trim();
        if (n != null && n.isNotEmpty) names.add(n);
      }
    }
    return names.isEmpty ? 'Pedido' : names.join(' · ');
  }

  LatLng? _pickupPoint(Map<String, dynamic> order) {
    final lat = order['pickup_lat'];
    final lng = order['pickup_lng'];
    final la = lat is num ? lat.toDouble() : double.tryParse(lat?.toString() ?? '');
    final ln = lng is num ? lng.toDouble() : double.tryParse(lng?.toString() ?? '');
    if (la == null || ln == null) return null;
    return LatLng(la, ln);
  }

  LatLng? _dropoffPoint(Map<String, dynamic> order) {
    final lat = order['dropoff_lat'];
    final lng = order['dropoff_lng'];
    final la = lat is num ? lat.toDouble() : double.tryParse(lat?.toString() ?? '');
    final ln = lng is num ? lng.toDouble() : double.tryParse(lng?.toString() ?? '');
    if (la == null || ln == null) return null;
    return LatLng(la, ln);
  }

  double _distanceKm(LatLng a, LatLng b) {
    final d = const Distance();
    return d.as(LengthUnit.Kilometer, a, b);
  }

  List<String> _storePhotos(Map<String, dynamic> o) {
    final raw = o['store_location_photos'];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .take(3)
          .toList();
    }
    return const [];
  }

  void _showMineSheet(Map<String, dynamic> o) {
    final id = o['id']?.toString() ?? '';
    final st = o['delivery_status']?.toString() ?? '';
    final storeName = o['store_name']?.toString().trim();
    final storeAddress = o['store_address']?.toString().trim();
    final storePhotos = _storePhotos(o);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _GlassBottomSheet(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Estado: $st',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (storeName != null && storeName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Tienda: $storeName', style: const TextStyle(fontWeight: FontWeight.w700)),
                if (storeAddress != null && storeAddress.isNotEmpty)
                  Text(
                    storeAddress,
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      fontSize: 12.5,
                    ),
                  ),
              ],
              if (storePhotos.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: storePhotos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        storePhotos[i],
                        width: 72,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (st == 'driver_assigned')
                CupertinoButton.filled(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _advance(id, 'picked_up');
                  },
                  child: const Text('Marcar recogido'),
                ),
              if (st == 'picked_up')
                CupertinoButton.filled(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _advance(id, 'delivered');
                  },
                  child: const Text('Marcar entregado'),
                ),
              const SizedBox(height: 6),
              CupertinoButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.period,
    required this.onPeriodChanged,
    required this.onRefresh,
  });

  final int period;
  final ValueChanged<int> onPeriodChanged;
  final Future<void> Function({bool silent}) onRefresh;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoTheme.of(context).scaffoldBackgroundColor;
    return CupertinoPageScaffold(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Inicio'),
            backgroundColor: bg.withAlpha(210),
            border: const Border(
              bottom: BorderSide(color: CupertinoColors.separator, width: 0.0),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => onRefresh(),
              child: const Icon(CupertinoIcons.refresh, size: 20),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoSlidingSegmentedControl<int>(
                    groupValue: period,
                    backgroundColor: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                    thumbColor: CupertinoColors.systemBackground.resolveFrom(context),
                    onValueChanged: (v) {
                      if (v != null) onPeriodChanged(v);
                    },
                    children: const {
                      0: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Text('Hoy'),
                      ),
                      1: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Text('Mes'),
                      ),
                    },
                  ),
                  const SizedBox(height: 14),
                  _GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            period == 0 ? 'Ganancias de hoy' : 'Ganancias del mes',
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Bs 0.00',
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pedidos completados: 0',
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'En curso',
                                  style: TextStyle(
                                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '0',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Disponibles',
                                  style: TextStyle(
                                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '0',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _MapsTab extends StatelessWidget {
  const _MapsTab({
    required this.mapController,
    required this.routePolyline,
    required this.loading,
    required this.pool,
    required this.mine,
    required this.driverPos,
    required this.actionError,
    required this.onDismissError,
    required this.onAccept,
    required this.onShowOffer,
    required this.onShowMine,
    required this.onOpenChatMine,
  });

  final MapController mapController;
  final List<LatLng>? routePolyline;
  final bool loading;
  final List<Map<String, dynamic>> pool;
  final List<Map<String, dynamic>> mine;
  final LatLng? driverPos;
  final String? actionError;
  final VoidCallback onDismissError;
  final Future<void> Function(String orderId) onAccept;
  final void Function(Map<String, dynamic> o) onShowOffer;
  final void Function(Map<String, dynamic> o) onShowMine;
  final VoidCallback onOpenChatMine;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoTheme.of(context).scaffoldBackgroundColor;
    final hasAccepted = mine.isNotEmpty;

    final markers = <Marker>[];
    final offers = hasAccepted ? const <Map<String, dynamic>>[] : pool;
    final nearOffers = <Map<String, dynamic>>[];
    final farOffers = <Map<String, dynamic>>[];

    for (final o in offers) {
      final pickup = _pickupPoint(o);
      if (pickup == null) continue;
      if (driverPos == null) {
        nearOffers.add(o);
        continue;
      }
      final km = _distanceKm(driverPos!, pickup);
      if (km <= _kPickupMaxKm) {
        nearOffers.add(o);
      } else {
        farOffers.add(o);
      }
    }

    for (final o in nearOffers) {
      final pickup = _pickupPoint(o);
      if (pickup == null) continue;
      markers.add(
        Marker(
          width: 62,
          height: 62,
          point: pickup,
          child: GestureDetector(
            onTap: () => onShowOffer(o),
            child: _AvatarMarker(
              accent: CupertinoColors.systemPink,
              imageUrl: _firstOrderImage(o),
              fallbackIcon: CupertinoIcons.cube_box,
            ),
          ),
        ),
      );
    }

    for (final o in mine) {
      final status = o['delivery_status']?.toString();
      final point = (status == 'picked_up')
          ? _dropoffPoint(o)
          : _pickupPoint(o) ?? _dropoffPoint(o);
      if (point == null) continue;
      markers.add(
        Marker(
          width: 62,
          height: 62,
          point: point,
          child: GestureDetector(
            onTap: () => onShowMine(o),
            child: _AvatarMarker(
              accent: CupertinoColors.systemPink,
              imageUrl: _firstOrderImage(o),
              fallbackIcon: CupertinoIcons.bag_fill,
            ),
          ),
        ),
      );
    }

    final mapUrl = _MapboxConfig.tileUrlTemplateOrNull(context);
    final mapAttribution = mapUrl == null ? const Text('© OpenStreetMap') : const Text('© Mapbox');

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text('Maps'),
                backgroundColor: bg.withAlpha(210),
                border: const Border(
                  bottom: BorderSide(color: CupertinoColors.separator, width: 0.0),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: true,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: _kCenter,
                          initialZoom: 13.5,
                          minZoom: 10,
                          maxZoom: 18,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                mapUrl ?? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.eveta.delivery',
                          ),
                          PolylineLayer(
                            polylines: (routePolyline != null && routePolyline!.length >= 2)
                                ? <Polyline<Object>>[
                                    Polyline<Object>(
                                      points: routePolyline!,
                                      strokeWidth: 5,
                                      color: CupertinoColors.systemPink.withAlpha(200),
                                    ),
                                  ]
                                : const <Polyline<Object>>[],
                          ),
                          MarkerLayer(markers: markers),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: _GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  hasAccepted
                                      ? 'Pedido aceptado · ruta tienda → cliente'
                                      : '${nearOffers.length} pedidos cerca para recojo',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              DefaultTextStyle(
                                style: TextStyle(
                                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                  fontSize: 12,
                                ),
                                child: mapAttribution,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!hasAccepted && (farOffers.isNotEmpty || driverPos == null))
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 70,
                        child: _GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              driverPos == null
                                  ? 'Activa ubicación para filtrar pedidos cercanos al punto de recojo.'
                                  : 'Hay ${farOffers.length} pedidos fuera de ${_kPickupMaxKm.toStringAsFixed(1)} km.',
                              style: TextStyle(
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (loading && pool.isEmpty && mine.isEmpty)
                      const Positioned.fill(
                        child: Center(child: CupertinoActivityIndicator()),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (actionError != null)
            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.of(context).padding.top + 8,
              child: _GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          actionError!,
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        minimumSize: Size.zero,
                        onPressed: onDismissError,
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (hasAccepted)
            Positioned(
              right: 16,
              bottom: 84,
              child: _FloatingChatButton(onPressed: onOpenChatMine),
            ),
        ],
      ),
    );
  }

  String? _firstOrderImage(Map<String, dynamic> o) {
    final items = o['order_items'];
    if (items is List && items.isNotEmpty) {
      for (final item in items) {
        if (item is Map && item['image_url']?.toString().trim().isNotEmpty == true) {
          return item['image_url'].toString().trim();
        }
      }
    }
    return null;
  }

  LatLng? _pickupPoint(Map<String, dynamic> o) {
    final lat = o['pickup_lat'];
    final lng = o['pickup_lng'];
    final la = lat is num ? lat.toDouble() : double.tryParse(lat?.toString() ?? '');
    final ln = lng is num ? lng.toDouble() : double.tryParse(lng?.toString() ?? '');
    if (la == null || ln == null) return null;
    return LatLng(la, ln);
  }

  LatLng? _dropoffPoint(Map<String, dynamic> o) {
    final lat = o['dropoff_lat'];
    final lng = o['dropoff_lng'];
    final la = lat is num ? lat.toDouble() : double.tryParse(lat?.toString() ?? '');
    final ln = lng is num ? lng.toDouble() : double.tryParse(lng?.toString() ?? '');
    if (la == null || ln == null) return null;
    return LatLng(la, ln);
  }

  double _distanceKm(LatLng a, LatLng b) {
    final d = const Distance();
    return d.as(LengthUnit.Kilometer, a, b);
  }
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoTheme.of(context).scaffoldBackgroundColor;
    return CupertinoPageScaffold(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Chats'),
            backgroundColor: bg.withAlpha(210),
            border: const Border(
              bottom: BorderSide(color: CupertinoColors.separator, width: 0.0),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
              child: Column(
                children: [
                  _GlassCard(
                    child: CupertinoListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: CupertinoColors.systemPink,
                        ),
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.person_fill,
                            color: CupertinoColors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      title: const Text('Cliente'),
                      subtitle: const Text('Mensaje de ejemplo…'),
                      trailing: Text(
                        'Ahora',
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {},
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

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({
    required this.onSignOut,
    required this.onOnlineChanged,
  });

  final Future<void> Function() onSignOut;
  final VoidCallback onOnlineChanged;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  bool _onlineBusy = true;
  bool _isOnline = false;
  String? _onlineError;

  @override
  void initState() {
    super.initState();
    _loadOnline();
  }

  Future<void> _loadOnline() async {
    setState(() {
      _onlineBusy = true;
      _onlineError = null;
    });
    try {
      final v = await DeliveryApi.fetchMyOnlineStatus();
      if (!mounted) return;
      setState(() {
        _isOnline = v;
        _onlineBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _onlineBusy = false;
        _onlineError = '$e';
      });
    }
  }

  Future<void> _setOnline(bool value) async {
    setState(() => _onlineBusy = true);
    try {
      await DeliveryApi.setMyOnlineStatus(value);
      if (!mounted) return;
      setState(() {
        _isOnline = value;
        _onlineBusy = false;
      });
      widget.onOnlineChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _onlineBusy = false;
        _onlineError = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoTheme.of(context).scaffoldBackgroundColor;
    return CupertinoPageScaffold(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Settings'),
            backgroundColor: bg.withAlpha(210),
            border: const Border(
              bottom: BorderSide(color: CupertinoColors.separator, width: 0.0),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _onlineBusy ? null : _loadOnline,
              child: const Icon(CupertinoIcons.refresh, size: 20),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Disponibilidad',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_onlineError != null) ...[
                    Text(
                      _onlineError!,
                      style: const TextStyle(
                        color: CupertinoColors.systemRed,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  CupertinoListSection.insetGrouped(
                    children: [
                  CupertinoListTile(
                    title: const Text('En línea para entregas'),
                    subtitle: Text(
                      _isOnline
                          ? 'Visible para nuevos pedidos'
                          : 'No recibirás ofertas en el mapa',
                      maxLines: 2,
                    ),
                    trailing: _onlineBusy
                        ? const CupertinoActivityIndicator()
                        : CupertinoSwitch(
                            value: _isOnline,
                            onChanged: _onlineBusy ? null : (v) => _setOnline(v),
                          ),
                  ),
                  CupertinoListTile(
                    title: const Text('Cerrar sesión'),
                    leading: const Icon(CupertinoIcons.square_arrow_right),
                    onTap: widget.onSignOut,
                  ),
                    ],
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

class _GlassBottomSheet extends StatelessWidget {
  const _GlassBottomSheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context).withAlpha(220),
                border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context).withAlpha(110),
                  width: 0.6,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemBackground.resolveFrom(context).withAlpha(210),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: CupertinoColors.separator.resolveFrom(context).withAlpha(90),
              width: 0.6,
            ),
          ),
          child: DefaultTextStyle(
            style: CupertinoTheme.of(context).textTheme.textStyle,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AvatarMarker extends StatelessWidget {
  const _AvatarMarker({
    required this.accent,
    this.imageUrl,
    required this.fallbackIcon,
  });

  final Color accent;
  final String? imageUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 3),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(70),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: CupertinoColors.systemBackground.resolveFrom(context).withAlpha(220),
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                : Center(
                    child: Icon(fallbackIcon, color: accent, size: 24),
                  ),
          ),
        ),
      ),
    );
  }
}

class _FloatingChatButton extends StatelessWidget {
  const _FloatingChatButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: CupertinoButton(
          padding: const EdgeInsets.all(14),
          color: CupertinoColors.systemPink.withAlpha(220),
          onPressed: onPressed,
          child: const Icon(CupertinoIcons.chat_bubble_2_fill, color: CupertinoColors.white),
        ),
      ),
    );
  }
}

class _MapboxConfig {
  static String? tileUrlTemplateOrNull(BuildContext context) {
    final token = mapboxPublicTokenFromEnv();
    if (token.isEmpty) return null;
    final style = mapboxStyleIdFromEnv();
    return 'https://api.mapbox.com/styles/v1/$style/tiles/256/{z}/{x}/{y}@2x?access_token=$token';
  }
}
