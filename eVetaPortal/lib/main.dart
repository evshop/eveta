import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
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
          initialRoute: isLoggedIn ? '/home' : '/login',
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
