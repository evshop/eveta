import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/delivery_auth_gate.dart';
import '../widgets/delivery_auth_logo.dart';

class DeliveryLoginScreen extends StatefulWidget {
  const DeliveryLoginScreen({super.key});

  @override
  State<DeliveryLoginScreen> createState() => _DeliveryLoginScreenState();
}

class _DeliveryLoginScreenState extends State<DeliveryLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Ingresa tu correo');
      return false;
    }
    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Correo no válido');
      return false;
    }
    if (pass.isEmpty) {
      setState(() => _errorMessage = 'Ingresa tu contraseña');
      return false;
    }
    return true;
  }

  String _toDeliveryAuthEmail(String value) {
    final e = value.trim().toLowerCase();
    final at = e.indexOf('@');
    if (at <= 0 || at == e.length - 1) return e;
    final local = e.substring(0, at);
    final domain = e.substring(at + 1);
    final baseLocal = local.contains('+') ? local.split('+').first : local;
    return '$baseLocal+delivery@$domain';
  }

  Future<void> _handleLogin() async {
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authEmail = _toDeliveryAuthEmail(_emailController.text);
      await Supabase.instance.client.auth.signInWithPassword(
        email: authEmail,
        password: _passwordController.text,
      );

      final gate = await DeliveryAuthGate.verifyCurrentSession();
      if (!gate.allowed) {
        if (!mounted) return;
        setState(() {
          _errorMessage = gate.errorMessage ??
              'Esta cuenta no está vinculada a Delivery. Usa una cuenta Delivery separada.';
        });
        return;
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } on SocketException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Sin conexión a Internet o no se puede resolver el servidor. '
              'Revisa Wi‑Fi/datos y que en assets/env/app.env la URL de Supabase '
              'sea exactamente https://TU_REF.supabase.co sin espacios.\n(${e.message})';
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        final isDns = msg.contains('Failed host lookup') ||
            msg.contains('No address associated with hostname');
        setState(() {
          _errorMessage = isDns
              ? 'No se pudo contactar a Supabase (DNS). Revisa la red y la URL en app.env; '
                  'si copiaste el .env, asegúrate de que no haya espacios dentro de la URL.'
              : 'Error de conexión: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final bg = theme.scaffoldBackgroundColor;

    return CupertinoPageScaffold(
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('Iniciar sesión'),
              backgroundColor: bg.withAlpha(210),
              border: const Border(
                bottom: BorderSide(color: CupertinoColors.separator, width: 0.0),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(child: DeliveryAuthLogo(size: 84)),
                    const SizedBox(height: 16),
                    Text(
                      'Hola, repartidor',
                      style: theme.textTheme.navLargeTitleTextStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ingresa el mismo correo y contraseña del repartidor que creaste desde eVeta Admin (web).',
                      style: theme.textTheme.textStyle.copyWith(
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemRed.withAlpha(24),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: CupertinoColors.systemRed.withAlpha(60),
                            width: 0.6,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.exclamationmark_circle,
                              color: CupertinoColors.systemRed,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: theme.textTheme.textStyle.copyWith(
                                  color: CupertinoColors.systemRed,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _CupertinoInputGroup(
                      children: [
                        CupertinoTextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          placeholder: 'Correo electrónico',
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Icon(CupertinoIcons.mail, size: 18),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() => _errorMessage = null),
                        ),
                        CupertinoTextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          placeholder: 'Contraseña',
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Icon(CupertinoIcons.lock, size: 18),
                          ),
                          suffix: CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            minimumSize: Size.zero,
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            child: Icon(
                              _obscurePassword
                                  ? CupertinoIcons.eye_slash
                                  : CupertinoIcons.eye,
                              size: 18,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleLogin(),
                          onChanged: (_) => setState(() => _errorMessage = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            color: CupertinoColors.systemPink,
                            borderRadius: BorderRadius.circular(16),
                            onPressed: _isLoading ? null : _handleLogin,
                            child: _isLoading
                                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                                : const Text('Entrar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CupertinoInputGroup extends StatelessWidget {
  const _CupertinoInputGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context).withAlpha(220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context).withAlpha(90),
          width: 0.6,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                Container(
                  height: 0.6,
                  color: CupertinoColors.separator.resolveFrom(context).withAlpha(90),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
