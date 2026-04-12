import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:eveta/auth/auth_error_messages.dart';
import 'package:eveta/auth/auth_routes.dart';
import 'package:eveta/auth/auth_validators.dart';
import 'package:eveta/auth/widgets/auth_animated_email_phone_field.dart';
import 'package:eveta/auth/widgets/auth_identifier_mode_switch.dart';
import 'package:eveta/auth/widgets/auth_primary_button.dart';
import 'package:eveta/auth/widgets/auth_text_field.dart';
import 'package:eveta/screens/complete_profile_screen.dart';
import 'package:eveta/screens/create_new_password_screen.dart';
import 'package:eveta/screens/privacy_screen.dart';
import 'package:eveta/screens/terms_screen.dart';
import 'package:eveta/screens/verify_code_screen.dart';
import 'package:eveta/utils/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.initialIdentifier});

  /// Prefill desde login (correo o +591 + 8 dígitos).
  final String? initialIdentifier;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone8 = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _ob1 = true;
  bool _ob2 = true;
  bool _loading = false;
  bool _usePhone = false;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (!mounted) return;

      if (event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).push(
            evetaAuthFadeRoute(const CreateNewPasswordScreen()),
          );
        });
        return;
      }

      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        final needs = await AuthService.profileNeedsCompletion();
        if (!mounted) return;
        if (needs) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(builder: (_) => const CompleteProfileScreen()),
          );
        } else {
          await AuthService.persistSessionUser(AuthService.currentUserEmail ?? '');
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    });
    final id = widget.initialIdentifier?.trim();
    if (id != null && id.isNotEmpty) {
      if (AuthValidators.boliviaPhoneFull.hasMatch(id)) {
        _usePhone = true;
        _phone8.text = id.substring(4);
      } else if (id.startsWith('+591')) {
        final d = id.replaceAll(RegExp(r'\D'), '');
        if (d.length >= 11 && d.startsWith('591')) {
          final local = d.substring(3);
          if (local.length == 8) {
            _usePhone = true;
            _phone8.text = local;
          }
        }
      } else {
        final digitsOnly = id.replaceAll(RegExp(r'\D'), '');
        if (digitsOnly.length == 8 && !id.contains('@')) {
          _usePhone = true;
          _phone8.text = digitsOnly;
        } else if (AuthValidators.isEmail(id)) {
          _email.text = id;
        } else {
          _email.text = id;
        }
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _email.dispose();
    _phone8.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.signInWithGoogle();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyAuthError(e);
        });
      }
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_usePhone) {
        final raw = _email.text.trim();
        final res = await AuthService.registerEmailOnly(
          email: raw,
          password: _password.text,
        );
        if (!mounted) return;
        if (res.session != null) {
          await AuthService.persistSessionUser(raw.toLowerCase());
          final needs = await AuthService.profileNeedsCompletion();
          if (!mounted) return;
          if (needs) {
            Navigator.pushReplacement(
              context,
              evetaAuthFadeRoute(const CompleteProfileScreen()),
            );
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          try {
            await AuthService.resendSignupEmailOtp(raw);
          } catch (_) {}
          if (!mounted) return;
          await Navigator.push<void>(
            context,
            evetaAuthFadeRoute(
              VerifyCodeScreen(
                mode: VerifyMode.signupEmail,
                emailOrPhone: raw.toLowerCase(),
                isPhone: false,
              ),
            ),
          );
        }
      } else {
        final err = AuthValidators.boliviaEightDigits(_phone8.text);
        if (err != null) {
          setState(() => _error = err);
          return;
        }
        final phone = AuthValidators.e164FromEightDigits(_phone8.text);
        await AuthService.requestPhoneOtp(phone);
        if (!mounted) return;
        await Navigator.push<void>(
          context,
          evetaAuthFadeRoute(
            VerifyCodeScreen(
              mode: VerifyMode.signupPhone,
              emailOrPhone: phone,
              isPhone: true,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: scheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Empecemos', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 10),
                Text(
                  'Crea una cuenta con tu correo o número de teléfono.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 20),
                AuthIdentifierModeSwitch(
                  phoneMode: _usePhone,
                  onChanged: (phone) {
                    setState(() {
                      _usePhone = phone;
                      _error = null;
                    });
                  },
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
                  ),
                  const SizedBox(height: 16),
                ],
                AuthAnimatedEmailPhoneField(
                  phoneMode: _usePhone,
                  emailController: _email,
                  phoneController: _phone8,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _password,
                  label: 'Contraseña',
                  obscure: _ob1,
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: scheme.onSurface.withValues(alpha: 0.45)),
                  suffix: IconButton(
                    icon: Icon(_ob1 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _ob1 = !_ob1),
                  ),
                  validator: AuthValidators.password,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _confirm,
                  label: 'Confirmar contraseña',
                  obscure: _ob2,
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: scheme.onSurface.withValues(alpha: 0.45)),
                  suffix: IconButton(
                    icon: Icon(_ob2 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _ob2 = !_ob2),
                  ),
                  validator: (v) => AuthValidators.confirmPassword(_password.text, v),
                ),
                const SizedBox(height: 8),
                AuthGoogleButton(onPressed: _handleGoogleSignIn, loading: _loading),
                const SizedBox(height: 16),
                AuthPrimaryButton(label: 'Crear cuenta', onPressed: _signUp, loading: _loading),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.55), fontSize: 14),
                      children: [
                        const TextSpan(text: '¿Ya tienes cuenta? '),
                        TextSpan(
                          text: 'Iniciar sesión',
                          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5), fontSize: 12, height: 1.45),
                    children: [
                      const TextSpan(text: 'Al registrarte aceptas nuestros '),
                      TextSpan(
                        text: 'Términos',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(context, evetaAuthFadeRoute(const TermsScreen()));
                          },
                      ),
                      const TextSpan(text: ' y la '),
                      TextSpan(
                        text: 'Política de privacidad',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(context, evetaAuthFadeRoute(const PrivacyScreen()));
                          },
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
