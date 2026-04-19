import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:eveta/common_widget/eveta_circular_back_button.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/utils/delivery_location_prefs.dart';

/// Flujo guiado: nombre → método (GPS / búsqueda) → mapa → detalles → confirmación.
class LocationOnboardingScreen extends StatefulWidget {
  const LocationOnboardingScreen({super.key});

  @override
  State<LocationOnboardingScreen> createState() => _LocationOnboardingScreenState();
}

class _LocationOnboardingScreenState extends State<LocationOnboardingScreen> {
  static const LatLng _defaultCenter = LatLng(-16.9167, -62.6167);
  static final LatLngBounds _allowedBounds = LatLngBounds(
    const LatLng(-16.95, -62.66),
    const LatLng(-16.88, -62.58),
  );

  /// 0 nombre · 1 método/búsqueda · 2 mapa · 3 detalles · 4 confirmación
  int _step = 0;
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _aptCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  final _mapController = MapController();
  final _miniMapController = MapController();

  LatLng? _pin;
  String _geocodedLine = '';
  bool _geocoding = false;
  bool _gpsLoading = false;
  bool _showSearchField = false;
  List<Map<String, dynamic>> _searchHits = [];
  bool _searchLoading = false;

  bool _inBounds(LatLng p) => _allowedBounds.contains(p);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _referenceCtrl.dispose();
    _aptCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng p) async {
    setState(() => _geocoding = true);
    if (!_inBounds(p)) {
      setState(() {
        _geocodedLine = 'Ubicación fuera de zona de cobertura';
        _geocoding = false;
      });
      return;
    }
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${p.latitude}&lon=${p.longitude}',
      );
      final response = await http.get(url, headers: const {'User-Agent': 'eVetaShopApp/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final dn = data['display_name']?.toString() ?? '';
        final parts = dn.split(',');
        final short = parts.length > 2 ? '${parts[0].trim()}, ${parts[1].trim()}' : dn;
        if (mounted) {
          setState(() => _geocodedLine = short.isEmpty ? 'Ubicación' : short);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _geocodedLine = 'Ubicación');
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  Future<void> _forwardSearch(String q) async {
    final query = q.trim();
    if (query.length < 3) {
      setState(() => _searchHits = []);
      return;
    }
    setState(() => _searchLoading = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=jsonv2&q=${Uri.encodeComponent(query)}&limit=8',
      );
      final response = await http.get(url, headers: const {'User-Agent': 'eVetaShopApp/1.0'});
      if (response.statusCode == 200 && mounted) {
        final list = json.decode(response.body) as List<dynamic>;
        setState(() {
          _searchHits = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searchHits = []);
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  Future<void> _useGps() async {
    setState(() => _gpsLoading = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Activa el permiso de ubicación en ajustes.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      var p = LatLng(pos.latitude, pos.longitude);
      if (!_inBounds(p)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Tu ubicación está fuera del área de reparto.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        p = _defaultCenter;
        _mapController.move(p, 15);
        setState(() {
          _pin = p;
          _step = 2;
        });
      } else {
        setState(() {
          _pin = p;
          _step = 2;
        });
        _mapController.move(p, 16);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _reverseGeocode(p));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo obtener la ubicación: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  void _pickSearchResult(Map<String, dynamic> hit) {
    final lat = double.tryParse(hit['lat']?.toString() ?? '');
    final lon = double.tryParse(hit['lon']?.toString() ?? '');
    if (lat == null || lon == null) return;
    final p = LatLng(lat, lon);
    setState(() {
      _pin = p;
      _step = 2;
      _showSearchField = false;
      _searchHits = [];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(p, 16);
      _reverseGeocode(p);
    });
  }

  Future<void> _persistAndPop() async {
    final pin = _pin;
    if (pin == null) return;
    await DeliveryLocationPrefs.saveDeliveryLocation(
      lat: pin.latitude,
      lng: pin.longitude,
      label: _nameCtrl.text.trim(),
      neighborhood: _neighborhoodCtrl.text.trim(),
      geocodedLine: _geocodedLine.trim().isEmpty ? 'Ubicación' : _geocodedLine.trim(),
      reference: _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
      aptFloor: _aptCtrl.text.trim().isEmpty ? null : _aptCtrl.text.trim(),
      instructions: _instructionsCtrl.text.trim().isEmpty ? null : _instructionsCtrl.text.trim(),
    );
    if (mounted) Navigator.pop(context, true);
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    if (_step == 1) {
      if (_showSearchField) {
        setState(() {
          _showSearchField = false;
          _searchHits = [];
          _searchCtrl.clear();
        });
        return;
      }
      setState(() => _step = 0);
      return;
    }
    if (_step == 2) {
      setState(() {
        _step = 1;
        _showSearchField = false;
      });
      return;
    }
    if (_step == 3) {
      setState(() => _step = 2);
      return;
    }
    if (_step == 4) {
      setState(() => _step = 3);
    }
  }

  String get _title {
    if (_step == 1 && _showSearchField) return 'Buscar dirección';
    return switch (_step) {
      0 => 'Nombre de la ubicación',
      1 => 'Método de ubicación',
      2 => 'Ajusta en el mapa',
      3 => 'Detalles adicionales',
      _ => 'Confirmación',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_step == 2) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _goBack();
        },
        child: Scaffold(
          backgroundColor: scheme.surface,
          body: _stepMap(context),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: EvetaCircularBackButton(
          variant: scheme.brightness == Brightness.dark
              ? EvetaCircularBackVariant.onDarkBackground
              : EvetaCircularBackVariant.onLightBackground,
          onPressed: _goBack,
        ),
        leadingWidth: 56,
        title: Text(_title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: switch (_step) {
        0 => _stepName(context),
        1 => _showSearchField ? _stepSearch(context) : _stepMethod(context),
        3 => _stepDetails(context),
        _ => _stepConfirm(context),
      },
    );
  }

  Widget _stepName(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(EvetaShopDimens.space2xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ponle un nombre para reconocerla después (ej.: Casa, Oficina).',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: EvetaShopDimens.space2xl),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre',
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd)),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                if (_nameCtrl.text.trim().isEmpty) return;
                setState(() => _step = 1);
              },
              style: FilledButton.styleFrom(
                backgroundColor: EvetaShopColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd)),
              ),
              child: const Text('Continuar', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepMethod(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(EvetaShopDimens.space2xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Elige cómo quieres colocar el punto en el mapa.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: EvetaShopDimens.space2xl),
            FilledButton.tonal(
              onPressed: _gpsLoading
                  ? null
                  : () async {
                      await _useGps();
                    },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd)),
              ),
              child: _gpsLoading
                  ? SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.my_location_rounded),
                        SizedBox(width: 10),
                        Text('Usar mi ubicación actual', style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
            const SizedBox(height: EvetaShopDimens.spaceMd),
            OutlinedButton(
              onPressed: () => setState(() => _showSearchField = true),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded),
                  SizedBox(width: 10),
                  Text('Buscar dirección', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepSearch(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceLg),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _forwardSearch,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Escribe calle, barrio o referencia…',
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd)),
                suffixIcon: _searchLoading
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                        ),
                      )
                    : const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(EvetaShopDimens.spaceLg),
              itemCount: _searchHits.length,
              itemBuilder: (context, i) {
                final h = _searchHits[i];
                final label = h['display_name']?.toString() ?? '';
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusSm)),
                  tileColor: scheme.surfaceContainerHigh,
                  title: Text(label, maxLines: 3, overflow: TextOverflow.ellipsis),
                  onTap: () => _pickSearchResult(h),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepMap(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final center = _pin ?? _defaultCenter;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 16,
              minZoom: 14,
              maxZoom: 18,
              cameraConstraint: CameraConstraint.contain(bounds: _allowedBounds),
              onMapEvent: (ev) {
                if (ev is MapEventMoveEnd) {
                  final c = ev.camera.center;
                  setState(() => _pin = c);
                  _reverseGeocode(c);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_labels_under/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.eveta.shop',
              ),
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: [
                      _allowedBounds.southWest,
                      LatLng(_allowedBounds.southWest.latitude, _allowedBounds.northEast.longitude),
                      _allowedBounds.northEast,
                      LatLng(_allowedBounds.northEast.latitude, _allowedBounds.southWest.longitude),
                    ],
                    color: Colors.transparent,
                    borderColor: EvetaShopColors.brand.withValues(alpha: 0.45),
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: EvetaCircularBackButton(
              variant: scheme.brightness == Brightness.dark
                  ? EvetaCircularBackVariant.onDarkBackground
                  : EvetaCircularBackVariant.onLightBackground,
              onPressed: _goBack,
            ),
          ),
        ),
        const IgnorePointer(
          child: Center(
            child: Icon(Icons.location_on_rounded, size: 52, color: EvetaShopColors.brand),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: scheme.surface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(EvetaShopDimens.spaceMd),
                  child: Row(
                    children: [
                      Icon(Icons.place_outlined, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _geocoding ? 'Buscando dirección…' : _geocodedLine,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _inBounds(_pin ?? center) ? scheme.onSurface : scheme.error,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: (_geocoding || !_inBounds(_pin ?? center)) ? null : () => setState(() => _step = 3),
                style: FilledButton.styleFrom(
                  backgroundColor: EvetaShopColors.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd)),
                ),
                child: const Text('Confirmar ubicación', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepDetails(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(EvetaShopDimens.space2xl),
        children: [
          Text('Detalles adicionales', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: EvetaShopDimens.spaceLg),
          TextField(
            controller: _neighborhoodCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Barrio / zona *',
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd)),
            ),
          ),
          const SizedBox(height: EvetaShopDimens.spaceLg),
          TextField(
            controller: _referenceCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Referencias / punto de referencia',
              hintText: 'ej. frente al parque',
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd)),
            ),
          ),
          const SizedBox(height: EvetaShopDimens.spaceLg),
          TextField(
            controller: _aptCtrl,
            decoration: InputDecoration(
              labelText: 'Número de apartamento / piso / interior',
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd)),
            ),
          ),
          const SizedBox(height: EvetaShopDimens.spaceLg),
          TextField(
            controller: _instructionsCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Instrucciones para el repartidor',
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd)),
            ),
          ),
          const SizedBox(height: EvetaShopDimens.space2xl),
          FilledButton(
            onPressed: () {
              if (_neighborhoodCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Indica el barrio o zona.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: scheme.error,
                  ),
                );
                return;
              }
              setState(() => _step = 4);
            },
            style: FilledButton.styleFrom(
              backgroundColor: EvetaShopColors.brand,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd)),
            ),
            child: const Text('Continuar', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _stepConfirm(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pin = _pin ?? _defaultCenter;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(EvetaShopDimens.space2xl),
        children: [
          Text('Resumen', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: EvetaShopDimens.spaceLg),
          Text(_nameCtrl.text.trim(), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            DeliveryLocationPrefs.composeFullAddress(
              label: _nameCtrl.text.trim(),
              neighborhood: _neighborhoodCtrl.text.trim(),
              geocodedLine: _geocodedLine,
              reference: _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
              aptFloor: _aptCtrl.text.trim().isEmpty ? null : _aptCtrl.text.trim(),
              instructions: _instructionsCtrl.text.trim().isEmpty ? null : _instructionsCtrl.text.trim(),
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: EvetaShopDimens.spaceLg),
          ClipRRect(
            borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: FlutterMap(
                mapController: _miniMapController,
                options: MapOptions(
                  initialCenter: pin,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  cameraConstraint: CameraConstraint.contain(bounds: _allowedBounds),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_labels_under/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.eveta.shop',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pin,
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: const Icon(Icons.location_on_rounded, color: EvetaShopColors.brand, size: 40),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: EvetaShopDimens.space2xl),
          FilledButton(
            onPressed: _persistAndPop,
            style: FilledButton.styleFrom(
              backgroundColor: EvetaShopColors.brand,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd)),
            ),
            child: const Text('Guardar ubicación', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
