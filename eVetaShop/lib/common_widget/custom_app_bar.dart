import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:eveta/screens/search_screen.dart';

class CustomAppBar extends StatefulWidget {
  const CustomAppBar({
    super.key,
    this.location = 'La Paz, Bolivia',
    this.onLocationTap,
    this.onProfileTap,
    this.showLocation = true,
    this.shrinkProgress = 0.0,
  });

  final String location;
  final VoidCallback? onLocationTap;
  final VoidCallback? onProfileTap;
  final bool showLocation;
  final double shrinkProgress; // 0.0 (expandido) a 1.0 (colapsado)

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(100), // Altura aumentada para el nuevo diseño
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: const Color(0xFF09CB6B),
          statusBarIconBrightness: Brightness.light,
        ),
        child: ClipRRect(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF09CB6B),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Icono de perfil
                        GestureDetector(
                          onTap: widget.onProfileTap,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Buscador Largo (Ocupa el resto del espacio)
                        Expanded(
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              readOnly: true,
                              textAlign: TextAlign.left,
                              textAlignVertical: TextAlignVertical.center,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.15,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SearchScreen(),
                                  ),
                                );
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Buscar en eVeta',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 13,
                                  height: 1.15,
                                ),
                                suffixIcon: const Align(
                                  widthFactor: 1,
                                  heightFactor: 1,
                                  child: Icon(
                                    Icons.search,
                                    color: Color(0xFF09CB6B),
                                    size: 20,
                                  ),
                                ),
                                suffixIconConstraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 38,
                                  maxHeight: 38,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  10,
                                  8,
                                  10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.showLocation)
                      Opacity(
                        opacity: (1.0 - widget.shrinkProgress * 2).clamp(0.0, 1.0),
                        child: Align(
                          heightFactor: (1.0 - widget.shrinkProgress).clamp(0.0, 1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 8),
                              // Ubicación a la izquierda
                              GestureDetector(
                                onTap: widget.onLocationTap,
                                child: Row(
                                  children: [
                                    SvgPicture.asset(
                                      'assets/images/ic_location.svg',
                                      width: 12,
                                      height: 12,
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Ingresa tu ubicación',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
