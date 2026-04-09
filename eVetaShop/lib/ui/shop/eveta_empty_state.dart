import 'package:flutter/material.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

class EvetaEmptyState extends StatelessWidget {
  const EvetaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.space2xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(EvetaShopDimens.space2xl),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: scheme.onSurfaceVariant.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: EvetaShopDimens.space2xl),
            Text(title, textAlign: TextAlign.center, style: tt.headlineSmall),
            if (subtitle != null) ...[
              const SizedBox(height: EvetaShopDimens.spaceSm),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: tt.bodyMedium,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: EvetaShopDimens.space2xl),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
