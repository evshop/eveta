import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.onChanged,
    this.inputFormatters,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofillHints,
    this.prefixText,
    this.counterText,
    this.maxLength,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? prefixText;
  final String? counterText;
  final int? maxLength;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      autofillHints: autofillHints,
      maxLength: maxLength,
      style: TextStyle(
        color: scheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixStyle: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.85),
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        counterText: counterText,
        prefixIcon: prefixIcon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 4),
                child: prefixIcon,
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        suffixIcon: suffix,
      ),
    );
  }
}
