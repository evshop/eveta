import 'package:flutter/material.dart';
/// Fondo agrupado tipo Ajustes iOS (lista sobre gris claro / negro suave).
Color evetaIosGroupedListBackground(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
}

/// Bloque redondeado con filas y divisores entre medias (estilo Ajustes).
class EvetaIosSettingsGroup extends StatelessWidget {
  const EvetaIosSettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final border = scheme.outline.withValues(alpha: isDark ? 0.35 : 0.22);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: border, width: 0.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class EvetaIosSettingsTile extends StatelessWidget {
  const EvetaIosSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.destructive = false,
    this.showDividerAbove = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool destructive;
  final bool showDividerAbove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = destructive ? scheme.error : scheme.primary;
    final titleColor = destructive ? scheme.error : scheme.onSurface;
    final divider = scheme.outline.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.28);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDividerAbove)
          Divider(height: 1, thickness: 0.5, color: divider, indent: 56),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: subtitle == null ? 48 : 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Icon(icon, size: 22, color: accent.withValues(alpha: destructive ? 1 : 0.95)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: subtitle == null
                          ? Text(
                              title,
                              style: tt.bodyLarge?.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.41,
                                color: titleColor,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: tt.bodyLarge?.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: -0.41,
                                    color: titleColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall?.copyWith(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    trailing ??
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                          size: 22,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Separación vertical entre grupos (16–32 pt en iOS).
class EvetaIosSettingsGroupSpacer extends StatelessWidget {
  const EvetaIosSettingsGroupSpacer({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}
