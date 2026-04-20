import 'package:flutter/material.dart';

import 'package:eveta_portal/services/portal_email_otp_service.dart';
import 'package:eveta_portal/widgets/portal/portal_auth_flow.dart';
import 'package:eveta_portal/widgets/portal_auth_logo.dart';

class ResetPasswordOtpScreen extends StatefulWidget {
  const ResetPasswordOtpScreen({
    super.key,
    required this.email,
    required this.resetToken,
  });

  final String email;
  final String resetToken;

  @override
  State<ResetPasswordOtpScreen> createState() => _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends State<ResetPasswordOtpScreen> with SingleTickerProviderStateMixin {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  final _formKey = GlobalKey<FormState>();
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

  String _friendlyError(Object e) {
    if (e is PortalOtpException) return e.message;
    final s = e.toString();
    return s.replaceFirst('AuthException(message: ', '').replaceFirst(')', '');
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PortalEmailOtpService.resetPassword(
        email: widget.email,
        resetToken: widget.resetToken,
        newPassword: _p1.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final scheme = Theme.of(ctx).colorScheme;
          return AlertDialog(
            backgroundColor: scheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF0EA866), size: 48),
            title: const Text('Listo'),
            content: const Text('Tu contraseña fue actualizada correctamente.'),
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA866),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva contraseña'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: PortalAuthFlowBackground(
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
                      const PortalAuthLogo(size: 72),
                      const SizedBox(height: 20),
                      Text(
                        'Define tu nueva contraseña',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Para la cuenta ${widget.email}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.75),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        portalAuthErrorBanner(context, _error!),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _p1,
                        obscureText: _ob1,
                        autofillHints: const [AutofillHints.newPassword],
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _ob1 = !_ob1),
                            icon: Icon(
                              _ob1 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: scheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                          if (v.length < 6) return 'Debe tener al menos 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _p2,
                        obscureText: _ob2,
                        autofillHints: const [AutofillHints.newPassword],
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: Icon(
                            Icons.lock_reset_rounded,
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _ob2 = !_ob2),
                            icon: Icon(
                              _ob2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: scheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Confirma la contraseña';
                          if (v != _p1.text) return 'Las contraseñas no coinciden';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      PortalAuthGradientButton(
                        onPressed: _loading ? null : _savePassword,
                        loading: _loading,
                        label: 'Guardar contraseña',
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
