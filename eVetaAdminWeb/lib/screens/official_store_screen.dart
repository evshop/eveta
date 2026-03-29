import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../widgets/category_image_crop_dialog.dart';

class OfficialStoreScreen extends StatefulWidget {
  const OfficialStoreScreen({super.key});

  @override
  State<OfficialStoreScreen> createState() => _OfficialStoreScreenState();
}

class _OfficialStoreScreenState extends State<OfficialStoreScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  String? _logoUrl;
  String? _bannerUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await AuthService.fetchMyProfile();
      if (!mounted) return;
      _nameCtrl.text = p?['shop_name']?.toString() ?? '';
      _descCtrl.text = p?['shop_description']?.toString() ?? '';
      _logoUrl = p?['shop_logo_url']?.toString();
      _bannerUrl = p?['shop_banner_url']?.toString();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar perfil: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadLogo() async {
    setState(() => _uploading = true);
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      final file = picked?.files.first;
      if (file == null || file.bytes == null) return;
      if (!mounted) return;
      final cropped = await showCategoryImageCropDialog(
        context,
        imageBytes: file.bytes!,
        aspectRatio: kCategoryLogoAspectRatio,
        title: 'Recortar logo oficial',
        hint: 'Formato 1:1 para icono de tienda.',
      );
      if (cropped == null) return;
      _logoUrl = await CloudinaryService.uploadImage(
        bytes: cropped,
        fileName: 'official_logo.png',
        folder: 'eveta/official_store/logo',
      );
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickAndUploadBanner() async {
    setState(() => _uploading = true);
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      final file = picked?.files.first;
      if (file == null || file.bytes == null) return;
      if (!mounted) return;
      final cropped = await showCategoryImageCropDialog(
        context,
        imageBytes: file.bytes!,
        aspectRatio: kCategoryBannerAspectRatio,
        title: 'Recortar banner oficial',
        hint: 'Formato 16:9 para cabecera.',
      );
      if (cropped == null) return;
      _bannerUrl = await CloudinaryService.uploadImage(
        bytes: cropped,
        fileName: 'official_banner.png',
        folder: 'eveta/official_store/banner',
      );
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pon un nombre de tienda oficial.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthService.updateMyStoreProfile(
        shopName: name,
        shopDescription: _descCtrl.text.trim(),
        shopLogoUrl: _logoUrl,
        shopBannerUrl: _bannerUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tienda oficial actualizada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tienda oficial de eVeta',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Define nombre, descripción, icono y banner principal (16:9).',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre visible',
                        hintText: 'Ej. Oficial eVeta',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descCtrl,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Descripción corta',
                        hintText: 'Ej. Tienda oficial con productos seleccionados por eVeta.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_logoUrl != null && _logoUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            _logoUrl!,
                            height: 72,
                            width: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _uploading ? null : _pickAndUploadLogo,
                          icon: const Icon(Icons.upload_outlined),
                          label: Text(_logoUrl == null ? 'Subir icono 1:1' : 'Cambiar icono 1:1'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_bannerUrl != null && _bannerUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            _bannerUrl!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _uploading ? null : _pickAndUploadBanner,
                          icon: const Icon(Icons.photo_outlined),
                          label: Text(_bannerUrl == null ? 'Subir banner 16:9' : 'Cambiar banner 16:9'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _saving || _uploading ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
                        ),
                      ],
                    ),
                    if (_uploading) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

