import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eveta/auth/widgets/auth_primary_button.dart';
import 'package:eveta/screens/complete_profile_screen.dart';
import 'package:eveta/screens/create_new_password_screen.dart';
import 'package:eveta/utils/auth_service.dart';

enum VerifyMode { signupEmail, signupPhone, recoveryPhone }

class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({
    super.key,
    required this.mode,
    required this.emailOrPhone,
    required this.isPhone,
  });

  final VerifyMode mode;
  final String emailOrPhone;
  final bool isPhone;

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final List<TextEditingController> _digits = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focus = List.generate(4, (_) => FocusNode());
  bool _loading = false;
  String? _error;
  bool _useSix = false;
  final _sixCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in _digits) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    _sixCtrl.dispose();
    super.dispose();
  }

  String get _code {
    if (_useSix) return _sixCtrl.text.trim();
    return _digits.map((c) => c.text).join();
  }

  Future<void> _verify() async {
    final code = _code;
    if (!_useSix && code.length != 4) {
      setState(() => _error = 'Ingresa el código de 4 dígitos');
      return;
    }
    if (_useSix && (code.length < 4 || code.length > 8)) {
      setState(() => _error = 'Ingresa el código que recibiste');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.isPhone) {
        await AuthService.verifyPhoneOtp(phoneE164: widget.emailOrPhone, token: code);
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
        await AuthService.verifySignupEmailOtp(email: widget.emailOrPhone, token: code);
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
      }
    } catch (e) {
      setState(() => _error = 'Código no válido. Prueba de nuevo o usa el modo de más dígitos si tu código es más largo.');
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
        await AuthService.resendSignupEmailOtp(widget.emailOrPhone);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código reenviado.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 3) {
      _focus[index + 1].requestFocus();
    }
    setState(() => _error = null);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isPhone ? 'Verifica tu celular' : 'Verifica tu correo',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                widget.isPhone
                    ? 'Ingresa el código que enviamos por SMS.'
                    : 'Ingresa el código que enviamos a tu correo.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
              ),
              const SizedBox(height: 36),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: scheme.error)),
                const SizedBox(height: 16),
              ],
              if (!_useSix)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (i) {
                    return SizedBox(
                      width: 64,
                      child: TextField(
                        controller: _digits[i],
                        focusNode: _focus[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: scheme.surface,
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (v) => _onDigitChanged(i, v),
                      ),
                    );
                  }),
                )
              else
                TextField(
                  controller: _sixCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: 'Código (4–8 dígitos)',
                    counterText: '',
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              TextButton(
                onPressed: () => setState(() {
                  _useSix = !_useSix;
                  _error = null;
                }),
                child: Text(_useSix ? 'Usar 4 casillas' : 'Mi código tiene más dígitos'),
              ),
              const SizedBox(height: 24),
              AuthPrimaryButton(label: 'Verificar', onPressed: _verify, loading: _loading),
              const SizedBox(height: 12),
              TextButton(onPressed: _resend, child: const Text('Reenviar código')),
            ],
          ),
        ),
      ),
    );
  }
}
