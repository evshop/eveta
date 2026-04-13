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

  Future<void> _navigateToForm([Map<String, dynamic>? product]) async {
    final scheme = Theme.of(context).colorScheme;
    portalHapticLight();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PortalTokens.radius2xl)),
      ),
      builder: (ctx) {
        final h = MediaQuery.of(ctx).size.height;
        return SizedBox(
          height: h * 0.94,
          child: ProductFormScreen(product: product),
        );
      },
    );

    if (result == true) {
      setState(() => _isLoading = true);
      _fetchProducts();
    }
  }

  Future<void> _openPublishSheet() async {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    portalHapticLight();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PortalTokens.radius2xl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(PortalTokens.space2, 8, PortalTokens.space2, PortalTokens.space2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.add_photo_alternate_rounded, color: scheme.primary),
                  title: const Text('Subir producto'),
                  subtitle: const Text('Añade fotos, precio y categoría'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateToForm();
                  },
                ),
              ],
            ),
          ),
        );
      },
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
                                    _navigateToForm(Map<String, dynamic>.from(product as Map));
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
                                  _navigateToForm(Map<String, dynamic>.from(product as Map));
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
