import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import 'package:eveta_portal/services/portal_email_otp_service.dart';
import 'package:eveta_portal/widgets/portal/portal_notice.dart';

import 'reset_password_otp_screen.dart';

class VerifyEmailCodeScreen extends StatefulWidget {
  const VerifyEmailCodeScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailCodeScreen> createState() => _VerifyEmailCodeScreenState();
}

class _VerifyEmailCodeScreenState extends State<VerifyEmailCodeScreen> with TickerProviderStateMixin {
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

  Future<void> _verifyCode() async {
    final code = _pinController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Ingresa los 6 digitos del codigo.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resetToken = await PortalEmailOtpService.verifyForgotPasswordCode(
        email: widget.email,
        code: code,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ResetPasswordOtpScreen(
            email: widget.email,
            resetToken: resetToken,
          ),
        ),
      );
    } catch (e) {
      final is400 = e is PortalOtpException && e.statusCode == 400;
      if (is400) {
        _pinController.clear();
        _pinFocusNode.requestFocus();
        await _shakeController.forward(from: 0);
      }
      setState(() {
        _error = is400
            ? 'Codigo invalido. Intentalo de nuevo'
            : (e is PortalOtpException ? e.message : 'No se pudo verificar el codigo.');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await PortalEmailOtpService.sendForgotPasswordCode(widget.email);
      if (!mounted) return;
      showPortalNotice(context, 'Te reenviamos un nuevo codigo.', type: PortalNoticeType.success);
    } catch (e) {
      setState(() => _error = e is PortalOtpException ? e.message : 'No se pudo reenviar el codigo.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
    final focusedPinTheme = pinTheme.copyWith(
      decoration: focusedPinDecoration,
    );
    final submittedPinTheme = pinTheme.copyWith(
      decoration: basePinDecoration.copyWith(
        color: isDark ? const Color(0xFF1A2230) : Colors.grey.shade100,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Verificar codigo')),
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
            FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Codigo de verificacion',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Ingresa los 6 digitos que enviamos a ${widget.email}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.75),
                            ),
                      ),
                      const SizedBox(height: 26),
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
                          onCompleted: (_) => _verifyCode(),
                        ),
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
                      const Spacer(),
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
                          onPressed: _loading ? null : _verifyCode,
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
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _resending ? null : _resend,
                        child: _resending ? const Text('Reenviando...') : const Text('Reenviar codigo'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
