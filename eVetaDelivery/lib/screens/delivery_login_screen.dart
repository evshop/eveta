import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'delivery_shell_screen.dart';
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
  void initState() {
    super.initState();
    final demoEmail = dotenv.env['DELIVERY_DEMO_EMAIL'];
    if (demoEmail != null && demoEmail.trim().isNotEmpty) {
      _emailController.text = demoEmail.trim();
    }
  }

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

  Future<void> _handleLogin() async {
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final offlineDemo = (dotenv.env['DELIVERY_OFFLINE_DEMO'] ?? '').toLowerCase() == 'true';
      if (offlineDemo) {
        final demoEmail = (dotenv.env['DELIVERY_DEMO_EMAIL'] ?? '').trim();
        final demoPass = (dotenv.env['DELIVERY_DEMO_PASSWORD'] ?? '');
        final email = _emailController.text.trim();
        final pass = _passwordController.text;
        if (demoEmail.isEmpty || demoPass.isEmpty) {
          throw const AuthException('Configura DELIVERY_DEMO_EMAIL y DELIVERY_DEMO_PASSWORD en app.env');
        }
        if (email.toLowerCase() != demoEmail.toLowerCase() || pass != demoPass) {
          throw const AuthException('Credenciales demo inválidas');
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute<void>(builder: (_) => const DeliveryShellScreen()),
        );
        return;
      }

      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final row = await Supabase.instance.client
          .from('profiles_delivery')
          .select('is_active')
          .eq('auth_user_id', Supabase.instance.client.auth.currentUser!.id)
          .maybeSingle();
      final ok = row != null && row['is_active'] == true;
      if (!ok) {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Esta cuenta no está vinculada a Delivery. Usa una cuenta Delivery separada.';
        });
        return;
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Error de conexión. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fillDemo() {
    final email = dotenv.env['DELIVERY_DEMO_EMAIL']?.trim();
    final pass = dotenv.env['DELIVERY_DEMO_PASSWORD'] ?? '';
    setState(() => _errorMessage = null);
    if (email != null && email.isNotEmpty) _emailController.text = email;
    if (pass.isNotEmpty) _passwordController.text = pass;
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
                      'Usa el correo y contraseña de tu cuenta eDelivery.',
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
                    const SizedBox(height: 10),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      onPressed: _isLoading ? null : _fillDemo,
                      child: Text(
                        'Usar cuenta demo',
                        style: theme.textTheme.textStyle.copyWith(
                          color: CupertinoColors.systemPink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tip: define DELIVERY_DEMO_EMAIL y DELIVERY_DEMO_PASSWORD en assets/env/app.env',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.textStyle.copyWith(
                        color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                        fontSize: 12,
                      ),
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
