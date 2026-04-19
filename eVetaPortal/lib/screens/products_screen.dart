import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/portal/portal_empty_state.dart';
import '../widgets/portal/portal_haptics.dart';
import '../widgets/portal/portal_tokens.dart';
import '../widgets/portal_cached_image.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<dynamic> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('products')
          .select(
            'id, name, price, stock, images, category_id, description, unit, '
            'tags, specs_json, is_active, is_featured',
          )
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _products = response;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading products: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _normalizeProductMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  /// Fila completa desde Supabase (evita datos incompletos al editar desde la lista).
  Future<Map<String, dynamic>?> _fetchProductRowForEdit(String id) async {
    try {
      final row = await Supabase.instance.client
          .from('products')
          .select(
            'id, name, price, stock, images, category_id, description, unit, '
            'tags, specs_json, is_active, is_featured',
          )
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      final m = Map<dynamic, dynamic>.from(row as Map);
      return Map<String, dynamic>.from(
        m.map((k, v) => MapEntry(k.toString(), v)),
      );
    } catch (e) {
      debugPrint('Error loading product for edit: $e');
      return null;
    }
  }

  Future<void> _navigateToForm([dynamic product]) async {
    portalHapticLight();
    Map<String, dynamic>? normalized = _normalizeProductMap(product);
    if (product != null) {
      final id = normalized?['id']?.toString();
      if (id != null && id.isNotEmpty) {
        final fresh = await _fetchProductRowForEdit(id);
        if (fresh != null) normalized = fresh;
      }
    }
    if (product != null && normalized == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cargar el producto para editar.')),
        );
      }
      return;
    }
    if (!mounted) return;

    // Pantalla completa: botón atrás del sistema / AppBar y gesto de retroceso (como antes).
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProductFormScreen(product: normalized),
      ),
    );

    if (result == true && mounted) {
      setState(() => _isLoading = true);
      _fetchProducts();
    }
  }

  Future<void> _openPublishSheet() async {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    portalHapticLight();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: PortalTokens.motionNormal,
      pageBuilder: (ctx, anim, _) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, MediaQuery.paddingOf(ctx).bottom + 12),
            child: Material(
              color: Colors.transparent,
              child: FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(PortalTokens.radiusXl + 4),
                      border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
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
                            'Nuevo producto',
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Fotos, precio, inventario y categoría en un solo formulario.',
                            style: tt.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                portalHapticSelect();
                                Navigator.of(ctx).pop();
                                _navigateToForm();
                              },
                              icon: const Icon(CupertinoIcons.plus_circle_fill, size: 22),
                              label: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'Empezar',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(PortalTokens.radiusLg + 2),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              portalHapticSelect();
                              Navigator.of(ctx).pop();
                            },
                            child: Text(
                              'Cancelar',
                              style: tt.titleSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) => child,
    );
  }

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PortalTokens.radiusXl)),
        title: const Text('Eliminar producto'),
        content: const Text('¿Seguro que quieres eliminar este producto? No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client.from('products').delete().eq('id', productId);
      _fetchProducts();
    } catch (e) {
      debugPrint('Error deleting product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar el producto.')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Mis productos', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: PortalTokens.motionNormal,
          child: _isLoading
              ? Center(key: const ValueKey('l'), child: CircularProgressIndicator(color: scheme.primary))
              : _products.isEmpty
                  ? PortalEmptyState(
                      key: const ValueKey('e'),
                      icon: Icons.inventory_2_outlined,
                      title: 'Sin productos aún',
                      subtitle: 'Publica tu primer artículo y empieza a vender en eVeta.',
                      action: FilledButton.icon(
                        onPressed: _openPublishSheet,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Subir producto'),
                      ),
                    )
                  : ListView.builder(
                      key: const ValueKey('list'),
                      padding: const EdgeInsets.fromLTRB(
                        PortalTokens.space2,
                        PortalTokens.space1,
                        PortalTokens.space2,
                        100,
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final id = product['id']?.toString() ?? '$index';
                        final imageUrl = (product['images'] != null && product['images'].isNotEmpty)
                            ? product['images'][0] as String
                            : null;
                        final name = product['name'] ?? 'Sin nombre';
                        final stock = product['stock'] ?? 0;
                        final price = product['price'];
                        final priceStr = price != null ? 'Bs ${(price as num).toStringAsFixed(2)}' : '—';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: PortalTokens.space2),
                          child: Slidable(
                            key: ValueKey('p_$id'),
                            groupTag: 'products',
                            startActionPane: ActionPane(
                              motion: const BehindMotion(),
                              extentRatio: 0.28,
                              children: [
                                SlidableAction(
                                  onPressed: (_) {
                                    portalHapticLight();
                                    _navigateToForm(product);
                                  },
                                  backgroundColor: scheme.primary,
                                  foregroundColor: scheme.onPrimary,
                                  icon: Icons.edit_rounded,
                                  label: 'Editar',
                                  borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
                                ),
                              ],
                            ),
                            endActionPane: ActionPane(
                              motion: const BehindMotion(),
                              extentRatio: 0.28,
                              children: [
                                SlidableAction(
                                  onPressed: (_) {
                                    portalHapticMedium();
                                    _deleteProduct(product['id']);
                                  },
                                  backgroundColor: scheme.error,
                                  foregroundColor: scheme.onError,
                                  icon: Icons.delete_outline_rounded,
                                  label: 'Eliminar',
                                  borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
                                ),
                              ],
                            ),
                            child: Material(
                              color: scheme.surfaceContainerHighest,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(PortalTokens.radius2xl),
                                side: BorderSide(color: scheme.outline.withValues(alpha: 0.08)),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(PortalTokens.radius2xl),
                                onTap: () {
                                  portalHapticLight();
                                  _navigateToForm(product);
                                },
                                splashColor: scheme.primary.withValues(alpha: 0.08),
                                child: Padding(
                                  padding: const EdgeInsets.all(PortalTokens.space2),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
                                        child: SizedBox(
                                          width: 88,
                                          height: 88,
                                          child: imageUrl != null
                                              ? PortalCachedImage(
                                                  imageUrl: imageUrl,
                                                  fit: BoxFit.cover,
                                                  memCacheWidth: 360,
                                                )
                                              : ColoredBox(
                                                  color: scheme.surfaceContainerHigh,
                                                  child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: PortalTokens.space2),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Stock: $stock',
                                              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              priceStr,
                                              style: tt.titleMedium?.copyWith(
                                                color: scheme.primary,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded, color: scheme.outline),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: FloatingActionButton.extended(
          heroTag: 'portal_add_product',
          elevation: 4,
          onPressed: _openPublishSheet,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuevo'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
