import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:eveta/common_widget/eveta_circular_back_button.dart';
import 'package:eveta/utils/delivery_location_prefs.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({super.key});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  LatLng _currentLatLng = const LatLng(-16.9167, -62.6167); // Centro de San Julián
  String _address = 'Buscando ubicación...';
  bool _isGeocoding = false;
  bool _isLoadingLocation = false;
  final MapController _mapController = MapController();
  
  // Límites permitidos (Bounding Box para San Julián)
  final LatLngBounds _allowedBounds = LatLngBounds(
    const LatLng(-16.95, -62.66), // Suroeste
    const LatLng(-16.88, -62.58), // Noreste
  );

  bool get _isInZone => _allowedBounds.contains(_currentLatLng);

  @override
  void initState() {
    super.initState();
    _checkPermissionAndGetLocation();
    _reverseGeocode(_currentLatLng);
  }

  Future<void> _checkPermissionAndGetLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    _goToCurrentLocation();
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition();
      LatLng userLatLng = LatLng(position.latitude, position.longitude);
      
      _mapController.move(userLatLng, 16.0);
      _reverseGeocode(userLatLng);
    } catch (e) {
      debugPrint('Error obteniendo ubicación: $e');
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    setState(() {
      _isGeocoding = true;
      _currentLatLng = latLng;
    });

    // Si está fuera de la zona, no buscamos dirección detallada para ahorrar API calls
    if (!_isInZone) {
      setState(() {
        _address = 'Ubicación fuera de zona de cobertura';
        _isGeocoding = false;
      });
      return;
    }

    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${latLng.latitude}&lon=${latLng.longitude}');
      final response = await http.get(url, headers: {
        'User-Agent': 'eVetaShopApp/1.0',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] ?? 'Ubicación desconocida';
        
        final parts = displayName.split(',');
        final shortAddress = parts.length > 2 
            ? '${parts[0]}, ${parts[1]}'
            : displayName;

        setState(() {
          _address = shortAddress;
        });
      }
    } catch (e) {
      debugPrint('Error in reverse geocoding: $e');
    } finally {
      setState(() => _isGeocoding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Confirmar Ubicación',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: const EvetaCircularBackButton(
          variant: EvetaCircularBackVariant.onLightBackground,
        ),
        leadingWidth: 56,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLatLng,
              initialZoom: 16.0,
              minZoom: 14.0,
              maxZoom: 18.0,
              onTap: (tapPosition, point) => _reverseGeocode(point),
              cameraConstraint: CameraConstraint.contain(
                bounds: _allowedBounds,
              ),
            ),
            children: [
              // CartoDB Voyager (Limpio y moderno)
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_labels_under/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.eveta.shop',
              ),
              // Capa de resaltado de zona (Línea sutil)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: [
                      _allowedBounds.southWest,
                      LatLng(_allowedBounds.southWest.latitude, _allowedBounds.northEast.longitude),
                      _allowedBounds.northEast,
                      LatLng(_allowedBounds.northEast.latitude, _allowedBounds.southWest.longitude),
                    ],
                    color: Colors.transparent, // Sin relleno
                    borderColor: const Color(0xFF09CB6B).withValues(alpha: 0.5),
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLatLng,
                    width: 60,
                    height: 60,
                    alignment: Alignment.topCenter,
                    child: Icon(
                      Icons.location_on, 
                      size: 40, 
                      color: _isInZone ? const Color(0xFF09CB6B) : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          Positioned(
            right: 16,
            bottom: 240,
            child: FloatingActionButton(
              onPressed: _isLoadingLocation ? null : _goToCurrentLocation,
              backgroundColor: Colors.white,
              mini: true,
              child: _isLoadingLocation 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF09CB6B)))
                : const Icon(Icons.my_location, color: Color(0xFF09CB6B)),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isInZone)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lo sentimos, eVeta aún no llega a esta ubicación. Por ahora solo operamos en San Julián.',
                              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Text(
                    'Dirección de entrega',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: _isInZone ? const Color(0xFF09CB6B) : Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _address,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isInZone ? Colors.black87 : Colors.red,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isGeocoding)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF09CB6B)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isGeocoding || !_isInZone) ? null : () async {
                        await DeliveryLocationPrefs.save(
                          lat: _currentLatLng.latitude,
                          lng: _currentLatLng.longitude,
                          address: _address,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context, {
                          'lat': _currentLatLng.latitude,
                          'lng': _currentLatLng.longitude,
                          'address': _address,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF09CB6B),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Confirmar Ubicación',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
