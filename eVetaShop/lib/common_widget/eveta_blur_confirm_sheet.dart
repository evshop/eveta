import 'dart:ui';

import 'package:flutter/material.dart';

const Color _kConfirmDeleteRed = Color(0xFFFF4747);

/// Diálogo a pantalla completa: el fondo **solo hace fade** (sin deslizar el blur) y la tarjeta **sube** aparte.
/// Evita la línea que aparecía al animar junto con [showModalBottomSheet].
Future<bool?> showEvetaBlurConfirmSheet(
  BuildContext context, {
  required String title,
  required Widget preview,
}) {
  final barrierLabel = MaterialLocalizations.of(context).modalBarrierDismissLabel;
  return showGeneralDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _EvetaBlurConfirmOverlay(
        animation: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        title: title,
        preview: preview,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return child;
    },
  );
}

class _EvetaBlurConfirmOverlay extends StatelessWidget {
  const _EvetaBlurConfirmOverlay({
    required this.animation,
    required this.title,
    required this.preview,
  });

  final Animation<double> animation;
  final String title;
  final Widget preview;

  static const BorderRadius _topRadius = BorderRadius.vertical(top: Radius.circular(22));
  static const BorderRadius _pill = BorderRadius.all(Radius.circular(999));

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value.clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: t < 0.01,
                  child: Opacity(
                    opacity: t,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(context, false),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionalTranslation(
                  translation: Offset(0, 1 - t),
                  child: Opacity(
                    opacity: t,
                    child: _SheetCard(
                      title: title,
                      preview: preview,
                      topRadius: _topRadius,
                      pill: _pill,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SheetCard extends StatelessWidget {
  const _SheetCard({
    required this.title,
    required this.preview,
    required this.topRadius,
    required this.pill,
  });

  final String title;
  final Widget preview;
  final BorderRadius topRadius;
  final BorderRadius pill;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: topRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 28,
              spreadRadius: 0,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 18),
                preview,
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.grey.shade200.withValues(alpha: 0.65),
                        borderRadius: pill,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, false),
                          borderRadius: pill,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Cancelar',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Material(
                        color: _kConfirmDeleteRed,
                        borderRadius: pill,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, true),
                          borderRadius: pill,
                          splashColor: Colors.white24,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Sí, eliminar',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
