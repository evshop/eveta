import 'package:flutter/material.dart';

/// Botón circular con borde marcado y flecha centrada (sin blur).
class EvetaCircularBackButton extends StatelessWidget {
  const EvetaCircularBackButton({
    super.key,
    this.onPressed,
    this.variant = EvetaCircularBackVariant.onLightBackground,
    this.diameter = 40,
    this.iconSize,
    this.borderWidth = 1,
  });

  final VoidCallback? onPressed;
  final EvetaCircularBackVariant variant;
  final double diameter;
  final double? iconSize;

  /// Grosor del aro (visible sobre cualquier fondo).
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final tappable = onPressed != null || canPop;
    final chrome = _chromeForBackVariant(context, variant);
    final localizations = MaterialLocalizations.of(context);

    void handleTap() {
      if (onPressed != null) {
        onPressed!();
        return;
      }
      if (canPop) {
        Navigator.maybePop(context);
      }
    }

    return Tooltip(
      message: localizations.backButtonTooltip,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: tappable ? handleTap : null,
              child: Container(
                width: diameter,
                height: diameter,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: chrome.fill,
                  border: Border.all(
                    color: chrome.border,
                    width: borderWidth,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back,
                  size: iconSize ?? diameter * 0.44,
                  color: tappable ? chrome.icon : chrome.icon.withValues(alpha: 0.38),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum EvetaCircularBackVariant {
  /// Fondo claro (AppBar blanco, etc.): icono oscuro.
  onLightBackground,

  /// Fondo oscuro o verde eVeta: icono blanco.
  onDarkBackground,

  /// AppBar sobre superficie del tema (modo oscuro en detalle / búsqueda): píldora [ColorScheme], sin blanco semitransparente.
  tonalSurface,
}

class _CircleChrome {
  const _CircleChrome({required this.fill, required this.border, required this.icon});

  final Color fill;
  final Color border;
  final Color icon;
}

_CircleChrome _chromeForBackVariant(BuildContext context, EvetaCircularBackVariant variant) {
  switch (variant) {
    case EvetaCircularBackVariant.onLightBackground:
      return _CircleChrome(
        fill: Colors.white,
        border: const Color(0xFF64748B).withValues(alpha: 0.28),
        icon: const Color(0xFF1F2937),
      );
    case EvetaCircularBackVariant.onDarkBackground:
      return _CircleChrome(
        fill: Colors.white.withValues(alpha: 0.22),
        border: Colors.white.withValues(alpha: 0.45),
        icon: Colors.white,
      );
    case EvetaCircularBackVariant.tonalSurface:
      final scheme = Theme.of(context).colorScheme;
      final isDark = scheme.brightness == Brightness.dark;
      return _CircleChrome(
        fill: scheme.surfaceContainerHigh,
        border: scheme.outline.withValues(alpha: isDark ? 0.38 : 0.26),
        icon: scheme.onSurface.withValues(alpha: isDark ? 0.95 : 0.9),
      );
  }
}

/// Mismo estilo visual que [EvetaCircularBackButton], con icono y acción libres.
class EvetaCircularIconButton extends StatelessWidget {
  const EvetaCircularIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.variant = EvetaCircularBackVariant.onLightBackground,
    this.diameter = 40,
    this.iconSize,
    this.borderWidth = 1,
    this.selected = false,
    this.activeIconColor = const Color(0xFF09CB6B),
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final EvetaCircularBackVariant variant;
  final double diameter;
  final double? iconSize;
  final double borderWidth;
  final bool selected;
  final Color activeIconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chrome = _chromeForIconVariant(
      context,
      variant: variant,
      selected: selected,
      activeIconColor: activeIconColor,
    );

    final child = SizedBox(
      width: 56,
      height: 56,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Container(
              width: diameter,
              height: diameter,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: chrome.fill,
                border: Border.all(
                  color: chrome.border,
                  width: borderWidth,
                ),
              ),
              child: Icon(
                icon,
                size: iconSize ?? diameter * 0.44,
                color: onPressed != null ? chrome.icon : chrome.icon.withValues(alpha: 0.38),
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

_CircleChrome _chromeForIconVariant(
  BuildContext context, {
  required EvetaCircularBackVariant variant,
  required bool selected,
  required Color activeIconColor,
}) {
  switch (variant) {
    case EvetaCircularBackVariant.onLightBackground:
      return _CircleChrome(
        fill: Colors.white,
        border: const Color(0xFF64748B).withValues(alpha: 0.28),
        icon: selected ? activeIconColor : const Color(0xFF1F2937),
      );
    case EvetaCircularBackVariant.onDarkBackground:
      return _CircleChrome(
        fill: Colors.white.withValues(alpha: 0.22),
        border: Colors.white.withValues(alpha: 0.45),
        icon: selected ? activeIconColor : Colors.white,
      );
    case EvetaCircularBackVariant.tonalSurface:
      final scheme = Theme.of(context).colorScheme;
      if (selected) {
        return _CircleChrome(
          fill: scheme.primary.withValues(alpha: 0.18),
          border: activeIconColor.withValues(alpha: 0.42),
          icon: activeIconColor,
        );
      }
      return _CircleChrome(
        fill: scheme.surfaceContainerHigh,
        border: scheme.outline.withValues(alpha: scheme.brightness == Brightness.dark ? 0.38 : 0.26),
        icon: scheme.onSurface.withValues(alpha: scheme.brightness == Brightness.dark ? 0.95 : 0.9),
      );
  }
}
