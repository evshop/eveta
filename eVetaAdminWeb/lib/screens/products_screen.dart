import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product_form_data.dart';
import '../services/cloudinary_service.dart';
import '../utils/cloudinary_image_url.dart';
import '../services/products_service.dart';
import '../theme/admin_theme.dart';

final ImagePicker _imagePicker = ImagePicker();

String? _firstProductImageUrl(Map<String, dynamic> product) {
  final images = product['images'];
  if (images is List && images.isNotEmpty) {
    return images.first.toString();
  }
  if (images is String && images.isNotEmpty) {
    return images;
  }
  return null;
}

String _categoryPickerLabelFor(Map<String, dynamic> c, Map<String, String> idToName) {
  final pid = c['parent_id']?.toString();
  if (pid == null) return c['name'].toString();
  final pn = idToName[pid];
  return pn != null ? '$pn › ${c['name']}' : c['name'].toString();
}

List<Map<String, dynamic>> _sortedCategoriesForPicker(
  List<Map<String, dynamic>> all,
  Map<String, String> idToName,
) {
  final copy = List<Map<String, dynamic>>.from(all);
  copy.sort(
    (a, b) => _categoryPickerLabelFor(a, idToName).toLowerCase().compareTo(
          _categoryPickerLabelFor(b, idToName).toLowerCase(),
        ),
  );
  return copy;
}

List<String> _specLabelsForCategory(String catId, List<Map<String, dynamic>> categories) {
  Map<String, dynamic>? row;
  for (final x in categories) {
    if (x['id'].toString() == catId) {
      row = x;
      break;
    }
  }
  if (row == null) return [];
  if (row['spec_template_enabled'] != true) return [];
  final raw = row['spec_field_labels'];
  if (raw is List) {
    return raw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
  }
  return [];
}

Map<String, String> _parseProductSpecsJson(dynamic raw) {
  final out = <String, String>{};
  if (raw is List) {
    for (final e in raw) {
      if (e is Map) {
        final l = e['label']?.toString();
        if (l != null && l.isNotEmpty) {
          out[l] = e['value']?.toString() ?? '';
        }
      }
    }
  }
  return out;
}

