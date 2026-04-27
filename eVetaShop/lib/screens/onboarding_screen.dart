import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String completedKey = 'eveta_onboarding_completed';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _controller;
  int _index = 0;
  static const int _last = 4;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.completedKey, true);
  }

  Future<void> _goLogin() async {
    await _markDone();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _goRegister() async {
    await _markDone();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/create-account');
  }

  void _skip() {
    _controller.animateToPage(
      _last,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_index >= _last) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLast = _index == _last;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  const SizedBox(width: 56),
                  Expanded(
                    child: Center(
                      child: _DotsIndicator(current: _index, count: _last + 1),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: isLast
                        ? null
                        : TextButton(
                            onPressed: _skip,
                            child: const Text(
                              'Saltar',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (v) => setState(() => _index = v),
                children: const [
                  _WelcomePage(),
                  _GenericPage(
                    title: 'Compra rápido',
                    subtitle: 'Encuentra productos y ordena en pocos toques.',
                    icon: Icons.shopping_bag_outlined,
                  ),
                  _GenericPage(
                    title: 'Entrega segura',
                    subtitle: 'Elige tu destino y te lo llevamos a donde estés.',
                    icon: Icons.local_shipping_outlined,
                  ),
                  _GenericPage(
                    title: 'Saldo eVeta',
                    subtitle: 'Recarga tu saldo y paga sin complicaciones.',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _FinalPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: isLast
                          ? FilledButton(
                              key: const ValueKey('create'),
                              onPressed: _goRegister,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Crear cuenta'),
                            )
                          : FilledButton(
                              key: const ValueKey('next'),
                              onPressed: _next,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Siguiente'),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _goLogin,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Iniciar sesión'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: SvgPicture.asset(
                'assets/images/telefono.svg',
                width: 240,
                height: 240,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Text(
            'Bienvenido a eVeta',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.08,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Compra, recarga tu saldo y recibe en tu destino.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class _GenericPage extends StatelessWidget {
  const _GenericPage({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, size: 92, color: scheme.primary),
              ),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class _FinalPage extends StatelessWidget {
  const _FinalPage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: 0.18),
                      scheme.primary.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
                ),
                child: Icon(Icons.verified_outlined, size: 98, color: scheme.primary),
              ),
            ),
          ),
          Text(
            'Listo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.08,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Crea tu cuenta o inicia sesión para continuar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({
    required this.current,
    required this.count,
  });

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) {
          final selected = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: selected ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: selected ? scheme.primary : scheme.outline.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(99),
            ),
          );
        },
      ),
    );
  }
}

