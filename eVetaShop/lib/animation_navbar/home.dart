import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NavbarHomeIcon extends StatelessWidget {
  const NavbarHomeIcon({
    super.key,
    required this.progress,
    required this.isDarkMode,
    this.size = 24,
  });

  final double progress;
  final bool isDarkMode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final unselectedColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.55);
    final selectedColor = isDarkMode ? Colors.white : Colors.black;

    return Transform.scale(
      scale: Tween<double>(begin: 0.94, end: 1.08).transform(t),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 1 - t,
            child: SvgPicture.asset(
              'assets/images/home_white.svg',
              width: size,
              height: size,
              colorFilter: ColorFilter.mode(unselectedColor, BlendMode.srcIn),
            ),
          ),
          Opacity(
            opacity: t,
            child: SvgPicture.asset(
              'assets/images/home_dark.svg',
              width: size,
              height: size,
              colorFilter: ColorFilter.mode(selectedColor, BlendMode.srcIn),
            ),
          ),
        ],
      ),
    );
  }
}
