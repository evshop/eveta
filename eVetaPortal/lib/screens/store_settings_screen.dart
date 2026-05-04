import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'store_location_picker_screen.dart';
import '../services/cloudinary_service.dart';
import '../services/portal_session.dart';
import '../widgets/portal/eveta_portal_image_crop_screen.dart';
import '../widgets/portal/eveta_portal_image_picker_sheet.dart';
import '../widgets/portal/portal_tokens.dart';
import '../widgets/portal/portal_soft_card.dart';
import '../widgets/store_front_preview_header.dart';

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _borderColorCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  String? _logoUrl;
  String? _bannerUrl;
  Uint8List? _logoBytes;
  Uint8List? _bannerBytes;

  String? _email;
  String? _shopId;
  String? _portalProfileId;
  String? _legacyProfileId;
  List<String> _locationPhotoUrls = [];

  Color? _parseHexColor(String? raw) {
    final s = (raw ?? '').trim().replaceAll('#', '');
    if (s.isEmpty) return null;
    final hex = s.length == 6 ? 'FF$s' : s;
    if (hex.length != 8) return null;
    final v = int.tryParse(hex, radix: 16);
    if (v == null) return null;
    return Color(v);
  }

  String _cacheBustImageUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return '$trimmed?v=${DateTime.now().millisecondsSinceEpoch}';
    final qp = Map<String, String>.from(uri.queryParameters)
      ..['v'] = DateTime.now().millisecondsSinceEpoch.toString();
    return uri.replace(queryParameters: qp).toString();
  }

  List<String> _parseLocationPhotos(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .take(3)
          .toList();
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay sesión activa.')),
          );
        }
        return;
      }

      _email = user.email;
      _shopId = user.id;

      // Carga el perfil Portal (con autolink si aplica) y guarda IDs útiles.
      final portal = await PortalSession.currentPortalProfile(forceRefresh: true);
      _portalProfileId = portal?['id']?.toString().trim();
      _legacyProfileId = portal?['legacy_profile_id']?.toString().trim();
      if (_legacyProfileId != null && _legacyProfileId!.isEmpty) {
        _legacyProfileId = null;
      }

      Map<String, dynamic>? row = portal;

      if (!mounted) return;
      if (row == null) {
        setState(() => _loading = false);
        return;
      }

      _nameCtrl.text = row['shop_name']?.toString().trim() ?? '';
      _descCtrl.text = row['shop_description']?.toString().trim() ?? '';
      _borderColorCtrl.text = row['shop_border_color']?.toString().trim() ?? '';
      _addressCtrl.text = row['shop_address']?.toString().trim() ?? '';
      _latCtrl.text = row['shop_lat']?.toString().trim() ?? '';
      _lngCtrl.text = row['shop_lng']?.toString().trim() ?? '';
      _locationPhotoUrls = _parseLocationPhotos(row['shop_location_photos']);
      final legacyAvatar = row['avatar_url']?.toString().trim();
      final logo = row['shop_logo_url']?.toString().trim();
      final banner = row['shop_banner_url']?.toString().trim();
      _logoUrl = (logo == null || logo.isEmpty) ? legacyAvatar : logo;
      _bannerUrl = (banner == null || banner.isEmpty) ? legacyAvatar : banner;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCropUpload({required bool isLogo}) async {
    final files = await EvetaPortalImagePicker.pick(
      context,
      EvetaPortalImagePickerOptions(
        title: isLogo ? 'Imagen del icono' : 'Imagen del banner',
        subtitle: isLogo
            ? 'Luego recortás 1:1 con vista previa.'
            : 'Luego recortás 16:9 con vista previa.',
        allowMultiFromGallery: false,
        maxFiles: 1,
        imageQuality: 88,
        maxWidth: isLogo ? 1600.0 : 2800.0,
      ),
    );
    if (files == null || files.isEmpty || !mounted) return;

    final bytes = await files.first.readAsBytes();
    if (!mounted) return;

    final cropped = await EvetaPortalImageCropScreen.open(
      context,
      bytes,
      initialMode: isLogo ? EvetaCropAspectMode.icon : EvetaCropAspectMode.banner,
      lockToInitialMode: true,
    );
    if (cropped == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final fileName = isLogo ? 'logo.png' : 'banner.png';
      final folder = isLogo
          ? 'eveta/portal_store/logo/${_shopId ?? 'unknown'}'
          : 'eveta/portal_store/banner/${_shopId ?? 'unknown'}';

      final rawUrl = await CloudinaryService.uploadImage(
        bytes: cropped,
        fileName: fileName,
        folder: folder,
      );
      final url = _cacheBustImageUrl(rawUrl);

      if (!mounted) return;
      setState(() {
        if (isLogo) {
          _logoUrl = url;
          _logoBytes = cropped;
        } else {
          _bannerUrl = url;
          _bannerBytes = cropped;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              isLogo ? 'Icono listo. Guardá cambios para publicarlo.' : 'Banner listo. Guardá cambios para publicarlo.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickStoreLocationOnMap() async {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    final initial = (lat != null && lng != null)
        ? LatLng(lat, lng)
        : const LatLng(-17.7833, -63.1821);
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => StoreLocationPickerScreen(initial: initial),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _latCtrl.text = selected.latitude.toStringAsFixed(6);
      _lngCtrl.text = selected.longitude.toStringAsFixed(6);
    });
  }

  Future<void> _pickAndUploadLocationPhotos() async {
    final remaining = 3 - _locationPhotoUrls.length;
    if (remaining <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 3 fotos del lugar.')),
      );
      return;
    }
    final files = await EvetaPortalImagePicker.pick(
      context,
      EvetaPortalImagePickerOptions(
        title: 'Fotos del lugar (máx 3)',
        subtitle: 'Sube frente/interior para facilitar el recojo.',
        allowMultiFromGallery: true,
        maxFiles: remaining,
        imageQuality: 85,
        maxWidth: 2200,
      ),
    );
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      final next = List<String>.from(_locationPhotoUrls);
      for (var i = 0; i < files.length; i++) {
        final bytes = await files[i].readAsBytes();
        final url = await CloudinaryService.uploadImage(
          bytes: bytes,
          fileName: 'store_place_${DateTime.now().microsecondsSinceEpoch}_$i.jpg',
          folder: 'eveta/portal_store/place/${_shopId ?? 'unknown'}',
        );
        next.add(_cacheBustImageUrl(url));
        if (next.length >= 3) break;
      }
      if (!mounted) return;
      setState(() {
        _locationPhotoUrls = next.take(3).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotos cargadas. Guarda cambios para publicar.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron subir fotos: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pon un nombre de tienda.')),
      );
      return;
    }

    double? parseCoord(String text) {
      final t = text.trim();
      if (t.isEmpty) return null;
      return double.tryParse(t);
    }

    final shopLat = parseCoord(_latCtrl.text);
    final shopLng = parseCoord(_lngCtrl.text);
    final hasOneCoord = (shopLat == null) != (shopLng == null);
    if (hasOneCoord) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes completar latitud y longitud, o dejar ambas vacías.')),
      );
      return;
    }
    if (shopLat != null && (shopLat < -90 || shopLat > 90)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latitud inválida. Rango válido: -90 a 90.')),
      );
      return;
    }
    if (shopLng != null && (shopLng < -180 || shopLng > 180)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Longitud inválida. Rango válido: -180 a 180.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final shopBorderColor =
          _borderColorCtrl.text.trim().isEmpty ? null : _borderColorCtrl.text.trim();
      final shopAddress =
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim();

      // Asegura una fila portal vinculada antes de guardar (por si fue creación reciente).
      if (_portalProfileId == null || _portalProfileId!.isEmpty) {
        final portal = await PortalSession.currentPortalProfile(forceRefresh: true);
        _portalProfileId = portal?['id']?.toString().trim();
        _legacyProfileId = portal?['legacy_profile_id']?.toString().trim();
        if (_legacyProfileId != null && _legacyProfileId!.isEmpty) {
          _legacyProfileId = null;
        }
      }
      if (_portalProfileId == null || _portalProfileId!.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se encontró tu perfil Portal. Cierra sesión e inicia de nuevo para crearlo.',
            ),
          ),
        );
        return;
      }

      final portalPayload = <String, dynamic>{
        'shop_name': name,
        'shop_description': _descCtrl.text.trim(),
        'shop_logo_url': _logoUrl,
        'shop_banner_url': _bannerUrl,
        'shop_border_color': shopBorderColor,
        'shop_address': shopAddress,
        'shop_lat': shopLat,
        'shop_lng': shopLng,
        'shop_location_photos': _locationPhotoUrls,
        'is_seller': true,
      };

      List<dynamic> updated;
      try {
        updated = await Supabase.instance.client
            .from('profiles_portal')
            .update(portalPayload)
            .eq('id', _portalProfileId!)
            .select('id');
      } catch (e) {
        final lower = e.toString().toLowerCase();
        if (lower.contains('shop_lat') ||
            lower.contains('shop_lng') ||
            lower.contains('shop_location_photos') ||
            lower.contains('shop_border_color') ||
            lower.contains('shop_address')) {
          final fallback = Map<String, dynamic>.from(portalPayload)
            ..remove('shop_lat')
            ..remove('shop_lng')
            ..remove('shop_location_photos')
            ..remove('shop_border_color')
            ..remove('shop_address');
          updated = await Supabase.instance.client
              .from('profiles_portal')
              .update(fallback)
              .eq('id', _portalProfileId!)
              .select('id');
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      if (updated.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se aplicaron los cambios (permisos). Verifica RLS en profiles_portal (self update por auth_user_id) o ejecuta los scripts 034/051.',
            ),
          ),
        );
        return;
      }

      // Actualiza cache para que `currentPortalProfile()` refleje los nuevos valores.
      PortalSession.invalidateCache();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tienda guardada.')),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().toLowerCase().contains('row-level security') ||
                    e.toString().toLowerCase().contains('rls')
                ? 'Sin permiso para guardar la tienda. Un admin debe habilitar políticas RLS para vendedores en profiles_portal.'
                : 'No se pudo guardar: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showBannerSheet() async {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasBanner = _bannerUrl != null && _bannerUrl!.trim().isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(PortalTokens.radiusXl + 6),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
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
                    const SizedBox(height: 18),
                    Text(
                      'Banner de la tienda',
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Recorte 16:9 con vista previa. Queda arriba en tu vitrina.',
                      style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                    ),
                    const SizedBox(height: 18),
                    PortalSoftCard(
                      padding: EdgeInsets.zero,
                      radius: PortalTokens.radiusLg + 2,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.crop_16_9_outlined, color: scheme.primary, size: 24),
                            ),
                            title: Text('Cambiar banner', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                            subtitle: Text(
                              'Elegí foto y ajustá el encuadre',
                              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                            onTap: () {
                              Navigator.pop(ctx);
                              _pickCropUpload(isLogo: false);
                            },
                          ),
                          if (hasBanner) ...[
                            Divider(height: 1, thickness: 1, color: scheme.outline.withValues(alpha: 0.12)),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: scheme.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.delete_outline_rounded, color: scheme.error, size: 24),
                              ),
                              title: Text(
                                'Quitar banner',
                                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.error),
                              ),
                              subtitle: Text(
                                'Se aplica al pulsar «Guardar cambios»',
                                style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (d) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(PortalTokens.radiusLg + 4),
                                    ),
                                    title: const Text('¿Quitar banner?'),
                                    content: const Text(
                                      'La imagen dejará de mostrarse en la tienda hasta que subas otra.',
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: scheme.error,
                                          foregroundColor: scheme.onError,
                                        ),
                                        onPressed: () => Navigator.pop(d, true),
                                        child: const Text('Quitar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true && mounted) setState(() => _bannerUrl = null);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLogoSheet() async {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasLogo = _logoUrl != null && _logoUrl!.trim().isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(PortalTokens.radiusXl + 6),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
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
                    const SizedBox(height: 18),
                    Text(
                      'Icono de la tienda',
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Recorte 1:1 (cuadrado) con vista previa.',
                      style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                    ),
                    const SizedBox(height: 18),
                    PortalSoftCard(
                      padding: EdgeInsets.zero,
                      radius: PortalTokens.radiusLg + 2,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.crop_square_outlined, color: scheme.primary, size: 24),
                            ),
                            title: Text('Cambiar icono', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                            subtitle: Text(
                              'Elegí foto y ajustá el encuadre',
                              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                            onTap: () {
                              Navigator.pop(ctx);
                              _pickCropUpload(isLogo: true);
                            },
                          ),
                          if (hasLogo) ...[
                            Divider(height: 1, thickness: 1, color: scheme.outline.withValues(alpha: 0.12)),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: scheme.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.delete_outline_rounded, color: scheme.error, size: 24),
                              ),
                              title: Text(
                                'Quitar icono',
                                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.error),
                              ),
                              subtitle: Text(
                                'Se aplica al pulsar «Guardar cambios»',
                                style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (d) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(PortalTokens.radiusLg + 4),
                                    ),
                                    title: const Text('¿Quitar icono?'),
                                    content: const Text(
                                      'Se usará un marcador por defecto en la tienda hasta que subas otro.',
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: scheme.error,
                                          foregroundColor: scheme.onError,
                                        ),
                                        onPressed: () => Navigator.pop(d, true),
                                        child: const Text('Quitar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true && mounted) setState(() => _logoUrl = null);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showNameDescSheet() async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nombre y descripción',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la tienda',
                      ).applyDefaults(Theme.of(ctx).inputDecorationTheme),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        alignLabelWithHint: true,
                      ).applyDefaults(Theme.of(ctx).inputDecorationTheme),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _borderColorCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Color del borde del logo (hex)',
                        hintText: '#09CB6B o vacío para sin color',
                      ).applyDefaults(Theme.of(ctx).inputDecorationTheme),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Dirección de recojo de tienda',
                        hintText: 'Ej: Av. Busch #123, Santa Cruz',
                        alignLabelWithHint: true,
                      ).applyDefaults(Theme.of(ctx).inputDecorationTheme),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: const InputDecoration(
                              labelText: 'Latitud',
                              hintText: '-17.7833',
                            ).applyDefaults(Theme.of(ctx).inputDecorationTheme),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _lngCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: const InputDecoration(
                              labelText: 'Longitud',
                              hintText: '-63.1821',
                            ).applyDefaults(Theme.of(ctx).inputDecorationTheme),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _pickStoreLocationOnMap();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Elegir ubicación en mapa'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Fotos del lugar (máx 3)',
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _locationPhotoUrls.length; i++)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _locationPhotoUrls[i],
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: InkWell(
                                  onTap: () => setState(() => _locationPhotoUrls.removeAt(i)),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(8),
                                        topRight: Radius.circular(10),
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (_locationPhotoUrls.length < 3)
                          InkWell(
                            onTap: _uploading ? null : _pickAndUploadLocationPhotos,
                            child: Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.add_a_photo_outlined, color: scheme.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Listo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _borderColorCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: scheme.primary)));
    }
    final scale = MediaQuery.sizeOf(context).width / 375;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Configuración de tienda'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_uploading) const LinearProgressIndicator(minHeight: 3),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RepaintBoundary(
                    child: StoreFrontPreviewHeader(
                      bannerUrl: _bannerUrl,
                      logoUrl: _logoUrl,
                      bannerBytes: _bannerBytes,
                      logoBytes: _logoBytes,
                      shopName: _nameCtrl.text.trim(),
                      shopDescription: _descCtrl.text.trim(),
                      logoBorderColor: _parseHexColor(_borderColorCtrl.text) ?? scheme.primary,
                      scale: scale,
                      onBannerTap: _uploading ? null : _showBannerSheet,
                      onLogoTap: _uploading ? null : _showLogoSheet,
                      onInfoTap: _showNameDescSheet,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'Toca el banner, el icono o el texto. Banner 16:9 e icono 1:1 con recorte antes de subir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (_email != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _email!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.9)),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FilledButton.icon(
                      onPressed: (_saving || _uploading) ? null : _save,
                      icon: _saving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
