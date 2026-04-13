import 'package:flutter/services.dart';

/// Feedback háptico ligero para taps (Material + sensación tipo iOS).
void portalHapticLight() {
  HapticFeedback.lightImpact();
}

void portalHapticSelect() {
  HapticFeedback.selectionClick();
}

void portalHapticMedium() {
  HapticFeedback.mediumImpact();
}
