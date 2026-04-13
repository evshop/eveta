import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/cloudinary_service.dart';
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

  Future<void> _pickAndUpload({required bool isLogo}) async {
    setState(() => _uploading = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final fileName = isLogo ? 'logo.png' : 'banner.png';

      final folder = isLogo
          ? 'eveta/portal_store/logo/${_shopId ?? 'unknown'}'
          : 'eveta/portal_store/banner/${_shopId ?? 'unknown'}';

      final url = await CloudinaryService.uploadImage(
        bytes: bytes,
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: scheme.primary),
                  title: const Text('Cambiar imagen del banner'),
                  subtitle: const Text('Desde la galería'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUpload(isLogo: false);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: scheme.error),
                  title: const Text('Quitar banner'),
                  subtitle: const Text('Se borrará al guardar cambios'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('¿Quitar banner?'),
                        content: const Text('La imagen dejará de mostrarse. Pulsa «Guardar cambios» para aplicar.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
                          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Quitar')),
                        ],
                      ),
                    );
                    if (ok == true && mounted) setState(() => _bannerUrl = null);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLogoSheet() async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: scheme.primary),
                  title: const Text('Cambiar icono de tienda'),
                  subtitle: const Text('Desde la galería (recomendado 1:1)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUpload(isLogo: true);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: scheme.error),
                  title: const Text('Quitar icono'),
                  subtitle: const Text('Se borrará al guardar cambios'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('¿Quitar icono?'),
                        content: const Text('Pulsa «Guardar cambios» para aplicar en la tienda.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
                          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Quitar')),
                        ],
                      ),
                    );
                    if (ok == true && mounted) setState(() => _logoUrl = null);
                  },
                ),
              ],
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
                      'Toca el banner, el icono o el texto para editar. Las imágenes se guardan en el dispositivo en caché.',
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
