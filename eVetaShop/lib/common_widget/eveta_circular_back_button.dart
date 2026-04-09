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
    final iconColor = variant == EvetaCircularBackVariant.onLightBackground
        ? const Color(0xFF1F2937)
        : Colors.white;
    final fillColor = variant == EvetaCircularBackVariant.onLightBackground
        ? Colors.white
        : Colors.white.withValues(alpha: 0.22);
    // Borde suave (baja opacidad), que se note pero sin ser duro.
    final borderColor = variant == EvetaCircularBackVariant.onLightBackground
        ? const Color(0xFF64748B).withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.45);
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
                  color: fillColor,
                  border: Border.all(
                    color: borderColor,
                    width: borderWidth,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back,
                  size: iconSize ?? diameter * 0.44,
                  color: tappable ? iconColor : iconColor.withValues(alpha: 0.38),
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
    final baseIcon = variant == EvetaCircularBackVariant.onLightBackground
        ? const Color(0xFF1F2937)
        : Colors.white;
    final iconColor = selected ? activeIconColor : baseIcon;
    final fillColor = variant == EvetaCircularBackVariant.onLightBackground
        ? Colors.white
        : Colors.white.withValues(alpha: 0.22);
    final borderColor = variant == EvetaCircularBackVariant.onLightBackground
        ? const Color(0xFF64748B).withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.45);

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
                color: fillColor,
                border: Border.all(
                  color: borderColor,
                  width: borderWidth,
                ),
              ),
              child: Icon(
                icon,
                size: iconSize ?? diameter * 0.44,
                color: onPressed != null ? iconColor : iconColor.withValues(alpha: 0.38),
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
