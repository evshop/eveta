import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class StoreLocationPickerScreen extends StatefulWidget {
  const StoreLocationPickerScreen({
    super.key,
    required this.initial,
  });

  final LatLng initial;

  @override
  State<StoreLocationPickerScreen> createState() => _StoreLocationPickerScreenState();
}

class _StoreLocationPickerScreenState extends State<StoreLocationPickerScreen> {
  late final MapController _mapController;
  late LatLng _center;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _center = widget.initial;
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activa el GPS para usar tu ubicación.')),
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado.')),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final next = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _center = next);
      _mapController.move(next, _mapController.camera.zoom.clamp(13, 18));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener ubicación: $e')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación de la tienda'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 15,
                minZoom: 10,
                maxZoom: 19,
                onPositionChanged: (position, _) {
                  final c = position.center;
                  if (c != null) {
                    _center = c;
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.eveta.portal',
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Icon(
                Icons.location_pin,
                color: scheme.primary,
                size: 46,
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  'Mueve el mapa y deja el pin sobre el frente del local.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 104,
            child: FloatingActionButton.small(
              onPressed: _locating ? null : _useMyLocation,
              child: _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop(_center);
              },
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                'Usar esta ubicación (${_center.latitude.toStringAsFixed(6)}, ${_center.longitude.toStringAsFixed(6)})',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
