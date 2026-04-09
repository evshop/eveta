import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:eveta_delivery/services/delivery_api.dart';
import 'delivery_login_screen.dart';

const Color _kGreen = Color(0xFF09CB6B);
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
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const DeliveryLoginScreen()),
      (_) => false,
    );
  }

  Future<void> _accept(String orderId) async {
    try {
      await DeliveryApi.acceptOrder(orderId);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido aceptado'), backgroundColor: _kGreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo aceptar: $e')),
      );
    }
  }

  Future<void> _advance(String orderId, String next) async {
    try {
      await DeliveryApi.advanceStatus(orderId, next);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _kGreen,
          foregroundColor: Colors.white,
          title: const Text('eVeta Delivery'),
          actions: [
            IconButton(onPressed: () => _refresh(), icon: const Icon(Icons.refresh)),
            IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Mapa'),
              Tab(text: 'Mis envíos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMapTab(),
            _buildMineTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTab() {
    if (_loading && _pool.isEmpty && _mine.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _kGreen));
    }

    final markers = <Marker>[];

    for (final o in _pool) {
      final lat = o['dropoff_lat'];
      final lng = o['dropoff_lng'];
      if (lat == null || lng == null) continue;
      final la = lat is num ? lat.toDouble() : double.tryParse(lat.toString());
      final ln = lng is num ? lng.toDouble() : double.tryParse(lng.toString());
      if (la == null || ln == null) continue;
      markers.add(
        Marker(
          width: 44,
          height: 44,
          point: LatLng(la, ln),
          child: GestureDetector(
            onTap: () => _showOfferSheet(o),
            child: const Icon(Icons.place, color: Colors.orange, size: 40),
          ),
        ),
      );
    }

    for (final o in _mine) {
      final lat = o['dropoff_lat'];
      final lng = o['dropoff_lng'];
      if (lat == null || lng == null) continue;
      final la = lat is num ? lat.toDouble() : double.tryParse(lat.toString());
      final ln = lng is num ? lng.toDouble() : double.tryParse(lng.toString());
      if (la == null || ln == null) continue;
      markers.add(
        Marker(
          width: 44,
          height: 44,
          point: LatLng(la, ln),
          child: GestureDetector(
            onTap: () => _showMineSheet(o),
            child: const Icon(Icons.delivery_dining, color: _kGreen, size: 40),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_actionError != null)
          MaterialBanner(
            content: Text(_actionError!),
            actions: [TextButton(onPressed: () => setState(() => _actionError = null), child: const Text('OK'))],
          ),
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _kCenter,
              initialZoom: 13.5,
              minZoom: 10,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.eveta.delivery',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          color: Colors.grey.shade100,
          padding: const EdgeInsets.all(12),
          child: Text(
            '${_pool.length} pedidos disponibles · ${_mine.length} tuyos',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _showOfferSheet(Map<String, dynamic> o) {
    final id = o['id']?.toString() ?? '';
    final addr = o['dropoff_address']?.toString() ?? '';
    final total = o['total']?.toString() ?? '';
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pedido', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(addr, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text('Total Bs $total', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _accept(id);
              },
              style: FilledButton.styleFrom(backgroundColor: _kGreen),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMineSheet(Map<String, dynamic> o) {
    final id = o['id']?.toString() ?? '';
    final st = o['delivery_status']?.toString() ?? '';
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Estado: $st', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (st == 'driver_assigned')
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _advance(id, 'picked_up');
                },
                style: FilledButton.styleFrom(backgroundColor: _kGreen),
                child: const Text('Marcar recogido'),
              ),
            if (st == 'picked_up')
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _advance(id, 'delivered');
                },
                style: FilledButton.styleFrom(backgroundColor: _kGreen),
                child: const Text('Marcar entregado'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMineTab() {
    if (_mine.isEmpty) {
      return Center(
        child: Text(
          'Sin envíos activos',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _mine.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final o = _mine[i];
        final id = o['id']?.toString() ?? '';
        final st = o['delivery_status']?.toString() ?? '';
        final addr = o['dropoff_address']?.toString() ?? '';
        return Card(
          child: ListTile(
            title: Text(
              id.length > 10 ? '${id.substring(0, 8)}…' : id,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('$addr\n$st'),
            isThreeLine: true,
            trailing: st == 'driver_assigned'
                ? TextButton(
                    onPressed: () => _advance(id, 'picked_up'),
                    child: const Text('Recogido'),
                  )
                : st == 'picked_up'
                    ? TextButton(
                        onPressed: () => _advance(id, 'delivered'),
                        child: const Text('Entregado'),
                      )
                    : null,
          ),
        );
      },
    );
  }
}
