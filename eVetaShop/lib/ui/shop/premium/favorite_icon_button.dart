import 'package:flutter/material.dart';
import 'package:eveta/utils/favorites_service.dart';

/// Botón circular de favorito reutilizable (estado interno + Supabase/local).
class FavoriteIconButton extends StatefulWidget {
  const FavoriteIconButton({
    super.key,
    required this.productId,
    required this.productMap,
    this.size = 34,
    this.iconSize = 19,
  });

  final String productId;
  final Map<String, dynamic> productMap;
  final double size;
  final double iconSize;

  @override
  State<FavoriteIconButton> createState() => _FavoriteIconButtonState();
}

class _FavoriteIconButtonState extends State<FavoriteIconButton> {
  bool _on = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant FavoriteIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _sync();
    }
  }

  Future<void> _sync() async {
    final v = await FavoritesService.isFavorite(widget.productId);
    if (mounted) setState(() {
      _on = v;
      _ready = true;
    });
  }

  Future<void> _toggle() async {
    final item = FavoriteItem.fromProductMap(widget.productMap);
    final now = await FavoritesService.toggleFavorite(item);
    if (mounted) setState(() => _on = now);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.94),
        shape: const CircleBorder(),
        elevation: 0.5,
        shadowColor: Colors.black26,
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: _ready ? _toggle : null,
          icon: Icon(
            _on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: widget.iconSize,
            color: _on ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
