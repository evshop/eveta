import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logos del login según tema (misma idea que eVetaShop [AuthLoginLogo]).
class PortalAuthLogo extends StatelessWidget {
  const PortalAuthLogo({super.key, this.size = 88});

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
