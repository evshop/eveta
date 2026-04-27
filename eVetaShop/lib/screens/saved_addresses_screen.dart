import 'package:flutter/material.dart';

import 'package:eveta/screens/location_onboarding_screen.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/ui/shop/eveta_empty_state.dart';
import 'package:eveta/utils/delivery_location_prefs.dart';

/// Lista de direcciones guardadas: ver, activar y borrar.
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  List<SavedDeliveryLocation> _list = [];
  String? _activeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DeliveryLocationPrefs.loadSaved();
    final active = await DeliveryLocationPrefs.loadActiveId();
    if (!mounted) return;
    setState(() {
      _list = list;
      _activeId = active;
      _loading = false;
    });
  }

  Future<void> _openAdd() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const LocationOnboardingScreen()),
    );
    if (mounted) await _load();
  }

  Future<void> _setActive(SavedDeliveryLocation e) async {
    await DeliveryLocationPrefs.selectSaved(e.id);
    if (!mounted) return;
    setState(() => _activeId = e.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${e.displayTitle}" es ahora tu dirección de entrega'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Future<void> _confirmDelete(SavedDeliveryLocation e) async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg)),
        title: const Text('¿Borrar dirección?'),
        content: Text('Se quitará "${e.displayTitle}" de tus guardadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await DeliveryLocationPrefs.removeSaved(e.id);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('Tus ubicaciones', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Agregar'),
        backgroundColor: scheme.surfaceContainerHigh,
        foregroundColor: scheme.onSurface,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : _list.isEmpty
              ? EvetaEmptyState(
                  icon: Icons.location_off_outlined,
                  title: 'Sin direcciones guardadas',
                  subtitle: 'Agregá una en el mapa para que sepamos dónde entregar tus pedidos.',
                  actionLabel: 'Agregar dirección',
                  onAction: _openAdd,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final e = _list[i];
                    final active = e.id == _activeId;
                    final sub = e.address.trim().isNotEmpty ? e.address.trim() : e.geocodedLine.trim();
                    return Material(
                      color: active ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _setActive(e),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                active ? Icons.check_circle_rounded : Icons.place_outlined,
                                color: active ? scheme.onSurface : scheme.onSurfaceVariant,
                                size: 26,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            e.displayTitle,
                                            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        if (active)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: scheme.surface,
                                              borderRadius: BorderRadius.circular(999),
                                              border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
                                            ),
                                            child: Text(
                                              'Activa',
                                              style: tt.labelSmall?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: scheme.onSurface,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (sub.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        sub,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: tt.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Borrar',
                                onPressed: () => _confirmDelete(e),
                                icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
