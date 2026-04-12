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

  static const Duration _duration = Duration(milliseconds: 400);

  static bool _isPhoneSlot(Widget child) {
    final k = child is KeyedSubtree ? child.key : null;
    return k is ValueKey<bool> && k.value == true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: AnimatedSize(
        duration: _duration,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
        duration: _duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            fit: StackFit.passthrough,
            clipBehavior: Clip.none,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final phone = _isPhoneSlot(child);
          final begin = phone ? const Offset(0.14, 0) : const Offset(-0.14, 0);
          final position = Tween<Offset>(begin: begin, end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          // Sin ClipRect: si no, la etiqueta flotante del InputDecoration se corta al animar.
          return SlideTransition(
            position: position,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            ),
          );
        },
        child: phoneMode
            ? KeyedSubtree(
                key: const ValueKey<bool>(true),
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
                key: const ValueKey<bool>(false),
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
        ),
      ),
    );
  }
}
