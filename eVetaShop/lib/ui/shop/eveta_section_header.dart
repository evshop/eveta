import 'package:flutter/material.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

class EvetaSectionHeader extends StatelessWidget {
  const EvetaSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EvetaShopDimens.spaceLg,
        EvetaShopDimens.spaceLg,
        EvetaShopDimens.spaceLg,
        EvetaShopDimens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.35, height: 1.15),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: EvetaShopDimens.spaceMd),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusSm)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel!,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.2,
                          color: scheme.primary,
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, size: 18, color: scheme.primary),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.25),
            ),
          ],
        ],
      ),
    );
  }
}
