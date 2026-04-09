import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const Color _kDeleteRed = Color(0xFFE53935);

/// Desliza a la izquierda: panel de eliminar hasta cerrar o borrar (mismo patrón que el carrito).
class EvetaSwipeRevealDelete extends StatefulWidget {
  const EvetaSwipeRevealDelete({
    super.key,
    required this.child,
    required this.onDelete,
    required this.screenWidth,
    required this.isOpen,
    required this.onOpen,
    required this.onClose,
  });

  final Widget child;
  final VoidCallback onDelete;
  final double screenWidth;
  final bool isOpen;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  static const double reveal = 78;

  @override
  State<EvetaSwipeRevealDelete> createState() => _EvetaSwipeRevealDeleteState();
}

class _EvetaSwipeRevealDeleteState extends State<EvetaSwipeRevealDelete> {
  late double _dx;

  @override
  void initState() {
    super.initState();
    _dx = widget.isOpen ? EvetaSwipeRevealDelete.reveal : 0;
  }

  @override
  void didUpdateWidget(covariant EvetaSwipeRevealDelete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      _dx = widget.isOpen ? EvetaSwipeRevealDelete.reveal : 0;
    }
  }

  void _snapFromDrag() {
    final half = EvetaSwipeRevealDelete.reveal / 2;
    final open = _dx > half;
    setState(() => _dx = open ? EvetaSwipeRevealDelete.reveal : 0);
    if (open) {
      widget.onOpen();
    } else {
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    const reveal = EvetaSwipeRevealDelete.reveal;
    final scheme = Theme.of(context).colorScheme;
    final deleteStrip = Color.alphaBlend(
      _kDeleteRed.withValues(alpha: 0.14),
      scheme.surfaceContainerHigh,
    );

    return ClipRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: reveal,
            child: Material(
              color: deleteStrip,
              child: InkWell(
                onTap: widget.onDelete,
                splashColor: _kDeleteRed.withValues(alpha: 0.12),
                child: const Center(
                  child: _EvetaSwipeDeleteSvgIcon(),
                ),
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dx = (_dx - details.delta.dx).clamp(0.0, reveal);
              });
            },
            onHorizontalDragEnd: (_) => _snapFromDrag(),
            child: Transform.translate(
              offset: Offset(-_dx, 0),
              child: Container(
                width: widget.screenWidth,
                color: scheme.surface,
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvetaSwipeDeleteSvgIcon extends StatelessWidget {
  const _EvetaSwipeDeleteSvgIcon();

  static const String _asset = 'assets/images/ic_cart_swipe_delete.svg';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _asset,
      width: 28,
      height: 28,
      fit: BoxFit.contain,
    );
  }
}
