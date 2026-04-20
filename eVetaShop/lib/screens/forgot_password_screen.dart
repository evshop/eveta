import 'package:flutter/material.dart';
import 'package:eveta/auth/auth_error_messages.dart';
import 'package:eveta/auth/auth_routes.dart';
import 'package:eveta/auth/auth_validators.dart';
import 'package:eveta/auth/widgets/auth_animated_email_phone_field.dart';
import 'package:eveta/auth/widgets/auth_flow_shell.dart';
import 'package:eveta/auth/widgets/auth_identifier_mode_switch.dart';
import 'package:eveta/auth/widgets/auth_login_logo.dart';
import 'package:eveta/screens/verify_code_screen.dart';
import 'package:eveta/utils/auth_service.dart';

/// Recuperación: correo → OTP por Gmail; teléfono → OTP SMS.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone8 = TextEditingController();
  bool _loading = false;
  bool _usePhone = false;
  String? _error;

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _anim.forward());
  }

  @override
  void dispose() {
    _anim.dispose();
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
        await AuthService.sendEmailOtp(
          email: raw,
          purpose: EmailOtpPurpose.passwordReset,
        );
        if (!mounted) return;
        await Navigator.push<void>(
          context,
          evetaAuthFadeRoute(
            VerifyCodeScreen(
              mode: VerifyMode.recoveryEmail,
              emailOrPhone: raw.toLowerCase(),
              isPhone: false,
            ),
          ),
        );
      } else {
        final err = AuthValidators.boliviaEightDigits(_phone8.text);
        if (err != null) {
          setState(() {
            _error = err;
            _loading = false;
          });
          return;
        }
        final phone = AuthValidators.e164FromEightDigits(_phone8.text);
        await AuthService.requestPhoneOtpRecovery(phone);
        if (!mounted) return;
        await Navigator.push<void>(
          context,
          evetaAuthFadeRoute(
            VerifyCodeScreen(
              mode: VerifyMode.recoveryPhone,
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
        title: const Text('Recuperar acceso'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: AuthFlowBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      const AuthLoginLogo(size: 72),
                      const SizedBox(height: 20),
                      Text(
                        '¿Olvidaste tu contraseña?',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Ingresa tu correo o número. Te enviaremos un código de 6 dígitos.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.75),
                            ),
                        textAlign: TextAlign.center,
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
                      const SizedBox(height: 20),
                      if (_error != null) ...[
                        authFlowErrorBanner(context, _error!),
                        const SizedBox(height: 16),
                      ],
                      AuthAnimatedEmailPhoneField(
                        phoneMode: _usePhone,
                        emailController: _email,
                        phoneController: _phone8,
                      ),
                      const SizedBox(height: 28),
                      AuthFlowGradientButton(
                        onPressed: _loading ? null : _send,
                        loading: _loading,
                        label: 'Enviar código',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
