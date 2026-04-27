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
                    title: 'Paga con QR',
                    subtitle: 'Rapido, seguro y sin complicaciones.',
                    icon: Icons.qr_code_scanner_rounded,
                  ),
                  _GenericPage(
                    title: 'Miles de productos',
                    subtitle: 'Encuentra lo que buscas entre miles de opciones.',
                    icon: Icons.shopping_bag_rounded,
                  ),
                  _GenericPage(
                    title: 'Rapido, seguro y confiable',
                    subtitle: 'Tu compra protegida en cada paso.\nPagos seguros · Envios rapidos · Atencion confiable',
                    icon: Icons.verified_user_rounded,
                  ),
                  _FinalPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: isLast
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _goRegister,
                            child: const Text('Crear cuenta'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _goLogin,
                            child: const Text('Iniciar sesion'),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _next,
                        child: const Text('Continuar'),
                      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Column(
        children: [
          Expanded(
            flex: 62,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 90,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Compra en segundos.\nPaga con QR.',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF111827),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -42,
                    right: -42,
                    top: 74,
                    bottom: -120,
                    child: ClipRect(
                      child: SvgPicture.asset(
                        'assets/images/telefono.svg',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            flex: 38,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Text(
                    'Bienvenido a eVeta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 33,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins-Bold',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Todo lo que necesitas, en un solo lugar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 106, color: const Color(0xFF16A34A)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 31,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins-Bold',
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
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Center(
                child: Icon(
                  Icons.rocket_launch_rounded,
                  size: 120,
                  color: Color(0xFF22C55E),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '¡Comencemos!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 33,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins-Bold',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Crea tu cuenta o inicia sesion',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 15,
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
              color: selected ? const Color(0xFF22C55E) : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(99),
            ),
          );
        },
      ),
    );
  }
}
