import 'package:flutter/material.dart';
import 'package:eveta/auth/auth_validators.dart';
import 'package:eveta/auth/widgets/auth_animated_email_phone_field.dart';
import 'package:eveta/auth/widgets/auth_identifier_mode_switch.dart';
import 'package:eveta/auth/widgets/auth_primary_button.dart';
import 'package:eveta/screens/verify_code_screen.dart';
import 'package:eveta/utils/auth_service.dart';

/// Recuperación: correo → enlace de Supabase; teléfono → OTP SMS.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone8 = TextEditingController();
  bool _loading = false;
  bool _usePhone = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _phone8.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_usePhone) {
        final raw = _email.text.trim();
        await AuthService.sendPasswordResetEmail(raw);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revisa tu correo para el enlace de recuperación.')),
        );
        Navigator.pop(context);
      } else {
        final err = AuthValidators.boliviaEightDigits(_phone8.text);
        if (err != null) {
          setState(() => _error = err);
          return;
        }
        final phone = AuthValidators.e164FromEightDigits(_phone8.text);
        await AuthService.requestPhoneOtpRecovery(phone);
        if (!mounted) return;
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyCodeScreen(
              mode: VerifyMode.recoveryPhone,
              emailOrPhone: phone,
              isPhone: true,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = '$e');
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('¿Olvidaste tu contraseña?', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 12),
                Text(
                  'Ingresa tu correo o número de teléfono. Te enviaremos un enlace o un código por SMS.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
                const SizedBox(height: 24),
                AuthIdentifierModeSwitch(
                  phoneMode: _usePhone,
                  onChanged: (phone) {
                    setState(() {
                      _usePhone = phone;
                      _error = null;
                    });
                  },
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: scheme.error, fontSize: 14)),
                  const SizedBox(height: 16),
                ],
                AuthAnimatedEmailPhoneField(
                  phoneMode: _usePhone,
                  emailController: _email,
                  phoneController: _phone8,
                ),
                const SizedBox(height: 28),
                AuthPrimaryButton(label: 'Enviar', onPressed: _send, loading: _loading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
