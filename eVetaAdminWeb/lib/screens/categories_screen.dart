import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/cloudinary_service.dart';
import '../services/products_service.dart';
import '../theme/admin_theme.dart';
import '../widgets/category_image_crop_dialog.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final data = await ProductsService.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openCategoryDialog({Map<String, dynamic>? existing}) async {
    final parentContext = context;
    final controller = TextEditingController(text: existing?['name']?.toString() ?? '');
    String? logoUrl = _categoryImageUrl(existing?['icon']);
    String? bannerUrl = _categoryImageUrl(existing?['image_url']);
    bool uploading = false;
    var parentId = existing?['parent_id']?.toString();
    var specTemplateEnabled = existing?['spec_template_enabled'] == true;
    final specGroupController = TextEditingController(
      text: existing?['spec_group_title']?.toString() ?? '',
    );
    final specLabelControllers = <TextEditingController>[];
    final rawSpec = existing?['spec_field_labels'];
    if (rawSpec is List) {
      for (final e in rawSpec) {
        specLabelControllers.add(TextEditingController(text: e.toString()));
      }
    }
    if (specTemplateEnabled && specLabelControllers.isEmpty) {
      specLabelControllers.add(TextEditingController());
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Nueva categoría' : 'Editar categoría'),
          content: SizedBox(
            width: 520,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de categoría',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: parentId,
                  decoration: const InputDecoration(
                    labelText: 'Dentro de (subcategoría)',
                    helperText: 'Vacío = categoría principal (ej. Tecnología). Con padre = ej. Celulares dentro de Tecnología.',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Ninguna — es categoría principal'),
                    ),
                    ..._categories
                        .where(
                          (c) =>
                              c['parent_id'] == null &&
                              c['id'].toString() != existing?['id']?.toString(),
                        )
                        .map(
                          (c) => DropdownMenuItem<String?>(
                            value: c['id'].toString(),
                            child: Text(c['name'].toString()),
                          ),
                        ),
                  ],
                  onChanged: (v) => setDialogState(() {
                    parentId = v;
                    if (v == null) specTemplateEnabled = false;
                  }),
                ),
                if (parentId != null) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: specTemplateEnabled,
                    onChanged: (v) => setDialogState(() {
                      specTemplateEnabled = v;
                      if (v && specLabelControllers.isEmpty) {
                        specLabelControllers.add(TextEditingController());
                      }
                    }),
                    title: const Text('Campos extra en productos'),
                    subtitle: const Text(
                      'Solo en subcategorías: tú pones el nombre del bloque (ej. Especificaciones) y cada apartado con +.',
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (specTemplateEnabled) ...[
                    TextField(
                      controller: specGroupController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del bloque',
                        hintText: 'Ej. Especificaciones, Ficha técnica, Detalles…',
                        border: OutlineInputBorder(),
                        helperText: 'Así se titula la sección en la tienda y en el admin.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Apartados (lo que verás al lado del texto al cargar el producto)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Orden: usa las flechas para subir o bajar cada apartado.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(specLabelControllers.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: specLabelControllers[i],
                                decoration: InputDecoration(
                                  labelText: 'Apartado ${i + 1}',
                                  hintText: 'Ej. Pantalla, Procesador…',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Subir',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 32,
                                  ),
                                  onPressed: i == 0
                                      ? null
                                      : () {
                                          setDialogState(() {
                                            final t = specLabelControllers.removeAt(i);
                                            specLabelControllers.insert(i - 1, t);
                                          });
                                        },
                                  icon: Icon(
                                    Icons.arrow_upward,
                                    size: 20,
                                    color: i == 0 ? Colors.grey : null,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Bajar',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 32,
                                  ),
                                  onPressed: i >= specLabelControllers.length - 1
                                      ? null
                                      : () {
                                          setDialogState(() {
                                            final t = specLabelControllers.removeAt(i);
                                            specLabelControllers.insert(i + 1, t);
                                          });
                                        },
                                  icon: Icon(
                                    Icons.arrow_downward,
                                    size: 20,
                                    color: i >= specLabelControllers.length - 1
                                        ? Colors.grey
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              tooltip: 'Quitar',
                              onPressed: () {
                                setDialogState(() {
                                  final c = specLabelControllers.removeAt(i);
                                  c.dispose();
                                });
                              },
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            specLabelControllers.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar apartado'),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                if (logoUrl != null && logoUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        logoUrl!,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () async {
                          setDialogState(() => uploading = true);
                          try {
                            final picked = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            final file = picked?.files.first;
                            if (file == null || file.bytes == null) return;
                            if (!parentContext.mounted) return;
                            final cropped = await showCategoryImageCropDialog(
                              parentContext,
                              imageBytes: file.bytes!,
                              aspectRatio: kCategoryLogoAspectRatio,
                              title: 'Recortar logo',
                              hint:
                                  'Proporción cuadrada 1:1. Arrastra y haz zoom para encuadrar.',
                            );
                            if (cropped == null) return;
                            if (!parentContext.mounted) return;
                            final uploaded = await CloudinaryService.uploadImage(
                              bytes: cropped,
                              fileName: 'category_logo.png',
                              folder: 'eveta/categories/logo',
                            );
                            logoUrl = _cacheBustImageUrl(uploaded);
                            setDialogState(() {});
                          } finally {
                            setDialogState(() => uploading = false);
                          }
                        },
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(
                    logoUrl == null
                        ? 'Subir logo (1:1, recorte)'
                        : 'Cambiar logo (1:1)',
                  ),
                ),
                const SizedBox(height: 8),
                if (bannerUrl != null && bannerUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        bannerUrl!,
                        height: 70,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () async {
                          setDialogState(() => uploading = true);
                          try {
                            final picked = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            final file = picked?.files.first;
                            if (file == null || file.bytes == null) return;
                            if (!parentContext.mounted) return;
                            final cropped = await showCategoryImageCropDialog(
                              parentContext,
                              imageBytes: file.bytes!,
                              aspectRatio: kCategoryBannerAspectRatio,
                              title: 'Recortar banner',
                              hint:
                                  'Formato panorámico 16:9. Arrastra y haz zoom para encuadrar.',
                            );
                            if (cropped == null) return;
                            if (!parentContext.mounted) return;
                            final uploaded = await CloudinaryService.uploadImage(
                              bytes: cropped,
                              fileName: 'category_banner.png',
                              folder: 'eveta/categories/banner',
                            );
                            bannerUrl = _cacheBustImageUrl(uploaded);
                            setDialogState(() {});
                          } finally {
                            setDialogState(() => uploading = false);
                          }
                        },
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(
                    bannerUrl == null
                        ? 'Subir banner (16:9, recorte)'
                        : 'Cambiar banner (16:9)',
                  ),
                ),
                if (uploading) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
              ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: uploading ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: uploading
                  ? null
                  : () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;
                      final isSub = parentId != null;
                      final effectiveSpec = isSub && specTemplateEnabled;
                      final specLabels = specLabelControllers
                          .map((c) => c.text.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                      final labelsToSave = effectiveSpec ? specLabels : <String>[];
                      final groupRaw = specGroupController.text.trim();
                      if (existing == null) {
                        await ProductsService.createCategory(
                          name,
                          parentId: parentId,
                          logoUrl: logoUrl,
                          bannerUrl: bannerUrl,
                          specTemplateEnabled: effectiveSpec,
                          specFieldLabels: labelsToSave,
                          specGroupTitle: effectiveSpec &&
                                  labelsToSave.isNotEmpty &&
                                  groupRaw.isNotEmpty
                              ? groupRaw
                              : null,
                        );
                      } else {
                        await ProductsService.updateCategory(
                          existing['id'].toString(),
                          name: name,
                          parentId: parentId,
                          logoUrl: logoUrl,
                          bannerUrl: bannerUrl,
                          specTemplateEnabled: effectiveSpec,
                          specFieldLabels: labelsToSave,
                          specGroupTitle: effectiveSpec &&
                                  labelsToSave.isNotEmpty &&
                                  groupRaw.isNotEmpty
                              ? groupRaw
                              : null,
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    specGroupController.dispose();
    for (final c in specLabelControllers) {
      c.dispose();
    }
    if (saved == true) {
      await _refresh();
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${category['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ProductsService.deleteCategory(category['id'].toString());
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo eliminar. Puede tener productos asociados.'),
        ),
      );
    }
  }

  Future<void> _clearSeedCategories() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar categorías'),
        content: const Text(
          'Esto intentará borrar todas las categorías actuales. '
          'Si alguna tiene productos asociados, la base de datos bloqueará el borrado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar todo', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ProductsService.clearAllCategories();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categorías borradas.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudieron borrar todas. Borra primero productos asociados.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminTokens.radiusSm)),
              ),
              onPressed: () => _openCategoryDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva categoría'),
            ),
            OutlinedButton.icon(
              onPressed: _clearSeedCategories,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Borrar todas'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category_outlined, size: 48, color: scheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(
                        'No hay categorías registradas.',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final cross = w > 1280
                        ? 4
                        : w > 900
                            ? 3
                            : w > 520
                                ? 2
                                : 1;
                    // Mayor ratio = tarjetas más bajas (más compactas).
                    final ratio = w > 1000 ? 1.72 : (w > 560 ? 1.48 : 1.28);
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: ratio,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final pid = cat['parent_id']?.toString();
                        Map<String, dynamic>? parent;
                        if (pid != null) {
                          for (final x in _categories) {
                            if (x['id'].toString() == pid) {
                              parent = x;
                              break;
                            }
                          }
                        }
                        final specOn = cat['spec_template_enabled'] == true;
                        final rawL = cat['spec_field_labels'];
                        var specHint = '';
                        if (specOn && rawL is List && rawL.isNotEmpty) {
                          final names = rawL.map((e) => e.toString()).take(2).join(', ');
                          final gt = cat['spec_group_title']?.toString().trim();
                          final block = (gt != null && gt.isNotEmpty) ? gt : 'Campos extra';
                          specHint = '$block: $names${rawL.length > 2 ? '…' : ''}';
                        }
                        final slugLine = 'slug: ${cat['slug']}';
                        final treeLine = parent != null
                            ? '${parent['name']} › ${cat['name']}'
                            : 'Categoría principal';
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openCategoryDialog(existing: cat),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _CategoryPreview(
                                        logoUrl: cat['icon']?.toString(),
                                        bannerUrl: cat['image_url']?.toString(),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'Editar',
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _openCategoryDialog(existing: cat),
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                      ),
                                      IconButton(
                                        tooltip: 'Eliminar',
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _deleteCategory(cat),
                                        icon: Icon(Icons.delete_outline, color: scheme.error, size: 18),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    cat['name'].toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    slugLine,
                                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    treeLine,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                                  ),
                                  if (specHint.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: scheme.primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        specHint,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

String? _categoryImageUrl(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty || s == 'null') return null;
  return s;
}

bool _looksLikeAssetPath(String? s) {
  if (s == null) return false;
  final v = s.trim();
  return v.startsWith('assets/') || v.startsWith('asset:') || v.startsWith('packages/');
}

bool _looksLikeDefaultAppIcon(String? s) {
  if (s == null) return false;
  final v = s.trim().toLowerCase();
  // Solo detecta assets/defaults, no carpetas Cloudinary tipo ".../eveta/...".
  return v.contains('ic_app_icon') ||
      v.contains('auth_logo') ||
      v.contains('logo_light') ||
      v.contains('logo_dark');
}

String _cacheBustImageUrl(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return s;
  final uri = Uri.tryParse(s);
  if (uri == null) return '$s?v=${DateTime.now().millisecondsSinceEpoch}';
  final qp = Map<String, String>.from(uri.queryParameters)
    ..['v'] = DateTime.now().millisecondsSinceEpoch.toString();
  return uri.replace(queryParameters: qp).toString();
}

class _CategoryPreview extends StatelessWidget {
  const _CategoryPreview({
    required this.logoUrl,
    required this.bannerUrl,
  });

  final String? logoUrl;
  final String? bannerUrl;

  Widget _imageThumb(BuildContext context, String raw, {required BoxFit fit}) {
    final scheme = Theme.of(context).colorScheme;
    final s = raw.trim();
    if (s.isEmpty) {
      return Icon(Icons.broken_image_outlined, size: 14, color: scheme.onSurfaceVariant);
    }
    if (_looksLikeAssetPath(s)) {
      final asset = s.replaceFirst(RegExp(r'^asset:\s*', caseSensitive: false), '');
      return Image.asset(
        asset,
        fit: fit,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) =>
            Icon(Icons.broken_image_outlined, size: 14, color: scheme.onSurfaceVariant),
      );
    }
    // Por defecto intentamos red (Cloudinary o cualquier CDN).
    return Image.network(
      _cacheBustImageUrl(s),
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) =>
          Icon(Icons.broken_image_outlined, size: 14, color: scheme.onSurfaceVariant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = _categoryImageUrl(logoUrl);
    final banner = _categoryImageUrl(bannerUrl);
    // Logo 1:1 debe venir de `icon`. Solo caemos al banner si no hay icon.
    final iconIsBad = icon == null ||
        icon.isEmpty ||
        _looksLikeAssetPath(icon) ||
        _looksLikeDefaultAppIcon(icon);
    final logo = iconIsBad ? null : icon;
    final hasLogo = logo != null && logo.isNotEmpty;
    final hasBanner = banner != null && banner.isNotEmpty;
    final bg = scheme.surfaceContainerHighest.withValues(alpha: 0.9);

    return SizedBox(
      width: 72,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: bg,
            ),
            clipBehavior: Clip.antiAlias,
            child: hasLogo
                ? _imageThumb(context, logo, fit: BoxFit.cover)
                : Icon(Icons.image_outlined, size: 14, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 4),
          Container(
            width: 36,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: bg,
            ),
            clipBehavior: Clip.antiAlias,
            child: hasBanner
                ? _imageThumb(context, banner, fit: BoxFit.cover)
                : Icon(Icons.photo_outlined, size: 14, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
