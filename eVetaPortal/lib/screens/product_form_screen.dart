import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cloudinary_service.dart';

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

  @override
  void initState() {
    super.initState();
    _initFormData();
    _loadCategories();
  }

  void _initFormData() {
    if (widget.product != null) {
      final p = widget.product!;
      _nameController.text = p['name'] ?? '';
      _descController.text = p['description'] ?? '';
      _priceController.text = (p['price'] ?? '').toString();
      _stockController.text = (p['stock'] ?? '').toString();
      _unit = p['unit'] ?? 'unidad';
      _categoryId = p['category_id'];
      _isActive = p['is_active'] ?? true;
      _isFeatured = p['is_featured'] ?? false;
      
      if (p['images'] != null) {
        _images = List<String>.from(p['images']);
      }
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
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final data = await Supabase.instance.client
          .from('categories')
          .select('id, name, parent_id, spec_template_enabled, spec_field_labels, spec_group_title')
          .order('name');
      setState(() {
        _categories = data;
      });

      // Si estás editando, ya tenemos category_id; reconstruye specs.
      if (_categoryId != null) {
        // Detecta el parent para mostrar el 2do dropdown.
        final selected = data.firstWhere(
          (c) => c['id']?.toString() == _categoryId,
          orElse: () => <String, dynamic>{},
        );
        final pid = selected['parent_id']?.toString();
        _parentCategoryId = pid != null && pid.isNotEmpty ? pid : null;
        _rebuildSpecControllersForCategory(_categoryId);
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  List<Map<String, dynamic>> _parentCategories() {
    return _categories
        .where((c) => c['parent_id'] == null || (c['parent_id']?.toString().isEmpty ?? true))
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
  }

  List<Map<String, dynamic>> _subCategoriesForParent(String parentId) {
    return _categories
        .where((c) => c['parent_id']?.toString() == parentId)
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
  }

  Map<String, String> _parseSpecsJson(dynamic raw) {
    final out = <String, String>{};
    if (raw is List) {
      for (final e in raw) {
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
    for (final c in _categories) {
      if (c['id']?.toString() == categoryId) {
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
    for (final c in _categories) {
      if (c['id']?.toString() == categoryId) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puedes subir un máximo de 10 imágenes.')),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Agregar foto'),
              subtitle: Text('Elige de dónde subirla'),
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

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 2200,
    );
    
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final bytes = await pickedFile.readAsBytes();
      final fileExt = pickedFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      final imageUrl = await CloudinaryService.uploadImage(
        bytes: bytes,
        fileName: fileName,
        folder: 'eveta/portal_store/products/${user.id}',
      );

      setState(() {
        _images.add(imageUrl);
        _coverUrl ??= imageUrl;
      });
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al subir la imagen. Intenta de nuevo.')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
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
      // En ReorderableListView el nuevo índice llega como "after move".
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
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
    
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona una categoría.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

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
        'seller_id': user.id,
        'category_id': _categoryId,
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto creado con éxito')));
        }
      } else {
        // Update existing
        await Supabase.instance.client
            .from('products')
            .update(productData)
            .eq('id', widget.product!['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto actualizado')));
        }
      }
      
      if (mounted) {
        Navigator.pop(context, true); // Return true to signal refresh needed
      }
    } catch (e) {
      debugPrint('Error saving product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar el producto.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar producto' : 'Subir producto', style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- IMÁGENES ---
              const Text('Imágenes del producto (Hasta 10)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_images.isEmpty)
                    const Text('Aún no agregaste fotos.')
                  else
                    SizedBox(
                      height: 112,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Queremos ~5 visibles en la hilera, con 10px de separación.
                          final gap = 10.0;
                          final w = constraints.maxWidth;
                          final itemW = ((w - gap * 4) / 5).clamp(56.0, 96.0);

                          return ReorderableListView(
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            onReorder: _reorderImage,
                            buildDefaultDragHandles: false,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            // Sin esto, Flutter envuelve el preview al arrastrar en un Material cuadrado (se ve blanco en las esquinas).
                            proxyDecorator: (Widget child, int index, Animation<double> animation) {
                              return AnimatedBuilder(
                                animation: animation,
                                builder: (context, _) {
                                  final t = Curves.easeInOut.transform(animation.value);
                                  return Transform.scale(
                                    scale: 1.0 + 0.02 * t,
                                    child: Material(
                                      color: Colors.transparent,
                                      shadowColor: Colors.black26,
                                      elevation: 6 * t,
                                      borderRadius: BorderRadius.circular(10),
                                      clipBehavior: Clip.antiAlias,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            children: [
                              for (int idx = 0; idx < _images.length; idx++)
                                Padding(
                                  key: ValueKey(_images[idx]),
                                  padding: EdgeInsets.only(right: idx == _images.length - 1 ? 0 : gap),
                                  child: SizedBox(
                                    width: itemW,
                                    height: 100,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Stack(
                                        clipBehavior: Clip.hardEdge,
                                        children: [
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: (_images[idx] == _coverUrl)
                                                      ? const Color(0xFF09CB6B)
                                                      : Colors.grey.shade400,
                                                  width: (_images[idx] == _coverUrl) ? 2.5 : 1,
                                                ),
                                                color: Colors.grey.shade100,
                                              ),
                                              padding: const EdgeInsets.all(2),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(7),
                                                child: Image.network(
                                                  _images[idx],
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (_images[idx] == _coverUrl)
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
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.star, size: 12, color: Colors.amber),
                                                    SizedBox(width: 3),
                                                    Expanded(
                                                      child: Text(
                                                        'Se verá en el producto',
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
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
                                            )
                                          else
                                            Positioned(
                                              left: 2,
                                              bottom: 2,
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(4),
                                                  onTap: () => _makeCover(idx),
                                                  child: Tooltip(
                                                    message: 'Esta será la imagen en la tarjeta (se guarda como primera)',
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
                                            right: 2,
                                            top: 2,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: IconButton(
                                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                padding: EdgeInsets.zero,
                                                tooltip: 'Quitar foto',
                                                onPressed: _isUploading ? null : () => _removeImage(idx),
                                                icon: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.45),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Handle para reordenar (así el swipe horizontal vuelve a hacer scroll).
                                          Positioned(
                                            right: 4,
                                            bottom: 4,
                                            child: ReorderableDragStartListener(
                                              index: idx,
                                              child: Container(
                                                padding: const EdgeInsets.all(3),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.45),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(
                                                  Icons.drag_handle,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  if (_images.length < 10) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _pickAndUploadImage,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                          ),
                          child: _isUploading
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF09CB6B),
                                    ),
                                  ),
                                )
                              : const Icon(Icons.add_photo_alternate, color: Colors.grey, size: 32),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // --- CAMPOS DE TEXTO ---
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre del producto', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                keyboardType: TextInputType.multiline,
                maxLines: 8,
                minLines: 3,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Precio (Bs)', border: OutlineInputBorder(), prefixText: 'Bs '),
                      validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _unit,
                decoration: const InputDecoration(labelText: 'Unidad de venta', border: OutlineInputBorder()),
                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (val) => setState(() => _unit = val!),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _parentCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items: _parentCategories().map((c) {
                  final id = c['id']?.toString();
                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text(c['name']?.toString() ?? ''),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val == null || val.isEmpty) return;
                  final children = _subCategoriesForParent(val);
                  setState(() {
                    _parentCategoryId = val;
                    // Si no tiene subcategorías, usamos la categoría padre como categoría del producto.
                    _categoryId = children.isEmpty ? val : null;
                  });
                  _rebuildSpecControllersForCategory(_categoryId);
                },
                hint: const Text('Seleccionar categoría'),
              ),

              if (_parentCategoryId != null && _subCategoriesForParent(_parentCategoryId!).isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Subcategoría',
                    border: OutlineInputBorder(),
                  ),
                  items: _subCategoriesForParent(_parentCategoryId!)
                      .map((c) => DropdownMenuItem<String>(
                            value: c['id']?.toString(),
                            child: Text(c['name']?.toString() ?? ''),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val == null || val.isEmpty) return;
                    setState(() => _categoryId = val);
                    _rebuildSpecControllersForCategory(val);
                  },
                  hint: const Text('Seleccionar subcategoría'),
                ),
              ],

              const SizedBox(height: 24),

              // --- SPECS DINAMICAS ---
              if (_currentSpecLabels.isNotEmpty) ...[
                Text(
                  _currentSpecGroupTitle.isNotEmpty ? _currentSpecGroupTitle : 'Especificaciones',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._currentSpecLabels.map((label) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _specControllers[label],
                      decoration: InputDecoration(
                        labelText: label,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 2,
                      maxLines: 8,
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],

              // --- HASHTAGS ---
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Hashtags',
                  hintText: 'Ej. samsung amoled 5g (separa por coma o espacio)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.multiline,
                maxLines: 3,
              ),

              const SizedBox(height: 24),

              // --- SWITCHES ---
              SwitchListTile(
                title: const Text('Producto Activo'),
                subtitle: const Text('Visible en el mercado'),
                activeThumbColor: const Color(0xFF09CB6B),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              SwitchListTile(
                title: const Text('Destacado'),
                subtitle: const Text('Aparece en la sección de destacados'),
                activeThumbColor: const Color(0xFF09CB6B),
                value: _isFeatured,
                onChanged: (val) => setState(() => _isFeatured = val),
              ),
              const SizedBox(height: 32),

              // --- BOTONES ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF09CB6B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEditing ? 'Guardar Cambios' : 'Crear Producto', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
            ],
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
