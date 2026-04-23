import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['NEXT_PUBLIC_SUPABASE_URL']!,
    anonKey: dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY']!,
  );
  runApp(const ScannerApp());
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'eVeta Scanner',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF22C55E)),
      ),
      home: const ScannerHomeScreen(),
    );
  }
}

class ScannerHomeScreen extends StatefulWidget {
  const ScannerHomeScreen({super.key});

  @override
  State<ScannerHomeScreen> createState() => _ScannerHomeScreenState();
}

class _ScannerHomeScreenState extends State<ScannerHomeScreen> {
  String? _lastToken;
  Map<String, dynamic>? _ticket;
  bool _loading = false;
  String? _error;

  Future<void> _loadState(String token) async {
    if (_loading || token.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client.rpc('get_ticket_scan_state', params: {
        'p_qr_token': token.trim(),
      });
      final data = List<Map<String, dynamic>>.from(rows as List);
      if (data.isEmpty) {
        setState(() => _error = 'Ticket no encontrado');
      } else {
        setState(() {
          _lastToken = token.trim();
          _ticket = data.first;
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerEntry() async {
    if (_lastToken == null) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.rpc('consume_ticket_entry', params: {
        'p_qr_token': _lastToken,
        'p_quantity': 1,
      });
      await _loadState(_lastToken!);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redeemBenefit(String type) async {
    if (_lastToken == null) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.rpc('consume_ticket_benefit', params: {
        'p_qr_token': _lastToken,
        'p_benefit_type': type,
        'p_quantity': 1,
      });
      await _loadState(_lastToken!);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final benefits = (_ticket?['benefits'] as List?)?.cast<Map>() ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner Staff')),
      body: Column(
        children: [
          SizedBox(
            height: 280,
            child: MobileScanner(
              onDetect: (capture) {
                final raw = capture.barcodes.first.rawValue;
                if (raw != null && raw != _lastToken) {
                  _loadState(raw);
                }
              },
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 3),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                  ),
                if (_ticket != null) ...[
                  Text(
                    _ticket!['event_name']?.toString() ?? 'Evento',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text('Cliente: ${_ticket!['owner_name'] ?? 'N/D'}'),
                  const SizedBox(height: 6),
                  Text(
                    'Personas: ${_ticket!['used_people']}/${_ticket!['people_count']}',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _registerEntry,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Registrar entrada'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Beneficios', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...benefits.map((item) {
                    final state = item['state']?.toString() ?? 'blocked';
                    final color = switch (state) {
                      'active' => Colors.green,
                      'complete' => Colors.blueGrey,
                      _ => Colors.grey,
                    };
                    return Card(
                      child: ListTile(
                        title: Text('${item['type']} (${item['used']}/${item['total']})'),
                        subtitle: Text('Estado: $state'),
                        trailing: FilledButton(
                          onPressed: state == 'active' && !_loading
                              ? () => _redeemBenefit(item['type'].toString())
                              : null,
                          style: FilledButton.styleFrom(backgroundColor: color),
                          child: const Text('Canjear'),
                        ),
                      ),
                    );
                  }),
                ] else
                  const Text('Escanea un QR para ver estado del ticket.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
