import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/cloudinary_service.dart';
import '../widgets/portal/eveta_portal_image_crop_screen.dart';
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

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  String? _logoUrl;
  String? _bannerUrl;

  String? _email;
  String? _shopId;

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

      final row = await Supabase.instance.client
          .from('profiles')
          .select(
            'id, shop_name, shop_description, shop_logo_url, shop_banner_url',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      if (row == null) {
        setState(() => _loading = false);
        return;
      }

      _nameCtrl.text = row['shop_name']?.toString().trim() ?? '';
      _descCtrl.text = row['shop_description']?.toString().trim() ?? '';
      _logoUrl = row['shop_logo_url']?.toString();
      _bannerUrl = row['shop_banner_url']?.toString();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<ImageSource?> _showStoreMediaSourceSheet({required bool isLogo}) async {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = isLogo ? 'Origen del icono' : 'Origen del banner';
    final subtitle = isLogo
        ? 'Después recortás a 1:1 con vista previa.'
        : 'Después recortás a 16:9 con vista previa.';

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
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
                      title,
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                    ),
                    const SizedBox(height: 18),
                    PortalSoftCard(
                      padding: EdgeInsets.zero,
                      radius: PortalTokens.radiusLg + 2,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.photo_library_rounded, color: scheme.primary, size: 24),
                            ),
                            title: Text('Galería', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                            subtitle: Text(
                              'Elegir una foto que ya tenés',
                              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                            onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
                          ),
                          Divider(height: 1, thickness: 1, color: scheme.outline.withValues(alpha: 0.12)),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: scheme.secondary.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.photo_camera_rounded, color: scheme.secondary, size: 24),
                            ),
                            title: Text('Cámara', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                            subtitle: Text(
                              'Sacar una foto ahora',
                              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                            onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
                          ),
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

  Future<void> _pickCropUpload({required bool isLogo}) async {
    final source = await _showStoreMediaSourceSheet(isLogo: isLogo);
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: isLogo ? 1600 : 2800,
        requestFullMetadata: false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'No se pudo abrir la cámara. Revisá permisos en ajustes del dispositivo.'
                : 'No se pudo abrir la galería: $e',
          ),
        ),
      );
      return;
    }
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
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

      final url = await CloudinaryService.uploadImage(
        bytes: cropped,
        fileName: fileName,
        folder: folder,
        publicId: isLogo ? 'logo_${_shopId ?? 'unknown'}' : 'banner_${_shopId ?? 'unknown'}',
      );

      if (!mounted) return;
      setState(() {
        if (isLogo) {
          _logoUrl = url;
        } else {
          _bannerUrl = url;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir: $e')),
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

    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('profiles').update({
        'shop_name': name,
        'shop_description': _descCtrl.text.trim(),
        'shop_logo_url': _logoUrl,
        'shop_banner_url': _bannerUrl,
        'is_seller': true,
      }).eq('id', user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tienda guardada.')),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
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
                      shopName: _nameCtrl.text.trim(),
                      shopDescription: _descCtrl.text.trim(),
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
