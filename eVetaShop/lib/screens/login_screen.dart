import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:eveta/auth/auth_error_messages.dart';
import 'package:eveta/auth/auth_routes.dart';
import 'package:eveta/auth/auth_validators.dart';
import 'package:eveta/auth/widgets/auth_animated_email_phone_field.dart';
import 'package:eveta/auth/widgets/auth_identifier_mode_switch.dart';
import 'package:eveta/auth/widgets/auth_login_logo.dart';
import 'package:eveta/auth/widgets/auth_primary_button.dart';
import 'package:eveta/auth/widgets/auth_text_field.dart';
import 'package:eveta/screens/complete_profile_screen.dart';
import 'package:eveta/screens/create_new_password_screen.dart';
import 'package:eveta/screens/forgot_password_screen.dart';
import 'package:eveta/screens/privacy_screen.dart';
import 'package:eveta/screens/register_screen.dart';
import 'package:eveta/screens/terms_screen.dart';
import 'package:eveta/utils/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _phone8Controller = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _usePhone = false;
  String? _errorMessage;
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
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _phone8Controller.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final password = _passwordController.text;

    try {
      if (!_usePhone) {
        final email = _emailController.text.trim();
        await AuthService.signInWithEmail(email: email, password: password);
      } else {
        final phone = AuthValidators.e164FromEightDigits(_phone8Controller.text);
        if (!AuthValidators.boliviaPhoneFull.hasMatch(phone)) {
          setState(() => _errorMessage = 'Correo o teléfono no válido.');
          return;
        }
        final profile = await AuthService.findProfileByIdentifier(phone);
        if (profile == null) {
          if (!mounted) return;
          Navigator.push(
            context,
            evetaAuthFadeRoute(RegisterScreen(initialIdentifier: phone)),
          );
          return;
        }

        final email = profile['email']?.toString();
        if (email == null || email.isEmpty) {
          setState(() => _errorMessage = 'La cuenta no tiene correo vinculado.');
          return;
        }
        await AuthService.signInWithEmail(email: email, password: password);
      }
    } catch (e) {
      setState(() => _errorMessage = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AuthService.signInWithGoogle();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = friendlyAuthError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const AuthLoginLogo(size: 88),
                const SizedBox(height: 28),
                Text(
                  'Hola, bienvenido de nuevo',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Inicia sesión con tu correo o número de teléfono.',
                  textAlign: TextAlign.center,
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
                      _errorMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: scheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: scheme.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                AuthAnimatedEmailPhoneField(
                  phoneMode: _usePhone,
                  emailController: _emailController,
                  phoneController: _phone8Controller,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _passwordController,
                  label: 'Contraseña',
                  obscure: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: scheme.onSurface.withValues(alpha: 0.45)),
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: scheme.onSurface.withValues(alpha: 0.45),
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: AuthValidators.password,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.push(context, evetaAuthFadeRoute(const ForgotPasswordScreen())),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
                const SizedBox(height: 8),
                AuthGoogleButton(onPressed: _handleGoogleSignIn, loading: _isLoading),
                const SizedBox(height: 16),
                AuthPrimaryButton(label: 'Iniciar sesión', onPressed: _handleLogin, loading: _isLoading),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.push(context, evetaAuthFadeRoute(const RegisterScreen())),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.55), fontSize: 14),
                      children: [
                        const TextSpan(text: '¿No tienes cuenta? '),
                        TextSpan(
                          text: 'Regístrate',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _TermsRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5), fontSize: 12, height: 1.45),
        children: [
          const TextSpan(text: 'Al continuar aceptas nuestros '),
          TextSpan(
            text: 'Términos',
            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Navigator.push(context, evetaAuthFadeRoute(const TermsScreen()));
              },
          ),
          const TextSpan(text: ' y la '),
          TextSpan(
            text: 'Política de privacidad',
            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Navigator.push(context, evetaAuthFadeRoute(const PrivacyScreen()));
              },
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
