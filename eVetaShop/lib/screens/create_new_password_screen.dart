import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eveta/auth/auth_validators.dart';
import 'package:eveta/auth/widgets/auth_flow_shell.dart';
import 'package:eveta/auth/widgets/auth_login_logo.dart';
import 'package:eveta/auth/widgets/auth_text_field.dart';
import 'package:eveta/utils/auth_service.dart';

class CreateNewPasswordScreen extends StatefulWidget {
  const CreateNewPasswordScreen({
    super.key,
    this.phoneForSignupProfile,
    this.emailForOtpReset,
    this.emailOtpResetToken,
  });

  /// Si viene de registro por SMS, guarda perfil con teléfono. Si es null, solo cambia contraseña (recovery / email link).
  final String? phoneForSignupProfile;
  final String? emailForOtpReset;
  final String? emailOtpResetToken;

  @override
  State<CreateNewPasswordScreen> createState() => _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _ob1 = true;
  bool _ob2 = true;
  bool _loading = false;
  String? _error;

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _anim.forward());
  }

  @override
  void dispose() {
    _anim.dispose();
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.phoneForSignupProfile != null) {
        await AuthService.finalizePhoneSignup(
          phoneE164: widget.phoneForSignupProfile!,
          password: _p1.text,
        );
      } else if (widget.emailForOtpReset != null && widget.emailOtpResetToken != null) {
        await AuthService.completeEmailOtpPasswordReset(
          email: widget.emailForOtpReset!,
          resetToken: widget.emailOtpResetToken!,
          newPassword: _p1.text,
        );
        await AuthService.signInWithEmail(
          email: widget.emailForOtpReset!,
          password: _p1.text,
        );
      } else {
        await AuthService.updatePassword(_p1.text);
      }
      final email = AuthService.currentUserEmail;
      if (email != null) {
        await AuthService.persistSessionUser(email);
      } else if (widget.phoneForSignupProfile != null) {
        await AuthService.persistSessionUser(widget.phoneForSignupProfile!);
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } catch (e) {
      if (e is AuthException) {
        setState(() => _error = e.message);
      } else {
        setState(() => _error = 'No se pudo guardar. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final email = widget.emailForOtpReset?.trim().toLowerCase();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: scheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Nueva contraseña'),
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
                        'Define tu contraseña',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      if (email != null && email.isNotEmpty) ...[
                        Text(
                          'Cuenta: $email',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        'Elige una contraseña segura para tu cuenta.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.75),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        authFlowErrorBanner(context, _error!),
                        const SizedBox(height: 16),
                      ],
                      AuthTextField(
                        controller: _p1,
                        label: 'Nueva contraseña',
                        obscure: _ob1,
                        autofillHints: const [AutofillHints.newPassword],
                        prefixIcon: Icon(Icons.lock_outline_rounded, color: scheme.onSurface.withValues(alpha: 0.45)),
                        suffix: IconButton(
                          icon: Icon(_ob1 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _ob1 = !_ob1),
                        ),
                        validator: AuthValidators.password,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: _p2,
                        label: 'Confirmar contraseña',
                        obscure: _ob2,
                        autofillHints: const [AutofillHints.newPassword],
                        prefixIcon: Icon(Icons.lock_reset_rounded, color: scheme.onSurface.withValues(alpha: 0.45)),
                        suffix: IconButton(
                          icon: Icon(_ob2 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _ob2 = !_ob2),
                        ),
                        validator: (v) => AuthValidators.confirmPassword(_p1.text, v),
                      ),
                      const SizedBox(height: 28),
                      AuthFlowGradientButton(
                        onPressed: _loading ? null : _save,
                        loading: _loading,
                        label: 'Guardar',
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
