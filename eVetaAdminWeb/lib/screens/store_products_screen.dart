import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/products_service.dart';
import '../widgets/admin_shop_product_card.dart';
import 'official_store_screen.dart';
import 'partner_store_edit_screen.dart';

/// Vista de catálogo de una tienda (cards estilo eVetaShop).
class StoreProductsScreen extends StatefulWidget {
  const StoreProductsScreen({
    super.key,
    required this.sellerId,
    required this.storeTitle,
    this.subtitle,
    required this.isOfficialAdminStore,
  });

  final String sellerId;
  final String storeTitle;
  final String? subtitle;
  /// true = "Mi tienda" (config con OfficialStoreScreen).
  final bool isOfficialAdminStore;

  @override
  State<StoreProductsScreen> createState() => _StoreProductsScreenState();
}

class _StoreProductsScreenState extends State<StoreProductsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _products = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ProductsService.fetchProductsForSeller(widget.sellerId);
      if (!mounted) return;
      setState(() {
        _products = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showProductSheet(Map<String, dynamic> p) {
    final id = p['id']?.toString() ?? '';
    final name = p['name']?.toString() ?? '';
    final desc = p['description']?.toString() ?? '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (id.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('ID: $id', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(desc, maxLines: 6, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStoreSettings() async {
    if (widget.isOfficialAdminStore) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            appBar: AppBar(
              title: const Text('Configurar mi tienda'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: OfficialStoreScreen(),
            ),
          ),
        ),
      );
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            appBar: AppBar(
              title: const Text('Editar tienda'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: PartnerStoreEditScreen(profileId: widget.sellerId),
            ),
          ),
        ),
      );
    }
    if (mounted) _load();
  }

  Future<void> _copyStoreEmail() async {
    final email = widget.subtitle?.trim() ?? '';
    if (email.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correo copiado')),
    );
  }

  Future<void> _sendStorePasswordReset() async {
    final email = widget.subtitle?.trim() ?? '';
    if (email.isEmpty || !email.contains('@')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay un correo válido para esta tienda.')),
      );
      return;
    }
    try {
      await AuthService.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se envió un enlace de recuperación a $email'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el correo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.storeTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
              Text(
                widget.subtitle!,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        actions: [
          if (widget.subtitle != null &&
              widget.subtitle!.trim().isNotEmpty &&
              widget.subtitle!.contains('@'))
            PopupMenuButton<String>(
              tooltip: 'Acceso de la tienda',
              icon: const Icon(Icons.key_rounded),
              onSelected: (value) {
                if (value == 'copy') {
                  _copyStoreEmail();
                } else if (value == 'reset') {
                  _sendStorePasswordReset();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'copy', child: Text('Copiar correo')),
                PopupMenuItem(
                  value: 'reset',
                  child: Text('Enviar recuperación de contraseña'),
                ),
              ],
            ),
          IconButton(
            tooltip: widget.isOfficialAdminStore ? 'Configurar tienda' : 'Editar tienda',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openStoreSettings,
          ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              Text(
                                '${_products.length} productos',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_products.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'Esta tienda aún no tiene productos.',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          sliver: SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final w = constraints.crossAxisExtent;
                              final cross = w > 1000
                                  ? 5
                                  : w > 800
                                      ? 4
                                      : w > 560
                                          ? 3
                                          : 2;
                              return SliverGrid(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cross,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.72,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) {
                                    final p = _products[i];
                                    return AdminShopProductCard(
                                      product: p,
                                      onTap: () => _showProductSheet(p),
                                    );
                                  },
                                  childCount: _products.length,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
