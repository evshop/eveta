import 'package:flutter/material.dart';

/// Barra: **Correo** ⟷ **Teléfono** con icono de intercambio al centro.
class AuthIdentifierModeSwitch extends StatelessWidget {
  const AuthIdentifierModeSwitch({
    super.key,
    required this.phoneMode,
    required this.onChanged,
  });

  final bool phoneMode;
  final void Function(bool phoneSelected) onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ModeLabel(
          label: 'Correo',
          selected: !phoneMode,
          onTap: () => onChanged(false),
          scheme: scheme,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: IconButton(
            tooltip: 'Intercambiar correo y teléfono',
            onPressed: () => onChanged(!phoneMode),
            icon: AnimatedRotation(
              turns: phoneMode ? 0.5 : 0,
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              child: Icon(Icons.swap_horiz_rounded, size: 30, color: scheme.primary),
            ),
          ),
        ),
        _ModeLabel(
          label: 'Teléfono',
          selected: phoneMode,
          onTap: () => onChanged(true),
          scheme: scheme,
        ),
      ],
    );
  }
}

class _ModeLabel extends StatelessWidget {
  const _ModeLabel({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.scheme,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: selected ? 2.5 : 0,
                color: selected ? scheme.primary : Colors.transparent,
              ),
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.45),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
