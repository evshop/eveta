import 'package:flutter/material.dart';

import '../services/wallet_admin_service.dart';

class WalletTopupsScreen extends StatefulWidget {
  const WalletTopupsScreen({super.key});

  @override
  State<WalletTopupsScreen> createState() => _WalletTopupsScreenState();
}

class _WalletTopupsScreenState extends State<WalletTopupsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = WalletAdminService.fetchTopups();
  }

  Future<void> _reload() async {
    setState(() => _future = WalletAdminService.fetchTopups());
    await _future;
  }

  Future<void> _approve(String topupId) async {
    await WalletAdminService.approveTopup(topupId);
    await _reload();
  }

  Future<void> _reject(String topupId) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar recarga'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rechazar')),
        ],
      ),
    );
    if (ok != true) return;
    await WalletAdminService.rejectTopup(
      topupId,
      reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Recargas pendientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No hay recargas pendientes de revisión.'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final t = rows[i];
                    final profile = Map<String, dynamic>.from((t['profiles'] as Map?) ?? const {});
                    final userLabel = profile['full_name']?.toString().trim().isNotEmpty == true
                        ? profile['full_name'].toString()
                        : (profile['username']?.toString().trim().isNotEmpty == true
                              ? profile['username'].toString()
                              : (profile['email']?.toString() ?? 'Usuario'));
                    final proofUrl = t['proof_url']?.toString() ?? '';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Bs ${t['amount']} · ${t['reference_code']}',
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(
                                  t['status']?.toString() ?? '',
                                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Usuario: $userLabel'),
                            const SizedBox(height: 4),
                            SelectableText(
                              proofUrl.isEmpty ? 'Sin comprobante' : proofUrl,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            if (proofUrl.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('Abrir comprobante (copiar URL)'),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                FilledButton.icon(
                                  onPressed: () => _approve(t['id'].toString()),
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('Aprobar'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _reject(t['id'].toString()),
                                  icon: const Icon(Icons.close_rounded),
                                  label: const Text('Rechazar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