String _specBlockHeadingForCategory(String catId, List<Map<String, dynamic>> categories) {
  Map<String, dynamic>? row;
  for (final x in categories) {
    if (x['id'].toString() == catId) {
      row = x;
      break;
    }
  }
  if (row == null) return 'Información adicional';
  final t = row['spec_group_title']?.toString().trim();
  if (t == null || t.isEmpty) return 'Información adicional';
  return t;
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];

  static const String _kCardImageHelp =
      'La imagen con la estrella rellena es la que se guarda como primera (índice 0): es la que '
      'se ve en la tarjeta del producto en la tienda. Podés reordenar el resto arrastrando cada '
      'foto; el orden que queda se usa para las demás imágenes en el detalle.';

  /// Si |ancho − alto| ≤ esto (px), se guarda como cuadrado.
  static const int _squarePixelTolerance = 20;

  String _normalizeStoredOrientation(Object? raw) {
    switch (raw?.toString()) {
      case 'cuadrado':
      case 'horizontal':
      case 'vertical':
        return raw.toString();
      case 'square':
        return 'cuadrado';
      case 'landscape':
        return 'horizontal';
      case 'portrait':
        return 'vertical';
      default:
        return 'desconocido';
    }
  }

  List<Map<String, dynamic>> _parseImagesLayoutFromRow(dynamic raw, int imageCount) {
    final out = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final m = Map<String, dynamic>.from(e.map((k, v) => MapEntry(k.toString(), v)));
          m['orientation'] = _normalizeStoredOrientation(m['orientation']);
          out.add(m);
        }
      }
    }
    while (out.length < imageCount) {
      out.add({
        'width': null,
        'height': null,
        'aspect_ratio': null,
        'orientation': 'desconocido',
      });
    }
    if (out.length > imageCount) {
      out.removeRange(imageCount, out.length);
    }
    return out;
  }

  /// Alinea [layout] con [images] (longitud).
  void _syncImagesLayoutToImages(List<String> images, List<Map<String, dynamic>> layout) {
    while (layout.length < images.length) {
      layout.add({
        'width': null,
        'height': null,
        'aspect_ratio': null,
        'orientation': 'desconocido',
      });
    }
    while (layout.length > images.length) {
      layout.removeLast();
    }
  }

  /// [displayUrls]: orden visual (izquierda→derecha). [cover]: URL marcada con estrella → siempre `images[0]`.
  (List<String>, List<Map<String, dynamic>>) _imagesForPersistence(
    List<String> displayUrls,
    List<Map<String, dynamic>> displayLayouts,
    String? cover,
  ) {
    if (displayUrls.isEmpty) return (<String>[], <Map<String, dynamic>>[]);
    final c = (cover != null && displayUrls.contains(cover)) ? cover : displayUrls.first;
    final rest = displayUrls.where((u) => u != c).toList();
    final images = [c, ...rest];
    final byUrl = <String, Map<String, dynamic>>{};
    for (var i = 0; i < displayUrls.length; i++) {
      byUrl[displayUrls[i]] = displayLayouts[i];
    }
    final layouts = images.map((u) {
      final m = byUrl[u];
      if (m == null) {
        return {
          'width': null,
          'height': null,
          'aspect_ratio': null,
          'orientation': 'desconocido',
        };
      }
      return Map<String, dynamic>.from(m);
    }).toList();
    return (images, layouts);
  }

  String _productListCategorySubtitle(Map<String, dynamic> p) {
    final cat = p['categories'];
    if (cat is! Map) return 'Cat: -';
    final name = cat['name']?.toString() ?? '-';
    final pid = cat['parent_id']?.toString();
    if (pid == null) return 'Cat: $name';
    for (final c in _categories) {
      if (c['id'].toString() == pid) {
        return 'Cat: ${c['name']} › $name';
      }
    }
    return 'Cat: $name';
  }

  Future<Map<String, dynamic>> _analyzeImageLayout(Uint8List bytes) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    final img = await completer.future;

    final w = img.width;
    final h = img.height;
    img.dispose();

    if (w <= 0 || h <= 0) {
      return {
        'width': w,
        'height': h,
        'aspect_ratio': null,
        'orientation': 'desconocido',
      };
    }

    final ratio = w / h;
    final orientation = (w - h).abs() <= _squarePixelTolerance
        ? 'cuadrado'
        : (w > h ? 'horizontal' : 'vertical');

    return {
      'width': w,
      'height': h,
      'aspect_ratio': double.parse(ratio.toStringAsFixed(5)),
      'orientation': orientation,
    };
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final products = await ProductsService.fetchMyProducts()
          .timeout(const Duration(seconds: 45), onTimeout: () => throw TimeoutException('Productos'));
      final categories = await ProductsService.fetchCategories()
          .timeout(const Duration(seconds: 45), onTimeout: () => throw TimeoutException('Categorías'));
      if (!mounted) return;
      setState(() {
        _products = products;
        _categories = categories;
      });
    } catch (e, stack) {
      debugPrint('ProductsScreen._refresh error: $e\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cargar la sección: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
      setState(() {
        _products = [];
        _categories = [];
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero crea categorías en la base de datos.')),
      );
      return;
    }
    final categoryIdToName = {
      for (final c in _categories) c['id'].toString(): c['name'].toString(),
    };
    final categoryPickerRows = _sortedCategoriesForPicker(_categories, categoryIdToName);
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?['description']?.toString() ?? '');
    final tagsRaw = (existing?['tags'] is List)
        ? (existing!['tags'] as List).map((e) => '#${e.toString().replaceAll('#', '').trim()}').where((s) => s != '#').join(', ')
        : '';
    final tagsCtrl = TextEditingController(text: tagsRaw);
    final priceCtrl = TextEditingController(text: (existing?['price'] ?? '').toString());
    final stockCtrl = TextEditingController(text: (existing?['stock'] ?? '').toString());
    String unit = (existing?['unit'] ?? 'unidad').toString();
    bool isActive = existing?['is_active'] == true;
    bool isFeatured = existing?['is_featured'] == true;
    String categoryId = (existing?['category_id'] ?? _categories.first['id']).toString();
    final specControllers = <String, TextEditingController>{};
    var specValues = _parseProductSpecsJson(existing?['specs_json']);

    void syncSpecValuesFromControllers(String catId) {
      for (final l in _specLabelsForCategory(catId, _categories)) {
        final c = specControllers[l];
        if (c != null) specValues[l] = c.text;
      }
    }

    void rebuildSpecControllersForCategory(String catId) {
      final labels = _specLabelsForCategory(catId, _categories);
      final toDisposeLater = <TextEditingController>[];
      for (final k in specControllers.keys.toList()) {
        if (!labels.contains(k)) {
          final c = specControllers.remove(k);
          if (c != null) toDisposeLater.add(c);
        }
      }
      if (toDisposeLater.isNotEmpty) {
        // No dispose mientras el TextField anterior siga montado (evita assert _dependents).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final c in toDisposeLater) {
            c.dispose();
          }
        });
      }
      for (final l in labels) {
        if (!specControllers.containsKey(l)) {
          specControllers[l] = TextEditingController(text: specValues[l] ?? '');
        } else {
          specControllers[l]!.text = specValues[l] ?? '';
        }
      }
    }

    rebuildSpecControllersForCategory(categoryId);

    final dbImages = (existing?['images'] is List)
        ? (existing?['images'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool uploading = false;
        var orderedUrls = List<String>.from(dbImages);
        var orderedLayouts = _parseImagesLayoutFromRow(existing?['images_layout'], orderedUrls.length);
        String? coverUrl = orderedUrls.isNotEmpty ? orderedUrls.first : null;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> addImagesFromFiles(List<XFile> files) async {
              if (files.isEmpty) return;
              setDialogState(() => uploading = true);
              try {
                for (final f in files) {
                  final bytes = await f.readAsBytes();
                  if (bytes.isEmpty) continue;
                  final meta = await _analyzeImageLayout(bytes);
                  if (!dialogCtx.mounted) return;
                  final url = await CloudinaryService.uploadImage(
                    bytes: bytes,
                    fileName: f.name.isNotEmpty ? f.name : 'product.jpg',
                    folder: 'eveta/products',
                  );
                  orderedUrls.add(url);
                  orderedLayouts.add(meta);
                  coverUrl ??= url;
                  setDialogState(() {});
                }
              } finally {
                setDialogState(() => uploading = false);
              }
            }

            Future<void> pickImagesWithSourcePrompt() async {
              final source = await showModalBottomSheet<ImageSource>(
                context: dialogCtx,
                showDragHandle: true,
                builder: (sheetCtx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ListTile(
                        title: Text('Agregar fotos'),
                        subtitle: Text('Elige de dónde subirlas'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library_outlined),
                        title: const Text('Galería'),
                        onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_camera_outlined),
                        title: const Text('Cámara'),
                        onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
              if (source == null) return;

              if (source == ImageSource.camera) {
                final x = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 92,
                  maxWidth: 2200,
                );
                if (x == null) return;
                await addImagesFromFiles([x]);
                return;
              }

              final xs = await _imagePicker.pickMultiImage(
                imageQuality: 92,
                maxWidth: 2200,
              );
              await addImagesFromFiles(xs);
            }

            return AlertDialog(
            title: Text(existing == null ? 'Subir producto' : 'Editar producto'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 3,
                      maxLines: 10,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(labelText: 'Precio'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: stockCtrl,
                      decoration: const InputDecoration(labelText: 'Stock'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: unit,
                      items: const ['unidad', 'kg', 'g', 'litro', 'ml']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => unit = v ?? 'unidad'),
                      decoration: const InputDecoration(labelText: 'Unidad'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('product_cat_$categoryId'),
                      initialValue: categoryId,
                      isExpanded: true,
                      items: categoryPickerRows
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c['id'].toString(),
                              child: Text(
                                _categoryPickerLabelFor(c, categoryIdToName),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setDialogState(() {
                          syncSpecValuesFromControllers(categoryId);
                          categoryId = v ?? categoryId;
                          rebuildSpecControllersForCategory(categoryId);
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Categoría / subcategoría',
                        helperText: 'Ej. Tecnología › Celulares para ordenar y detalle.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_specLabelsForCategory(categoryId, _categories).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _specBlockHeadingForCategory(categoryId, _categories),
                          style: Theme.of(dialogCtx).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Cada fila: apartado a la izquierda, contenido a la derecha.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      for (final label in _specLabelsForCategory(categoryId, _categories))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 132,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 14, right: 8),
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: specControllers[label],
                                  decoration: const InputDecoration(
                                    hintText: 'Escribe aquí…',
                                    alignLabelWithHint: true,
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  minLines: 2,
                                  maxLines: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: tagsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Hashtags',
                        hintText: '#celulares, #android, #5g',
                        helperText: 'Sepáralos por coma, espacio o salto de línea.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (v) => setDialogState(() => isActive = v),
                      title: const Text('Activo'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      value: isFeatured,
                      onChanged: (v) => setDialogState(() => isFeatured = v),
                      title: const Text('Destacado'),
                      contentPadding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'Fotos del producto',
                            style: Theme.of(dialogCtx).textTheme.titleSmall,
                          ),
                        ),
                        Tooltip(
                          message: _kCardImageHelp,
                          waitDuration: const Duration(milliseconds: 350),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.help_outline,
                              size: 22,
                              color: Theme.of(dialogCtx).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (orderedUrls.isEmpty)
                      const Text('Aún no agregaste fotos.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < orderedUrls.length; i++)
                            SizedBox(
                              width: 86,
                              height: 100,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: orderedUrls[i] == coverUrl
                                              ? Theme.of(dialogCtx).colorScheme.primary
                                              : Colors.grey.shade400,
                                          width: orderedUrls[i] == coverUrl ? 2.5 : 1,
                                        ),
                                        color: Colors.grey.shade100,
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(7),
                                        child: Image.network(
                                          evetaImageDeliveryUrl(
                                            orderedUrls[i],
                                            EvetaImageDelivery.thumb,
                                          ),
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              ColoredBox(color: Colors.grey.shade200),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (orderedUrls[i] == coverUrl)
                                    Positioned(
                                      left: 2,
                                      bottom: 2,
                                      right: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.star, size: 10, color: Colors.amber),
                                            const SizedBox(width: 3),
                                            Expanded(
                                              child: Text(
                                                'Se verá en el producto',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.05,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (orderedUrls[i] != coverUrl)
                                    Positioned(
                                      left: 2,
                                      bottom: 2,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: uploading
                                              ? null
                                              : () {
                                                  coverUrl = orderedUrls[i];
                                                  setDialogState(() {});
                                                },
                                          borderRadius: BorderRadius.circular(4),
                                          child: Tooltip(
                                            message:
                                                'Esta será la imagen en la tarjeta (se guarda como primera)',
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.55),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Icon(
                                                Icons.star_outline,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    right: -10,
                                    top: -10,
                                    child: IconButton(
                                      tooltip: 'Quitar foto',
                                      onPressed: uploading
                                          ? null
                                          : () {
                                              final removed = orderedUrls[i];
                                              orderedUrls.removeAt(i);
                                              if (i < orderedLayouts.length) {
                                                orderedLayouts.removeAt(i);
                                              }
                                              if (coverUrl == removed) {
                                                coverUrl = orderedUrls.isNotEmpty ? orderedUrls.first : null;
                                              }
                                              _syncImagesLayoutToImages(orderedUrls, orderedLayouts);
                                              setDialogState(() {});
                                            },
                                      icon: const Icon(Icons.close, size: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                    const SizedBox(height: 10),
                    if (uploading) const LinearProgressIndicator(),
                    if (uploading) const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: uploading
                              ? null
                              : () async {
                                  await pickImagesWithSourcePrompt();
                                },
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Agregar fotos'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: uploading || orderedUrls.isEmpty
                              ? null
                              : () {
                                  orderedUrls.clear();
                                  orderedLayouts.clear();
                                  coverUrl = null;
                                  setDialogState(() {});
                                },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Limpiar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: uploading
                    ? null
                    : () async {
                        final persisted = _imagesForPersistence(orderedUrls, orderedLayouts, coverUrl);
                        final imagesSave = persisted.$1;
                        final layoutsSave = persisted.$2;
                        _syncImagesLayoutToImages(imagesSave, layoutsSave);
                        syncSpecValuesFromControllers(categoryId);
                        final specLabels = _specLabelsForCategory(categoryId, _categories);
                        final specRows = specLabels.map((l) {
                          final c = specControllers[l];
                          final text = c?.text ?? specValues[l] ?? '';
                          return <String, String>{'label': l, 'value': text};
                        }).toList();
                        final tags = tagsCtrl.text
                            .split(RegExp(r'[\s,]+'))
                            .map((t) => t.replaceAll('#', '').trim().toLowerCase())
                            .where((t) => t.isNotEmpty)
                            .toSet()
                            .toList();
                        final form = ProductFormData(
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          price: double.tryParse(priceCtrl.text.trim()) ?? 0,
                          stock: int.tryParse(stockCtrl.text.trim()) ?? 0,
                          categoryId: categoryId,
                          isActive: isActive,
                          isFeatured: isFeatured,
                          unit: unit,
                          images: imagesSave,
                          imagesLayout: layoutsSave,
                          specRows: specRows,
                          tags: tags,
                        );

                        try {
                          if (existing == null) {
                            await ProductsService.createProduct(form);
                          } else {
                            await ProductsService.updateProduct(existing['id'].toString(), form);
                          }
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(content: Text('No se pudo guardar: $e')),
                            );
                          }
                        }
                      },
                child: const Text('Guardar'),
              ),
            ],
          );
          },
        );
      },
    );

    void disposeDialogControllers() {
      for (final c in specControllers.values) {
        c.dispose();
      }
      specControllers.clear();
      nameCtrl.dispose();
      descCtrl.dispose();
      tagsCtrl.dispose();
      priceCtrl.dispose();
      stockCtrl.dispose();
    }

    // Tras cerrar el diálogo, el árbol aún puede estar desmontando; dispose en el siguiente frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      disposeDialogControllers();
    });

    if (saved == true) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminTokens.radiusSm)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Subir producto'),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: scheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(
                        'No hay productos cargados.',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final cross = w > 1300
                        ? 4
                        : w > 960
                            ? 3
                            : w > 520
                                ? 2
                                : 1;
                    // Ratio ancho/alto: valores ~1.0–1.12 = tarjetas más bajas que con ~0.9.
                    final ratio = w > 900 ? 1.06 : 0.96;
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: ratio,
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final p = _products[index];
                        final catLine = _productListCategorySubtitle(p);
                        final thumbUrl = _firstProductImageUrl(p);
                        final active = p['is_active'] == true;
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openForm(existing: p),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AspectRatio(
                                  // Más ancho que alto → miniatura menos alta.
                                  aspectRatio: 1.75,
                                  child: _ProductGridThumb(imageUrl: thumbUrl),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              p['name']?.toString() ?? 'Sin nombre',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                            ),
                                          ),
                                          if (!active)
                                            Container(
                                              margin: const EdgeInsets.only(left: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFF9800).withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Inactivo',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        catLine,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Bs ${p['price']} · Stock ${p['stock']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: scheme.primary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      tooltip: 'Editar',
                                      visualDensity: VisualDensity.compact,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _openForm(existing: p),
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar',
                                      visualDensity: VisualDensity.compact,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      padding: EdgeInsets.zero,
                                      onPressed: () async {
                                        await ProductsService.deleteProduct(p['id'].toString());
                                        await _refresh();
                                      },
                                      icon: Icon(Icons.delete_outline, color: scheme.error, size: 18),
                                    ),
                                  ],
                                ),
                              ],
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

/// Miniatura para grid de productos.
class _ProductGridThumb extends StatelessWidget {
  const _ProductGridThumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.image_outlined, size: 40, color: scheme.onSurfaceVariant),
      );
    }
    return Image.network(
      evetaImageDeliveryUrl(url, EvetaImageDelivery.card),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
