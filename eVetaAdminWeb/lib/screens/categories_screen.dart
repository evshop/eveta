import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/cloudinary_service.dart';
import '../services/products_service.dart';
import '../utils/cloudinary_image_url.dart';
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
    String? logoUrl = existing?['icon']?.toString();
    String? bannerUrl = existing?['image_url']?.toString();
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
                        evetaImageDeliveryUrl(logoUrl!, EvetaImageDelivery.card),
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
                            logoUrl = await CloudinaryService.uploadImage(
                              bytes: cropped,
                              fileName: 'category_logo.png',
                              folder: 'eveta/categories/logo',
                            );
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
                        evetaImageDeliveryUrl(bannerUrl!, EvetaImageDelivery.card),
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
                            bannerUrl = await CloudinaryService.uploadImage(
                              bytes: cropped,
                              fileName: 'category_banner.png',
                              folder: 'eveta/categories/banner',
                            );
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => _openCategoryDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva categoría'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _clearSeedCategories,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Borrar categorías actuales'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _categories.isEmpty
              ? const Center(child: Text('No hay categorías registradas.'))
              : ListView.separated(
                  itemCount: _categories.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final c = _categories[index];
                    final pid = c['parent_id']?.toString();
                    Map<String, dynamic>? parent;
                    if (pid != null) {
                      for (final x in _categories) {
                        if (x['id'].toString() == pid) {
                          parent = x;
                          break;
                        }
                      }
                    }
                    final specOn = c['spec_template_enabled'] == true;
                    final rawL = c['spec_field_labels'];
                    var specHint = '';
                    if (specOn && rawL is List && rawL.isNotEmpty) {
                      final names = rawL.map((e) => e.toString()).take(3).join(', ');
                      final gt = c['spec_group_title']?.toString().trim();
                      final block = (gt != null && gt.isNotEmpty) ? gt : 'Campos extra';
                      specHint = ' · $block: $names${rawL.length > 3 ? '…' : ''}';
                    }
                    final subline = parent != null
                        ? 'slug: ${c['slug']} · ${parent['name']} › ${c['name']}$specHint'
                        : 'slug: ${c['slug']} · Categoría principal$specHint';
                    return ListTile(
                      leading: _CategoryPreview(
                        logoUrl: c['icon']?.toString(),
                        bannerUrl: c['image_url']?.toString(),
                      ),
                      title: Text(c['name'].toString()),
                      subtitle: Text(subline),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _openCategoryDialog(existing: c),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => _deleteCategory(c),
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CategoryPreview extends StatelessWidget {
  const _CategoryPreview({
    required this.logoUrl,
    required this.bannerUrl,
  });

  final String? logoUrl;
  final String? bannerUrl;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    final hasBanner = bannerUrl != null && bannerUrl!.isNotEmpty;
    return SizedBox(
      width: 84,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey.shade200,
            ),
            clipBehavior: Clip.antiAlias,
            child: hasLogo
                ? Image.network(
                    evetaImageDeliveryUrl(logoUrl!, EvetaImageDelivery.thumb),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.image_not_supported, size: 16),
                  )
                : const Icon(Icons.image_outlined, size: 16),
          ),
          const SizedBox(width: 6),
          Container(
            width: 42,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey.shade200,
            ),
            clipBehavior: Clip.antiAlias,
            child: hasBanner
                ? Image.network(
                    evetaImageDeliveryUrl(bannerUrl!, EvetaImageDelivery.thumb),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.photo_outlined, size: 16),
                  )
                : const Icon(Icons.photo_outlined, size: 16),
          ),
        ],
      ),
    );
  }
}
