import 'package:eveta/utils/tickets_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  late Future<List<Map<String, dynamic>>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _ticketsFuture = TicketsService.getMyTickets();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis entradas')),
      backgroundColor: scheme.surface,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudieron cargar tus entradas.'));
          }
          final tickets = snapshot.data ?? const [];
          if (tickets.isEmpty) {
            return const Center(child: Text('Aún no tienes entradas compradas.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final t = tickets[i];
              final event = (t['events'] as Map?)?.cast<String, dynamic>() ?? const {};
              final benefits = (t['ticket_benefits'] as List?)?.cast<Map>() ?? const [];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['name']?.toString() ?? 'Evento',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Personas: ${t['used_people']}/${t['people_count']}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: QrImageView(
                          data: t['qr_token']?.toString() ?? '',
                          size: 180,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.center,
                        child: OutlinedButton.icon(
                          onPressed: () => _downloadTicketQr(t['qr_token']?.toString() ?? ''),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Descargar QR'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: benefits.map((b) {
                          final state = b['state']?.toString() ?? 'blocked';
                          final tone = switch (state) {
                            'active' => Colors.green,
                            'complete' => Colors.blueGrey,
                            _ => Colors.grey,
                          };
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: tone.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${b['benefit_type']}: ${b['used']}/${b['total']} · $state',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: tone.shade700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _downloadTicketQr(String token) async {
    if (token.trim().isEmpty) return;
    try {
      final painter = QrPainter(
        data: token,
        version: QrVersions.auto,
        color: const Color(0xFF111827),
        emptyColor: Colors.white,
      );
      final image = await painter.toImageData(1024);
      final bytes = image?.buffer.asUint8List();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ticket_qr_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Entrada eVeta QR',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar QR: $e')),
      );
    }
  }
}
