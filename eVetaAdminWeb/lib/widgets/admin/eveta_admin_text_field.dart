import 'package:flutter/material.dart';

class EvetaAdminTextField extends StatelessWidget {
  const EvetaAdminTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.suffix,
    this.prefixIcon,
    this.autofillHints,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? suffix;
  final IconData? prefixIcon;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      autofillHints: autofillHints,
      enabled: enabled,
      style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 22, color: scheme.onSurfaceVariant)
            : null,
        suffixIcon: suffix,
      ),
    );
  }
}
