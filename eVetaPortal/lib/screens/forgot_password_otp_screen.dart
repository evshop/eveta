import 'package:flutter/material.dart';

import 'package:eveta_portal/services/portal_email_otp_service.dart';
import 'package:eveta_portal/widgets/portal/portal_auth_flow.dart';
import 'package:eveta_portal/widgets/portal/portal_notice.dart';
import 'package:eveta_portal/widgets/portal_auth_logo.dart';

import 'verify_email_code_screen.dart';

class ForgotPasswordOtpScreen extends StatefulWidget {
  const ForgotPasswordOtpScreen({super.key});

  @override
  State<ForgotPasswordOtpScreen> createState() => _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
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
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _emailCtrl.text.trim().toLowerCase();
      await PortalEmailOtpService.sendForgotPasswordCode(email);
      if (!mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (_, a, b) => FadeTransition(
            opacity: a,
            child: VerifyEmailCodeScreen(email: email),
          ),
        ),
      );
    } catch (e) {
      final msg = e is PortalOtpException ? e.message : 'No se pudo enviar el codigo.';
      setState(() => _error = msg);
      if (mounted) {
        showPortalNotice(context, msg, type: PortalNoticeType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar acceso'),
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
                        'Te enviaremos un codigo de 6 digitos',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Ingresa el correo de tu cuenta Portal para verificar primero que exista.',
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
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onFieldSubmitted: (_) => _sendCode(),
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Correo electronico',
                          hintText: 'tu@correo.com',
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Ingresa un correo';
                          if (!value.contains('@')) return 'Correo no valido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      PortalAuthGradientButton(
                        onPressed: _loading ? null : _sendCode,
                        loading: _loading,
                        label: 'Enviar codigo',
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
