import 'package:flutter/material.dart';

/// Transición entre pantallas de auth (login → registro, olvidé contraseña, códigos, etc.):
/// fundido + deslizamiento horizontal suave (estilo navegación tipo app).
PageRoute<T> evetaAuthFadeRoute<T extends Object?>(Widget page) {
  const forward = Duration(milliseconds: 340);
  const reverse = Duration(milliseconds: 280);
  return PageRouteBuilder<T>(
    transitionDuration: forward,
    reverseTransitionDuration: reverse,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.07, 0), end: Offset.zero).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}
