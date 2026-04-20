import 'package:flutter/material.dart';

import '../../theme/admin_theme.dart';

enum EvetaButtonVariant { primary, secondary, danger }

class EvetaPrimaryButton extends StatelessWidget {
  const EvetaPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.variant = EvetaButtonVariant.primary,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final EvetaButtonVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = loading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: variant == EvetaButtonVariant.secondary ? scheme.primary : scheme.onPrimary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final effectiveOnPressed = loading ? null : onPressed;

    Widget btn;
    switch (variant) {
      case EvetaButtonVariant.primary:
        btn = FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
          ),
          child: child,
        );
      case EvetaButtonVariant.secondary:
        btn = OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          child: child,
        );
      case EvetaButtonVariant.danger:
        btn = FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: scheme.error.withValues(alpha: 0.9),
            foregroundColor: scheme.onError,
          ),
          child: child,
        );
    }

    if (expand) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}

/// Botón de texto para headers / acciones secundarias.
class EvetaTextButton extends StatelessWidget {
  const EvetaTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
      label: Text(label),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminTokens.radiusSm)),
      ),
    );
  }
}
