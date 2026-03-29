import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/cloudinary_service.dart';
import '../services/home_promotion_service.dart';
import '../widgets/category_image_crop_dialog.dart';

/// Carrusel de inicio en eVetaShop: subir banners en 16:9, ordenar y activar/desactivar.
class HomePromotionBannersScreen extends StatefulWidget {
  const HomePromotionBannersScreen({super.key});

  @override
  State<HomePromotionBannersScreen> createState() => _HomePromotionBannersScreenState();
}

class _HomePromotionBannersScreenState extends State<HomePromotionBannersScreen> {
  bool _loading = true;
  bool _uploading = false;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await HomePromotionService.fetchAllForAdmin();
      if (!mounted) return;
      setState(() => _rows = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los banners: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addBanner() async {
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
        title: 'Recortar banner de promoción',
        hint: 'Proporción 16:9, igual que el carrusel de inicio en la app.',
      );
      if (cropped == null) return;
      final url = await CloudinaryService.uploadImage(
        bytes: cropped,
        fileName: 'home_promo.png',
        folder: 'eveta/home_promotions',
      );
      await HomePromotionService.insertBanner(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Banner agregado.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> row, bool value) async {
    final id = row['id']?.toString();
    if (id == null) return;
    try {
      await HomePromotionService.updateActive(id, value);
      if (!mounted) return;
      setState(() {
        final i = _rows.indexWhere((r) => r['id']?.toString() == id);
        if (i >= 0) {
          _rows[i] = {..._rows[i], 'is_active': value};
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }

  Future<void> _move(int index, int delta) async {
    final j = index + delta;
    if (j < 0 || j >= _rows.length) return;
    try {
      await HomePromotionService.swapSortOrder(_rows[index], _rows[j]);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reordenar: $e')),
      );
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar banner'),
        content: const Text('¿Eliminar esta imagen del carrusel de inicio?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await HomePromotionService.deleteBanner(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Banner eliminado.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Estas imágenes son el carrusel de inicio en eVetaShop (solo banners activos). '
          'Si no hay ninguno activo, en la app no se muestra carrusel.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _uploading ? null : _addBanner,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_uploading ? 'Subiendo…' : 'Agregar banner (16:9)'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _rows.isEmpty
              ? Center(
                  child: Text(
                    'No hay banners guardados. En la app de tienda no se mostrará carrusel hasta que agregues al menos uno activo.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    final url = row['image_url']?.toString() ?? '';
                    final active = row['is_active'] == true;
                    final thumbW = 160.0;
                    final thumbH = thumbW * 9 / 16;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: url.isEmpty
                                  ? Container(
                                      width: thumbW,
                                      height: thumbH,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.image_not_supported),
                                    )
                                  : Image.network(
                                      url,
                                      width: thumbW,
                                      height: thumbH,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: thumbW,
                                        height: thumbH,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.broken_image_outlined),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    url,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: const Text('Visible en la app'),
                                    value: active,
                                    onChanged: (v) => _toggleActive(row, v),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Subir',
                                  onPressed: index > 0 ? () => _move(index, -1) : null,
                                  icon: const Icon(Icons.arrow_upward),
                                ),
                                IconButton(
                                  tooltip: 'Bajar',
                                  onPressed: index < _rows.length - 1 ? () => _move(index, 1) : null,
                                  icon: const Icon(Icons.arrow_downward),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  onPressed: () => _confirmDelete(row),
                                  icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
