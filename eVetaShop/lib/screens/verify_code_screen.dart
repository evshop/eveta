import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:eveta/auth/auth_routes.dart';
import 'package:eveta/auth/widgets/auth_flow_shell.dart';
import 'package:eveta/auth/widgets/auth_login_logo.dart';
import 'package:eveta/screens/complete_profile_screen.dart';
import 'package:eveta/screens/create_new_password_screen.dart';
import 'package:eveta/utils/auth_service.dart';

enum VerifyMode { signupEmail, signupPhone, recoveryPhone, recoveryEmail }

class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({
    super.key,
    required this.mode,
    required this.emailOrPhone,
    required this.isPhone,
    this.signupPassword,
  });

  final VerifyMode mode;
  final String emailOrPhone;
  final bool isPhone;
  final String? signupPassword;

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> with TickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  bool _loading = false;
  bool _resending = false;
  String? _error;

  late final AnimationController _entryController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final AnimationController _shakeController;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _fade = CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 2),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _entryController.forward());
  }

  @override
  void dispose() {
    _entryController.dispose();
    _shakeController.dispose();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  String get _code => _pinController.text.trim();

  Future<void> _verify() async {
    if (_code.length != 6) {
      setState(() => _error = 'Ingresa el código de 6 dígitos');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.isPhone) {
        await AuthService.verifyPhoneOtp(phoneE164: widget.emailOrPhone, token: _code);
        if (!mounted) return;
        if (widget.mode == VerifyMode.signupPhone) {
          await Navigator.of(context).pushReplacement(
            evetaAuthFadeRoute(
              CreateNewPasswordScreen(phoneForSignupProfile: widget.emailOrPhone),
            ),
          );
        } else if (widget.mode == VerifyMode.recoveryPhone) {
          await Navigator.of(context).pushReplacement(
            evetaAuthFadeRoute(const CreateNewPasswordScreen()),
          );
        }
      } else {
        if (widget.mode == VerifyMode.signupEmail) {
          await AuthService.verifySignupEmailOtp(
            email: widget.emailOrPhone,
            token: _code,
          );
          if (widget.signupPassword != null && widget.signupPassword!.isNotEmpty) {
            await AuthService.signInWithEmail(
              email: widget.emailOrPhone,
              password: widget.signupPassword!,
            );
          }
          if (!mounted) return;
          await AuthService.persistSessionUser(widget.emailOrPhone);
          if (!mounted) return;
          final needs = await AuthService.profileNeedsCompletion();
          if (!mounted) return;
          if (needs) {
            Navigator.of(context).pushAndRemoveUntil(
              evetaAuthFadeRoute(const CompleteProfileScreen()),
              (_) => false,
            );
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
          }
        } else {
          final result = await AuthService.verifyEmailOtp(
            email: widget.emailOrPhone,
            token: _code,
            purpose: EmailOtpPurpose.passwordReset,
          );
          final resetToken = result['reset_token']?.toString();
          if (resetToken == null || resetToken.isEmpty) {
            throw AuthException('No se recibió token de restablecimiento.');
          }
          if (!mounted) return;
          await Navigator.of(context).pushReplacement(
            evetaAuthFadeRoute(
              CreateNewPasswordScreen(
                emailForOtpReset: widget.emailOrPhone,
                emailOtpResetToken: resetToken,
              ),
            ),
          );
        }
      }
    } catch (e) {
      _pinController.clear();
      _pinFocusNode.requestFocus();
      await _shakeController.forward(from: 0);
      setState(() => _error = 'Código no válido. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      if (widget.isPhone) {
        if (widget.mode == VerifyMode.recoveryPhone) {
          await AuthService.requestPhoneOtpRecovery(widget.emailOrPhone);
        } else {
          await AuthService.requestPhoneOtp(widget.emailOrPhone);
        }
      } else {
        if (widget.mode == VerifyMode.recoveryEmail) {
          await AuthService.sendEmailOtp(
            email: widget.emailOrPhone,
            purpose: EmailOtpPurpose.passwordReset,
          );
        } else {
          await AuthService.resendSignupEmailOtp(widget.emailOrPhone);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Text(
              widget.isPhone ? 'Código reenviado por SMS.' : 'Código reenviado a ${widget.emailOrPhone}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: const Text('No se pudo reenviar. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emailLower = widget.emailOrPhone.trim().toLowerCase();

    final basePinDecoration = BoxDecoration(
      color: isDark ? const Color(0xFF1A1D24) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5), width: 1.1),
    );
    final focusedPinDecoration = BoxDecoration(
      color: isDark ? const Color(0xFF1B2332) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF4A90E2), width: 1.4),
    );
    final pinTheme = PinTheme(
      width: 50,
      height: 58,
      textStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      decoration: basePinDecoration,
    );
    final focusedPinTheme = pinTheme.copyWith(decoration: focusedPinDecoration);
    final submittedPinTheme = pinTheme.copyWith(
      decoration: basePinDecoration.copyWith(
        color: isDark ? const Color(0xFF1A2230) : Colors.grey.shade100,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: scheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Verificar código'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          const AuthLoginLogo(size: 72),
                          const SizedBox(height: 20),
                          Text(
                            widget.isPhone ? 'Verifica tu celular' : 'Código de verificación',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.isPhone
                                ? 'Ingresa el código de 6 dígitos enviado por SMS.'
                                : 'Ingresa el código de 6 dígitos que enviamos a:',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.75),
                                ),
                            textAlign: TextAlign.center,
                          ),
                          if (!widget.isPhone) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                emailLower,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          AnimatedBuilder(
                            animation: _shakeController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_shake.value, 0),
                                child: child,
                              );
                            },
                            child: Pinput(
                              controller: _pinController,
                              focusNode: _pinFocusNode,
                              length: 6,
                              defaultPinTheme: pinTheme,
                              focusedPinTheme: focusedPinTheme,
                              submittedPinTheme: submittedPinTheme,
                              keyboardType: TextInputType.number,
                              autofocus: true,
                              pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onCompleted: (_) => _verify(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_error != null) authFlowErrorBanner(context, _error!),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthFlowGradientButton(
                          onPressed: _loading ? null : _verify,
                          loading: _loading,
                          label: 'Verificar',
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: _resending ? null : _resend,
                          child: Text(
                            _resending ? 'Reenviando…' : 'Reenviar código',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
