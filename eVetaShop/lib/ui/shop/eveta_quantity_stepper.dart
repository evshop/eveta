import 'package:flutter/material.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

class EvetaQuantityStepper extends StatelessWidget {
  const EvetaQuantityStepper({
    super.key,
    required this.quantity,
    required this.min,
    required this.max,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final int min;
  final int max;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canDec = quantity > min && onDecrement != null;
    final canInc = quantity < max && onIncrement != null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(EvetaShopDimens.radiusXl),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundIconBtn(
            icon: Icons.remove_rounded,
            enabled: canDec,
            onTap: onDecrement,
            filled: false,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: scheme.onSurface,
              ),
            ),
          ),
          _RoundIconBtn(
            icon: Icons.add_rounded,
            enabled: canInc,
            onTap: onIncrement,
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.filled,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? (enabled ? scheme.primary : scheme.surfaceContainerHighest)
                : scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: filled
                ? (enabled ? scheme.onPrimary : scheme.onSurfaceVariant)
                : (enabled ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }
}
