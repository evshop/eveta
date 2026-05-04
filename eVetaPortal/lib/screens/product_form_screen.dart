import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cloudinary_service.dart';
import '../services/portal_session.dart';
import '../widgets/portal/eveta_portal_image_picker_sheet.dart';
import '../widgets/portal/portal_haptics.dart';
import '../widgets/portal/portal_notice.dart';
import '../widgets/portal/portal_section_header.dart';
import '../widgets/portal/portal_tokens.dart';
import '../widgets/product_form_images_grid.dart';

class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? product; // If null, it's a new product. If provided, we're editing.

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isUploading = false;
  
  // Fields
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _tagsController = TextEditingController();
  String _unit = 'unidad';
  String? _parentCategoryId;
  String? _categoryId;
  bool _isActive = true;
  bool _isFeatured = false;
  
  List<dynamic> _categories = [];
  List<String> _images = [];
  String? _coverUrl; // Imagen principal (estrella). En la DB se guarda como images[0].
  
  // Plantilla de specs por categoría (viene de categories.*).
  final Map<String, TextEditingController> _specControllers = {};
  List<String> _currentSpecLabels = [];
  String _currentSpecGroupTitle = '';
  Map<String, String> _initialSpecValues = {};
  
  // Igual que el panel admin (sin "manojo").
  final List<String> _units = ['unidad', 'kg', 'g', 'litro', 'ml'];

  /// Espacio extra al hacer scroll al foco (AppBar + teclado / bottom sheet).
  static const EdgeInsets _fieldScrollPadding = EdgeInsets.fromLTRB(0, 100, 0, 200);

  @override
  void initState() {
    super.initState();
    _initFormData();
    // Abre el scaffold primero; categorías en el siguiente frame (mejor sensación de velocidad).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCategories();
    });
  }

  static bool _parseBool(dynamic v, {required bool fallback}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 't') return true;
    if (s == 'false' || s == '0' || s == 'f') return false;
    return fallback;
  }

  /// Lista de URLs desde Supabase (List, JSON string o literal tipo Postgres `{a,b}`).
  static List<String> _parseProductImages(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    }
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return [];
      if (s.startsWith('[')) {
        try {
          final decoded = jsonDecode(s);
          if (decoded is List) {
            return decoded.map((e) => e.toString().trim()).where((t) => t.isNotEmpty).toList();
          }
        } catch (_) {}
      }
      if (s.startsWith('{') && s.endsWith('}')) {
        final inner = s.substring(1, s.length - 1).trim();
        if (inner.isEmpty) return [];
        return inner
            .split(',')
            .map((t) => t.trim().replaceAll('"', ''))
            .where((t) => t.isNotEmpty)
            .toList();
      }
      return [s];
    }
    return [];
  }

  void _initFormData() {
    if (widget.product != null) {
      final p = widget.product!;
      _nameController.text = p['name'] ?? '';
      _descController.text = p['description'] ?? '';
      _priceController.text = (p['price'] ?? '').toString();
      _stockController.text = (p['stock'] ?? '').toString();
      var unitRaw = (p['unit'] ?? 'unidad').toString().trim();
      if (!_units.contains(unitRaw)) unitRaw = 'unidad';
      _unit = unitRaw;
      final cid = p['category_id']?.toString().trim();
      _categoryId = (cid == null || cid.isEmpty) ? null : cid;
      _isActive = _parseBool(p['is_active'], fallback: true);
      _isFeatured = _parseBool(p['is_featured'], fallback: false);

      _images = _parseProductImages(p['images']);
      _coverUrl = _images.isNotEmpty ? _images.first : null;

      // specs_json: [{"label":"Pantalla","value":"..."}]
      _initialSpecValues = _parseSpecsJson(p['specs_json']);

      final tagsRaw = p['tags'];
      if (tagsRaw is List) {
        final tags = tagsRaw
            .map((e) => e.toString().replaceAll('#', '').trim())
            .where((t) => t.isNotEmpty)
            .toList();
        _tagsController.text = tags.join(', ');
      } else if (tagsRaw is String && tagsRaw.trim().isNotEmpty) {
        final s = tagsRaw.trim();
        if (s.startsWith('[')) {
          try {
            final decoded = jsonDecode(s);
            if (decoded is List) {
              final tags = decoded
                  .map((e) => e.toString().replaceAll('#', '').trim())
                  .where((t) => t.isNotEmpty)
                  .toList();
              _tagsController.text = tags.join(', ');
            }
          } catch (_) {
            _tagsController.text = s;
          }
        } else {
          _tagsController.text = s;
        }
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final data = await Supabase.instance.client
          .from('categories')
          .select('id, name, parent_id, spec_template_enabled, spec_field_labels, spec_group_title')
          .order('name');

      // Un solo setState: evita un frame intermedio sin padre/subcategoría resueltos.
      setState(() {
        _categories = data;

        if (_categoryId != null && _categoryId!.isNotEmpty) {
          final cid = _categoryId!;
          final selected = data.firstWhere(
            (c) => c['id']?.toString().trim() == cid,
            orElse: () => <String, dynamic>{},
          );
          if (selected.isNotEmpty) {
            final rawPid = selected['parent_id']?.toString().trim();
            if (rawPid != null && rawPid.isNotEmpty) {
              _parentCategoryId = rawPid;
            } else {
              _parentCategoryId = selected['id']?.toString().trim();
            }
          }
        }
        _categoryId = _categoryId?.trim();
        _parentCategoryId = _parentCategoryId?.trim();
      });

      if (_categoryId != null && _categoryId!.isNotEmpty) {
        _rebuildSpecControllersForCategory(_resolvedCategoryId);
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  bool _isRootCategoryRow(Map<dynamic, dynamic> c) {
    final p = c['parent_id']?.toString().trim();
    return p == null || p.isEmpty;
  }

  List<Map<String, dynamic>> _parentCategories() {
    return _categories
        .where((c) => _isRootCategoryRow(c as Map))
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
  }

  List<Map<String, dynamic>> _subCategoriesForParent(String parentId) {
    final p = parentId.trim();
    return _categories
        .where((c) => c['parent_id']?.toString().trim() == p)
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
  }

  /// Categoría guardada en DB: subcategoría si se eligió; si no, la padre (válido aunque existan subs).
  String? get _resolvedCategoryId {
    final pid = _parentCategoryId;
    if (pid == null) return _categoryId;
    final subs = _subCategoriesForParent(pid);
    if (subs.isEmpty) return pid;
    return _categoryId ?? pid;
  }

  InputDecoration _inputDec(
    BuildContext context,
    String label, {
    String? prefixText,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      alignLabelWithHint: alignLabelWithHint,
    ).applyDefaults(Theme.of(context).inputDecorationTheme);
  }

  Map<String, String> _parseSpecsJson(dynamic raw) {
    final out = <String, String>{};
    dynamic list = raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        list = decoded;
      } catch (_) {
        return out;
      }
    }
    if (list is List) {
      for (final e in list) {
        if (e is Map) {
          final l = e['label']?.toString();
          if (l != null && l.trim().isNotEmpty) {
            out[l.trim()] = e['value']?.toString() ?? '';
          }
        }
      }
    }
    return out;
  }

  List<String> _specLabelsForCategory(String? categoryId) {
    if (categoryId == null) return const [];
    final cidNorm = categoryId.trim();
    for (final c in _categories) {
      if (c['id']?.toString().trim() == cidNorm) {
        if (c['spec_template_enabled'] != true) return const [];
        final raw = c['spec_field_labels'];
        if (raw is List) {
          return raw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
        }
        return const [];
      }
    }
    return const [];
  }

  String _specGroupTitleForCategory(String? categoryId) {
    if (categoryId == null) return '';
    final cidNorm = categoryId.trim();
    for (final c in _categories) {
      if (c['id']?.toString().trim() == cidNorm) {
        return c['spec_group_title']?.toString().trim() ?? '';
      }
    }
    return '';
  }

  void _rebuildSpecControllersForCategory(String? categoryId) {
    final newLabels = _specLabelsForCategory(categoryId);
    final newGroupTitle = _specGroupTitleForCategory(categoryId);

    final existingKeys = _specControllers.keys.toSet();
    final newKeys = newLabels.toSet();

    // Controllers que ya no se usan.
    final toDispose = existingKeys.difference(newKeys).toList();
    final controllersToDispose = toDispose.map((k) => _specControllers[k]!).toList();

    for (final k in toDispose) {
      _specControllers.remove(k);
    }

    // Asegura controladores nuevos/actualizados.
    for (final label in newLabels) {
      final ctrl = _specControllers[label] ?? TextEditingController();
      ctrl.text = _initialSpecValues[label] ?? '';
      _specControllers[label] = ctrl;
    }

    if (controllersToDispose.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final c in controllersToDispose) {
          c.dispose();
        }
      });
    }

    setState(() {
      _currentSpecLabels = newLabels;
      _currentSpecGroupTitle = newGroupTitle;
    });
  }

  Future<void> _pickAndUploadImage() async {
    if (_images.length >= 10) {
      showPortalNotice(context, 'Puedes subir un maximo de 10 imagenes.', type: PortalNoticeType.info);
      return;
    }

    final remainingSlots = 10 - _images.length;
    final files = await EvetaPortalImagePicker.pick(
      context,
      EvetaPortalImagePickerOptions(
        title: 'Añadir fotos',
        subtitle: 'Galería: varias a la vez · Cámara: vista previa antes de usar',
        allowMultiFromGallery: true,
        maxFiles: remainingSlots,
      ),
    );
    if (files == null || files.isEmpty || !mounted) return;

    setState(() => _isUploading = true);
    var added = 0;
    try {
      final sellerId = await PortalSession.currentSellerId();
      if (sellerId == null) throw Exception('No user logged in');

      for (var i = 0; i < files.length; i++) {
        if (!mounted) return;
        final pickedFile = files[i];
        final bytes = await pickedFile.readAsBytes();
        final path = pickedFile.path;
        final rawExt = path.contains('.') ? path.split('.').last.toLowerCase() : 'jpg';
        final ext = ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(rawExt) ? rawExt : 'jpg';
        final fileName =
            '${DateTime.now().microsecondsSinceEpoch}_${i}_${_images.length}.$ext';

        final imageUrl = await CloudinaryService.uploadImage(
          bytes: bytes,
          fileName: fileName,
          folder: 'eveta/portal_store/products/$sellerId',
        );

        if (!mounted) return;
        setState(() {
          _images.add(imageUrl);
          _coverUrl ??= imageUrl;
        });
        added++;
      }
      if (mounted && added > 0) {
        showPortalNotice(
          context,
          added == 1 ? 'Foto anadida.' : '$added fotos anadidas.',
          type: PortalNoticeType.success,
        );
      }
    } catch (e) {
      debugPrint('Error uploading images: $e');
      if (mounted) {
        showPortalNotice(context, 'Error al subir fotos. Intenta otra vez.', type: PortalNoticeType.error);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      final removedUrl = _images[index];
      _images.removeAt(index);
      if (_coverUrl == removedUrl) {
        _coverUrl = _images.isNotEmpty ? _images.first : null;
      }
    });
  }

  void _reorderImage(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    setState(() {
      final item = _images.removeAt(oldIndex);
      // Criterio del paquete reorderable_grid_view (README): insert en newIndex sin ajuste tipo ListView.
      final j = newIndex.clamp(0, _images.length);
      _images.insert(j, item);
    });
  }

  void _makeCover(int index) {
    setState(() {
      if (index < 0 || index >= _images.length) return;
      _coverUrl = _images[index];
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_images.isEmpty) {
      showPortalNotice(context, 'Debes subir al menos una foto del producto.', type: PortalNoticeType.error);
      return;
    }

    final categoryId = _resolvedCategoryId;
    if (categoryId == null || categoryId.isEmpty) {
      showPortalNotice(context, 'Por favor, selecciona una categoria.', type: PortalNoticeType.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sellerId = await PortalSession.currentSellerId();
      if (sellerId == null) throw Exception('No user logged in');

      final specRows = _currentSpecLabels
          .map((label) => <String, String>{
                'label': label,
                'value': _specControllers[label]?.text ?? '',
              })
          .toList();

      final tags = _tagsController.text
          .split(RegExp(r'[\s,]+'))
          .map((t) => t.replaceAll('#', '').trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();

      final productData = {
        'seller_id': sellerId,
        'category_id': categoryId,
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': double.parse(_priceController.text),
        'stock': int.parse(_stockController.text),
        'unit': _unit,
        // Asegura que la portada se guarde como images[0] para que en la web/card
        // se vea la imagen seleccionada con estrella.
        'images': (() {
          final imagesSave = List<String>.from(_images);
          if (_coverUrl != null && imagesSave.contains(_coverUrl)) {
            imagesSave.remove(_coverUrl);
            imagesSave.insert(0, _coverUrl!);
          }
          return imagesSave;
        })(),
        'is_active': _isActive,
        'is_featured': _isFeatured,
        'specs_json': specRows,
        'tags': tags,
      };

      if (widget.product == null) {
        // Create new
        await Supabase.instance.client.from('products').insert(productData);
        if (mounted) {
          showPortalNotice(context, 'Producto creado con exito.', type: PortalNoticeType.success);
        }
      } else {
        // Update existing
        await Supabase.instance.client
            .from('products')
            .update(productData)
            .eq('id', widget.product!['id'].toString());
        if (mounted) {
          showPortalNotice(context, 'Producto actualizado.', type: PortalNoticeType.success);
        }
      }
      
      if (mounted) {
        Navigator.pop(context, true); // Return true to signal refresh needed
      }
    } catch (e) {
      debugPrint('Error saving product: $e');
      if (mounted) {
        showPortalNotice(context, 'Error al guardar el producto.', type: PortalNoticeType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    final scheme = Theme.of(context).colorScheme;

    // DropdownButtonFormField exige que initialValue coincida con un item (Flutter 3.33+).
    final parentRowsRaw = _parentCategories();
    final seenParentIds = <String>{};
    final parentRows = <Map<String, dynamic>>[];
    for (final c in parentRowsRaw) {
      final id = c['id']?.toString().trim();
      if (id == null || id.isEmpty || seenParentIds.contains(id)) continue;
      seenParentIds.add(id);
      parentRows.add(c);
    }
    final parentIdSet = parentRows.map((c) => c['id']?.toString().trim()).whereType<String>().toSet();
    final parentCatTrim = _parentCategoryId?.trim();
    final parentDropdownInitial =
        parentCatTrim != null && parentIdSet.contains(parentCatTrim) ? parentCatTrim : null;

    String? subDropdownInitial;
    final pid = _parentCategoryId?.trim();
    if (pid != null && pid.isNotEmpty) {
      final subIdSet = _subCategoriesForParent(pid)
          .map((c) => c['id']?.toString().trim())
          .whereType<String>()
          .toSet();
      final cid = _categoryId?.trim();
      if (cid != null && subIdSet.contains(cid)) subDropdownInitial = cid;
    }

    final unitDropdownInitial = _units.contains(_unit) ? _unit : 'unidad';

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        // Botón atrás explícito (además del gesto / botón físico del sistema).
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop<bool>(false),
        ),
        automaticallyImplyLeading: false,
        title: Text(isEditing ? 'Editar producto' : 'Subir producto'),
      ),
      // El Scaffold aplica el inset del teclado al cuerpo; evita Padding(viewInsets) aquí,
      // que reconstruía todo el formulario (imágenes, reorder, etc.) en cada frame del teclado.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PortalTokens.space2),
          // onDrag competía con el scroll vertical y bloqueaba arrastrar hacia la derecha en la grilla.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PortalSectionHeader(
                  title: 'Fotos del producto',
                  subtitle: 'Hasta 10 imágenes · arrastra para reordenar · marca la portada',
                ),
                RepaintBoundary(
                  child: ProductFormImagesGrid(
                    images: _images,
                    coverUrl: _coverUrl,
                    isUploading: _isUploading,
                    onReorder: _reorderImage,
                    onRemove: _removeImage,
                    onMakeCover: _makeCover,
                    onAddTap: _pickAndUploadImage,
                  ),
                ),
                const SizedBox(height: PortalTokens.space3),

                const PortalSectionHeader(
                  title: 'Información',
                  subtitle: 'Nombre y descripción que verán los compradores',
                ),
                TextFormField(
                controller: _nameController,
                scrollPadding: _fieldScrollPadding,
                decoration: _inputDec(context, 'Nombre del producto'),
                validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descController,
                scrollPadding: _fieldScrollPadding,
                decoration: _inputDec(context, 'Descripción', alignLabelWithHint: true),
                keyboardType: TextInputType.multiline,
                maxLines: 6,
                minLines: 3,
              ),
              const SizedBox(height: PortalTokens.space3),

              const PortalSectionHeader(
                title: 'Precio e inventario',
                subtitle: 'Unidad de venta y existencias',
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      scrollPadding: _fieldScrollPadding,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDec(context, 'Precio (Bs)', prefixText: 'Bs '),
                      validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      scrollPadding: _fieldScrollPadding,
                      keyboardType: TextInputType.number,
                      decoration: _inputDec(context, 'Stock'),
                      validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PortalTokens.space2),

              DropdownButtonFormField<String>(
                key: ValueKey<String>('unit_$unitDropdownInitial'),
                initialValue: unitDropdownInitial,
                decoration: _inputDec(context, 'Unidad de venta'),
                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (val) => setState(() => _unit = val!),
              ),
              const SizedBox(height: PortalTokens.space3),

              const PortalSectionHeader(
                title: 'Categoría',
                subtitle: 'Clasifica tu producto para que sea fácil de encontrar',
              ),
              DropdownButtonFormField<String>(
                key: ValueKey<String?>('parent_${parentDropdownInitial}_${_parentCategoryId}_${parentRows.length}'),
                initialValue: parentDropdownInitial,
                decoration: _inputDec(context, 'Categoría'),
                items: parentRows
                    .map((c) {
                      final id = c['id']?.toString().trim();
                      if (id == null || id.isEmpty) return null;
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(c['name']?.toString() ?? ''),
                      );
                    })
                    .whereType<DropdownMenuItem<String>>()
                    .toList(),
                onChanged: (val) {
                  if (val == null || val.isEmpty) return;
                  final children = _subCategoriesForParent(val);
                  setState(() {
                    _parentCategoryId = val;
                    // Si no tiene subcategorías, usamos la categoría padre como categoría del producto.
                    _categoryId = children.isEmpty ? val : null;
                  });
                  _rebuildSpecControllersForCategory(_resolvedCategoryId);
                },
                hint: const Text('Seleccionar categoría'),
              ),

              if (_parentCategoryId != null && _subCategoriesForParent(_parentCategoryId!).isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey<String?>('sub_${_parentCategoryId}_${subDropdownInitial}_$_categoryId'),
                  initialValue: subDropdownInitial,
                  decoration: _inputDec(context, 'Subcategoría'),
                  items: _subCategoriesForParent(_parentCategoryId!)
                      .map((c) {
                        final id = c['id']?.toString().trim();
                        if (id == null || id.isEmpty) return null;
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(c['name']?.toString() ?? ''),
                        );
                      })
                      .whereType<DropdownMenuItem<String>>()
                      .toList(),
                  onChanged: (val) {
                    if (val == null || val.isEmpty) return;
                    setState(() => _categoryId = val);
                    _rebuildSpecControllersForCategory(val);
                  },
                  hint: const Text('Seleccionar subcategoría'),
                ),
              ],

              const SizedBox(height: PortalTokens.space3),

              if (_currentSpecLabels.isNotEmpty) ...[
                PortalSectionHeader(
                  title: _currentSpecGroupTitle.isNotEmpty ? _currentSpecGroupTitle : 'Especificaciones',
                  subtitle: 'Campos sugeridos para esta categoría',
                ),
                ..._currentSpecLabels.map((label) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _specControllers[label],
                      scrollPadding: _fieldScrollPadding,
                      decoration: _inputDec(context, label, alignLabelWithHint: true),
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 2,
                      maxLines: 6,
                    ),
                  );
                }),
                const SizedBox(height: PortalTokens.space1),
              ],

              const PortalSectionHeader(
                title: 'Hashtags',
                subtitle: 'Palabras clave separadas por coma o espacio',
              ),
              TextField(
                controller: _tagsController,
                scrollPadding: _fieldScrollPadding,
                decoration: _inputDec(context, 'Hashtags', alignLabelWithHint: true).copyWith(
                  hintText: 'Ej. samsung amoled 5g (separa por coma o espacio)',
                ),
                keyboardType: TextInputType.multiline,
                maxLines: 3,
              ),

              const SizedBox(height: PortalTokens.space3),

              const PortalSectionHeader(
                title: 'Visibilidad',
                subtitle: 'Controla cómo aparece en el marketplace',
              ),
              SwitchListTile(
                title: const Text('Producto Activo'),
                subtitle: const Text('Visible en el mercado'),
                activeThumbColor: scheme.primary,
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              SwitchListTile(
                title: const Text('Destacado'),
                subtitle: const Text('Aparece en la sección de destacados'),
                activeThumbColor: scheme.primary,
                value: _isFeatured,
                onChanged: (val) => setState(() => _isFeatured = val),
              ),
              const SizedBox(height: PortalTokens.space3),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          portalHapticMedium();
                          _saveProduct();
                        },
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: scheme.onPrimary, strokeWidth: 2),
                        )
                      : Text(
                          isEditing ? 'Guardar Cambios' : 'Crear Producto',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: PortalTokens.space3),
            ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _tagsController.dispose();
    for (final c in _specControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
}
