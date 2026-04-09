import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:eveta/auth/auth_validators.dart';
import 'package:eveta/auth/widgets/auth_text_field.dart';

/// Campo correo o teléfono con transición al cambiar de modo.
class AuthAnimatedEmailPhoneField extends StatelessWidget {
  const AuthAnimatedEmailPhoneField({
    super.key,
    required this.phoneMode,
    required this.emailController,
    required this.phoneController,
  });

  final bool phoneMode;
  final TextEditingController emailController;
  final TextEditingController phoneController;

  static const Duration _duration = Duration(milliseconds: 380);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: _duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
      child: phoneMode
          ? KeyedSubtree(
              key: const ValueKey('auth_identifier_phone'),
              child: AuthTextField(
                controller: phoneController,
                label: 'Número de celular',
                hint: '7XXXXXXX',
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.telephoneNumber],
                prefixText: '+591 ',
                prefixIcon: Icon(Icons.phone_android_rounded, color: scheme.onSurface.withValues(alpha: 0.45)),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 8,
                counterText: '',
                validator: AuthValidators.boliviaEightDigits,
              ),
            )
          : KeyedSubtree(
              key: const ValueKey('auth_identifier_email'),
              child: AuthTextField(
                controller: emailController,
                label: 'Correo electrónico',
                hint: 'tu@correo.com',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                prefixIcon: Icon(Icons.mail_outline_rounded, color: scheme.onSurface.withValues(alpha: 0.45)),
                validator: AuthValidators.emailOnly,
              ),
            ),
    );
  }
}
