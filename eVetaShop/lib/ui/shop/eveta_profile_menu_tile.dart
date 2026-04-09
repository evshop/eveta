import 'package:flutter/material.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

class EvetaProfileMenuTile extends StatelessWidget {
  const EvetaProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: EvetaShopDimens.spaceSm),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: EvetaShopDimens.spaceLg, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: destructive
                        ? scheme.error.withValues(alpha: 0.12)
                        : scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(EvetaShopDimens.radiusMd),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: destructive ? scheme.error : scheme.primary,
                  ),
                ),
                const SizedBox(width: EvetaShopDimens.spaceMd),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: destructive ? scheme.error : scheme.onSurface,
                    ),
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
