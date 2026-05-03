import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:eveta_delivery/services/delivery_api.dart';
import 'delivery_login_screen.dart';

const LatLng _kCenter = LatLng(-16.9167, -62.6167);

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
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final pool = await DeliveryApi.fetchPool();
      final mine = await DeliveryApi.fetchMine();
      if (!mounted) return;
      setState(() {
        _pool = pool;
        _mine = mine;
        _loading = false;
        _actionError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _actionError = '$e';
      });
    }
  }

  Future<void> _signOut() async {
    final offlineDemo = (dotenv.env['DELIVERY_OFFLINE_DEMO'] ?? '').toLowerCase() == 'true';
    if (!offlineDemo) {
      await Supabase.instance.client.auth.signOut();
    }
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
                  loading: _loading,
                  pool: _pool,
                  mine: _mine,
                  actionError: _actionError,
                  onDismissError: () => setState(() => _actionError = null),
                  onAccept: _accept,
                  onShowMine: _showMineSheet,
                  onShowOffer: _showOfferSheet,
                );
              case 2:
                return const _ChatsTab();
              case 3:
                return _SettingsTab(onSignOut: _signOut);
              default:
                return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  void _showOfferSheet(Map<String, dynamic> o) {
    final id = o['id']?.toString() ?? '';
    final addr = o['dropoff_address']?.toString() ?? '';
    final total = o['total']?.toString() ?? '';
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _GlassBottomSheet(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pedido',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                addr,
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Total Bs $total',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              CupertinoButton.filled(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _accept(id);
                },
                child: const Text('Aceptar'),
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

  void _showMineSheet(Map<String, dynamic> o) {
    final id = o['id']?.toString() ?? '';
    final st = o['delivery_status']?.toString() ?? '';
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
    required this.loading,
    required this.pool,
    required this.mine,
    required this.actionError,
    required this.onDismissError,
    required this.onAccept,
    required this.onShowOffer,
    required this.onShowMine,
  });

  final bool loading;
  final List<Map<String, dynamic>> pool;
  final List<Map<String, dynamic>> mine;
  final String? actionError;
  final VoidCallback onDismissError;
  final Future<void> Function(String orderId) onAccept;
  final void Function(Map<String, dynamic> o) onShowOffer;
  final void Function(Map<String, dynamic> o) onShowMine;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoTheme.of(context).scaffoldBackgroundColor;
    final hasAccepted = mine.isNotEmpty;

    final markers = <Marker>[];
    final offers = hasAccepted ? const <Map<String, dynamic>>[] : pool;

    for (final o in offers) {
      final lat = o['dropoff_lat'];
      final lng = o['dropoff_lng'];
      final la = lat is num ? lat.toDouble() : double.tryParse(lat?.toString() ?? '');
      final ln = lng is num ? lng.toDouble() : double.tryParse(lng?.toString() ?? '');
      if (la == null || ln == null) continue;
      markers.add(
        Marker(
          width: 54,
          height: 54,
          point: LatLng(la, ln),
          child: GestureDetector(
            onTap: () => onShowOffer(o),
            child: _AvatarMarker(
              accent: CupertinoColors.systemPink,
              icon: CupertinoIcons.cube_box,
            ),
          ),
        ),
      );
    }

    for (final o in mine) {
      final lat = o['dropoff_lat'];
      final lng = o['dropoff_lng'];
      final la = lat is num ? lat.toDouble() : double.tryParse(lat?.toString() ?? '');
      final ln = lng is num ? lng.toDouble() : double.tryParse(lng?.toString() ?? '');
      if (la == null || ln == null) continue;
      markers.add(
        Marker(
          width: 54,
          height: 54,
          point: LatLng(la, ln),
          child: GestureDetector(
            onTap: () => onShowMine(o),
            child: _AvatarMarker(
              accent: CupertinoColors.systemPink,
              icon: CupertinoIcons.bag_fill,
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
                            polylines: hasAccepted
                                ? <Polyline<Object>>[
                                    Polyline<Object>(
                                      points: const [
                                        LatLng(-16.9167, -62.6167),
                                        LatLng(-16.9100, -62.6100),
                                      ],
                                      strokeWidth: 4,
                                      color: CupertinoColors.systemPink.withAlpha(180),
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
                                      ? 'Pedido aceptado · mostrando ruta'
                                      : '${offers.length} pedidos disponibles',
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
              child: _FloatingChatButton(onPressed: () {}),
            ),
        ],
      ),
    );
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

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.onSignOut});

  final Future<void> Function() onSignOut;

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
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
              child: CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile(
                    title: const Text('Cerrar sesión'),
                    leading: const Icon(CupertinoIcons.square_arrow_right),
                    onTap: onSignOut,
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
  const _AvatarMarker({required this.accent, required this.icon});

  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context).withAlpha(210),
            border: Border.all(color: accent.withAlpha(140), width: 1),
          ),
          child: Center(
            child: Icon(icon, color: accent, size: 22),
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
    // Activa Mapbox agregando esto en `assets/env/app.env`:
    // MAPBOX_ACCESS_TOKEN=pk.xxxxx
    // MAPBOX_STYLE_ID=mapbox/streets-v12
    final token = ((dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '').trim().isNotEmpty
            ? (dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '').trim()
            : (dotenv.env['NEXT_PUBLIC_MAPBOX_TOKEN'] ?? '').trim());
    if (token.isEmpty) return null;
    final style = (dotenv.env['MAPBOX_STYLE_ID'] ?? 'mapbox/streets-v12').trim();
    return 'https://api.mapbox.com/styles/v1/$style/tiles/256/{z}/{x}/{y}@2x?access_token=$token';
  }
}
