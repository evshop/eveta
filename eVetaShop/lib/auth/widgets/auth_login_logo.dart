import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logos del login según tema (SVG, sin marco ni sombra; el diseño va en el archivo).
///
/// Coloca tus SVG en:
/// - [assets/images/auth_logo_light.svg] → modo claro
/// - [assets/images/auth_logo_dark.svg]  → modo oscuro
///
/// Respaldo si falla la carga: [assets/images/eVeta.svg].
class AuthLoginLogo extends StatelessWidget {
  const AuthLoginLogo({super.key, this.size = 100});

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final path = isDark ? 'assets/images/auth_logo_dark.svg' : 'assets/images/auth_logo_light.svg';

    return Center(
      child: SvgPicture.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => SvgPicture.asset(
          'assets/images/eVeta.svg',
          width: size * 0.55,
          height: size * 0.55,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
