import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:eveta_delivery/screens/delivery_login_screen.dart';
import 'package:eveta_delivery/screens/delivery_shell_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/env/app.env');
  await Supabase.initialize(
    url: dotenv.env['NEXT_PUBLIC_SUPABASE_URL']!,
    anonKey: dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY']!,
  );
  runApp(const EvetaDeliveryApp());
}

class EvetaDeliveryApp extends StatelessWidget {
  const EvetaDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'eDelivery',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemPink,
      ),
      home: _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final offlineDemo = (dotenv.env['DELIVERY_OFFLINE_DEMO'] ?? '').toLowerCase() == 'true';
    if (offlineDemo) {
      return const DeliveryShellScreen();
    }
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const DeliveryShellScreen();
        }
        return const DeliveryLoginScreen();
      },
    );
  }
}
