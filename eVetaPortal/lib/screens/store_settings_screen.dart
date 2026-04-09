import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/cloudinary_service.dart';

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

      // Carpetas por usuario para que no se mezclen tiendas.
      final folder = isLogo
          ? 'eveta/portal_store/logo/${_shopId ?? 'unknown'}'
          : 'eveta/portal_store/banner/${_shopId ?? 'unknown'}';

      final url = await CloudinaryService.uploadImage(
        bytes: bytes,
        fileName: fileName,
        folder: folder,
        // Public_id fijo para reemplazar en vez de duplicar.
        publicId: isLogo ? 'logo_${_shopId ?? 'unknown'}' : 'banner_${_shopId ?? 'unknown'}',
      );

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Widget _buildPreviewBox({
    required String? url,
    required String label,
    required double height,
  }) {
    if (url == null || url.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de tienda'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPreviewBox(
              url: _bannerUrl,
              label: 'Sube banner 16:9',
              height: 170,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 86,
                  height: 86,
                  child: _logoUrl == null || _logoUrl!.isEmpty
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Icon(Icons.store, color: Colors.grey),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            _logoUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu tienda',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (_email != null)
                        Text(
                          _email!,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _uploading ? null : () => _pickAndUpload(isLogo: true),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(_logoUrl == null ? 'Subir logo 1:1' : 'Cambiar logo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _uploading ? null : () => _pickAndUpload(isLogo: false),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(_bannerUrl == null ? 'Subir banner 16:9' : 'Cambiar banner'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre de la tienda',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descripción de la tienda',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: (_saving || _uploading) ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}

