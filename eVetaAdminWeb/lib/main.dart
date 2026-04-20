import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/app_settings.dart';
import 'screens/admin_shell_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'theme/admin_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['NEXT_PUBLIC_SUPABASE_URL']!,
    anonKey: dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY']!,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: const AdminWebApp(),
    ),
  );
}

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return MaterialApp(
      title: 'eVeta Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminLightTheme(),
      darkTheme: buildAdminDarkTheme(),
      themeMode: settings.themeMode,
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final user = Supabase.instance.client.auth.currentUser;
          if (user == null) return const LoginScreen();
          return FutureBuilder<bool>(
            future: AuthService.isCurrentUserAdmin(),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (adminSnapshot.data == true) return const AdminShellScreen();
              return const LoginScreen(
                forceMessage: 'Tu cuenta no tiene permisos de administrador.',
              );
            },
          );
        },
      ),
    );
  }
}
