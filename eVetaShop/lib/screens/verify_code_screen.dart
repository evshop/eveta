import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  String get _code => _pinController.text.trim();

  Future<void> _verify() async {
    if (_code.length != 6) {
      setState(() => _error = 'Ingresa el codigo de 6 digitos');
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
            MaterialPageRoute<void>(
              builder: (_) => CreateNewPasswordScreen(phoneForSignupProfile: widget.emailOrPhone),
            ),
          );
        } else if (widget.mode == VerifyMode.recoveryPhone) {
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const CreateNewPasswordScreen()),
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
              MaterialPageRoute<void>(builder: (_) => const CompleteProfileScreen()),
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
            MaterialPageRoute<void>(
              builder: (_) => CreateNewPasswordScreen(
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
      setState(() => _error = 'Codigo no valido. Intentalo de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
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
            content: Text(
              widget.isPhone ? 'Codigo reenviado por SMS.' : 'Codigo reenviado a ${widget.emailOrPhone}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('No se pudo reenviar. Intenta de nuevo.'),
          ),
        );
      }
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
      width: 48,
      height: 56,
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
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF111318), const Color(0xFF171A20), const Color(0xFF1B2028)]
                        : [const Color(0xFFF7F8FA), const Color(0xFFFFFFFF), const Color(0xFFF3F5F8)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: const SizedBox(),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    widget.isPhone ? 'Verifica tu celular' : 'Codigo de verificacion',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.isPhone
                        ? 'Ingresa el codigo de 6 digitos enviado por SMS.'
                        : 'Ingresa el codigo de 6 digitos que enviamos a:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.72),
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
                  Pinput(
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
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _error == null
                        ? const SizedBox(height: 20)
                        : Text(
                            _error!,
                            key: ValueKey(_error),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF17C17A), Color(0xFF0EA866)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B86F).withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _loading ? null : _verify,
                      child: _loading
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : const Text(
                              'Verificar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _resend, child: const Text('Reenviar codigo')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
