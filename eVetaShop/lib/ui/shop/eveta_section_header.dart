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
        EvetaShopDimens.space2xl,
        EvetaShopDimens.spaceLg,
        EvetaShopDimens.spaceMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: tt.bodyMedium),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 20, color: scheme.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
