import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : Text(label),
    );
  }
}

class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({super.key, required this.onPressed, this.loading = false});

  /// Ícono de Google: añade el archivo en `pubspec.yaml` y pon la ruta aquí (`.svg` con [SvgPicture], `.png` con [Image.asset]).
  /// Mientras sea `null` se usa [defaultGoogleIconSvgUrl].
  static const String? googleIconAsset = null;

  /// URL del logo multicolor (SVG). Sustituye por otra URL o usa solo [googleIconAsset].
  static const String defaultGoogleIconSvgUrl =
      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg';

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        foregroundColor: scheme.onSurface,
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      ),
      child: loading
          ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onSurface,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GoogleMark(scheme: scheme),
                const SizedBox(width: 12),
                const Text('Continuar con Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    const size = 22.0;
    final asset = AuthGoogleButton.googleIconAsset;
    if (asset != null) {
      final lower = asset.toLowerCase();
      if (lower.endsWith('.svg')) {
        return SvgPicture.asset(
          asset,
          height: size,
          width: size,
          fit: BoxFit.contain,
        );
      }
      return Image.asset(
        asset,
        height: size,
        width: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.g_mobiledata, size: 24, color: scheme.onSurface),
      );
    }
    return SvgPicture.network(
      AuthGoogleButton.defaultGoogleIconSvgUrl,
      height: size,
      width: size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => SizedBox(
        height: size,
        width: size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: scheme.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
