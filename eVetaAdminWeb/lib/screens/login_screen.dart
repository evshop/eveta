import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings.dart';
import '../services/auth_service.dart';
import '../services/login_prefs.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin/eveta_glass_card.dart';
import '../widgets/admin/eveta_primary_button.dart';
import '../widgets/admin/eveta_admin_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.forceMessage});

  final String? forceMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _remember = true;
  String? _error;

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _error = widget.forceMessage;
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 680));
    _fade = CurvedAnimation(parent: _anim, curve: const Interval(0, 0.65, curve: Curves.easeOutCubic));
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _anim.forward());
  }

  Future<void> _loadPrefs() async {
    final p = await LoginPrefs.load();
    if (!mounted) return;
    if (p.remember && p.email != null && p.email!.isNotEmpty) {
      _emailController.text = p.email!;
      setState(() => _remember = true);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      await LoginPrefs.saveRememberedEmail(_emailController.text, _remember);
      final isAdmin = await AuthService.isCurrentUserAdmin();
      if (!isAdmin) {
        final hasProfile = await AuthService.currentUserProfileExists();
        await AuthService.signOut();
        setState(() {
          _error = hasProfile
              ? 'Tu cuenta no tiene permisos de administrador (profiles.is_admin = false).'
              : 'Tu cuenta autenticó, pero no existe perfil en la tabla profiles para este usuario. Debes crear la fila profiles(id=auth.uid()) y marcar is_admin=true.';
        });
      }
    } catch (e) {
      setState(() => _error = 'No se pudo iniciar sesión: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<AppSettings>();

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              AdminTokens.darkCanvas,
              const Color(0xFF12121A),
              scheme.primary.withValues(alpha: 0.08),
            ]
          : [
              const Color(0xFFE8F8F0),
              const Color(0xFFF6F7F9),
              Colors.white,
            ],
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: const SizedBox(),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Tema',
                                onPressed: () => settings.cycleTheme(),
                                icon: Icon(
                                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          EvetaBackdropCard(
                            radius: AdminTokens.radiusLg,
                            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'eVeta',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.8,
                                      color: scheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Panel de administración',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  if (_error != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: scheme.error.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
                                        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
                                      ),
                                      child: Text(
                                        _error!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: scheme.error,
                                          fontWeight: FontWeight.w500,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                  ],
                                  EvetaAdminTextField(
                                    controller: _emailController,
                                    label: 'Correo electrónico',
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: Icons.mail_outline_rounded,
                                    autofillHints: const [AutofillHints.email],
                                    validator: (v) =>
                                        (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  EvetaAdminTextField(
                                    controller: _passwordController,
                                    label: 'Contraseña',
                                    obscure: _obscure,
                                    prefixIcon: Icons.lock_outline_rounded,
                                    autofillHints: const [AutofillHints.password],
                                    suffix: IconButton(
                                      tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                                  ),
                                  const SizedBox(height: 8),
                                  CheckboxListTile(
                                    value: _remember,
                                    onChanged: (v) => setState(() => _remember = v ?? true),
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    title: Text(
                                      'Recordarme en este dispositivo',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  EvetaPrimaryButton(
                                    label: 'Entrar',
                                    loading: _loading,
                                    onPressed: _loading ? null : _submit,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Acceso restringido a cuentas administrador.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
