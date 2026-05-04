import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:eveta_delivery/screens/delivery_login_screen.dart';
import 'package:eveta_delivery/screens/delivery_shell_screen.dart';
import 'package:eveta_delivery/services/delivery_auth_gate.dart';

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

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _checking = true;
  bool _allowed = false;
  StreamSubscription<AuthState>? _sub;

  bool get _offlineDemo =>
      (dotenv.env['DELIVERY_OFFLINE_DEMO'] ?? '').toLowerCase() == 'true';

  @override
  void initState() {
    super.initState();
    if (_offlineDemo) {
      _checking = false;
      _allowed = true;
      return;
    }
    _verifyInitial();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        if (mounted) {
          setState(() {
            _checking = false;
            _allowed = false;
          });
        }
      } else {
        _verifyInitial();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _verifyInitial() async {
    if (_offlineDemo) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (mounted) {
        setState(() {
          _checking = false;
          _allowed = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _checking = true);
    final gate = await DeliveryAuthGate.verifyCurrentSession();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _allowed = gate.allowed;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_offlineDemo) {
      return const DeliveryShellScreen();
    }
    if (_checking) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator(radius: 14)),
      );
    }
    if (_allowed) {
      return const DeliveryShellScreen();
    }
    return const DeliveryLoginScreen();
  }
}
