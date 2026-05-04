import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'services/portal_auth_gate.dart';
import 'theme/eveta_shop_theme.dart';
import 'theme/eveta_theme_controller.dart';

/// Temas con fuente aplicada una sola vez al arranque (evita trabajo extra en cada rebuild).
late final ThemeData evetaPortalLightTheme;
late final ThemeData evetaPortalDarkTheme;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['NEXT_PUBLIC_SUPABASE_URL']!,
    anonKey: dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY']!,
  );

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  await loadEvetaThemeMode();

  final lightBase = EvetaShopTheme.light();
  final darkBase = EvetaShopTheme.dark();
  evetaPortalLightTheme = lightBase.copyWith(
    textTheme: GoogleFonts.interTextTheme(lightBase.textTheme),
  );
  evetaPortalDarkTheme = darkBase.copyWith(
    textTheme: GoogleFonts.interTextTheme(darkBase.textTheme),
  );

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: evetaThemeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'eVeta Portal',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: evetaPortalLightTheme,
          darkTheme: evetaPortalDarkTheme,
          home: _PortalAuthGate(initiallyLoggedIn: isLoggedIn),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const MainNavigation(),
          },
          builder: (context, child) {
            return SlidableAutoCloseBehavior(
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.0),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        );
      },
    );
  }
}

class _PortalAuthGate extends StatefulWidget {
  const _PortalAuthGate({required this.initiallyLoggedIn});

  final bool initiallyLoggedIn;

  @override
  State<_PortalAuthGate> createState() => _PortalAuthGateState();
}

class _PortalAuthGateState extends State<_PortalAuthGate> {
  bool _checking = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _verifyInitial();
  }

  Future<void> _verifyInitial() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // Si no hay sesión, limpia bandera local y manda a login.
      if (widget.initiallyLoggedIn) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('isLoggedIn');
        await prefs.remove('userEmail');
        await prefs.remove('isAdmin');
        await prefs.remove('isSeller');
      }
      if (!mounted) return;
      setState(() {
        _checking = false;
        _allowed = false;
      });
      return;
    }
    final gate = await PortalAuthGate.verifyCurrentSession();
    if (!mounted) return;
    if (!gate.allowed) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('userEmail');
      await prefs.remove('isAdmin');
      await prefs.remove('isSeller');
    } else {
      final prefs = await SharedPreferences.getInstance();
      final profile = gate.profile ?? const <String, dynamic>{};
      await prefs.setBool('isLoggedIn', true);
      await prefs.setBool('isAdmin', profile['is_admin'] == true);
      await prefs.setBool('isSeller', profile['is_seller'] == true);
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _allowed = gate.allowed;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: scheme.primary)),
      );
    }
    return _allowed ? const MainNavigation() : const LoginScreen();
  }
}
