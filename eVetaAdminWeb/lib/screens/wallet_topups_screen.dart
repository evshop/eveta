import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/wallet_admin_service.dart';

class WalletTopupsScreen extends StatefulWidget {
  const WalletTopupsScreen({super.key});

  @override
  State<WalletTopupsScreen> createState() => _WalletTopupsScreenState();
}

class _WalletTopupsScreenState extends State<WalletTopupsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  late Future<List<Map<String, dynamic>>> _tokensFuture;

  @override
  void initState() {
    super.initState();
    _future = WalletAdminService.fetchTopups();
    _tokensFuture = WalletAdminService.fetchWebhookTokens();
  }

  Future<void> _reload() async {
    setState(() => _future = WalletAdminService.fetchTopups());
    setState(() => _tokensFuture = WalletAdminService.fetchWebhookTokens());
    await _future;
  }

  Future<void> _createToken() async {
    final labelCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generar token Tasker'),
        content: TextField(
          controller: labelCtrl,
          decoration: const InputDecoration(
            labelText: 'Etiqueta (opcional)',
            hintText: 'Ej: Samsung J7',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generar')),
        ],
      ),
    );
    if (ok != true) return;

    final created = await WalletAdminService.createWebhookToken(
      label: labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim(),
    );
    if (!mounted) return;
    final token = created['token']?.toString() ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Token generado'),
        content: SelectableText(
          token,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Token copiado. Guárdalo en Tasker.')),
                );
              }
            },
            child: const Text('Copiar'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
    await _reload();
  }

  Future<void> _revokeToken(String tokenId) async {
    await WalletAdminService.revokeWebhookToken(tokenId);
    await _reload();
  }

  Future<void> _approve(Map<String, dynamic> row) async {
    final topupId = row['id'].toString();
    final hint = Map<String, dynamic>.from((row['reconciliation_hint'] as Map?) ?? const {});
    final bankEventId = hint['bank_event_id']?.toString();
    await WalletAdminService.approveTopup(
      topupId,
      bankEventId: (bankEventId == null || bankEventId.isEmpty) ? null : bankEventId,
    );
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
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _tokensFuture,
              builder: (context, tokenSnap) {
                final tokens = tokenSnap.data ?? const [];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Tokens webhook Tasker',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _createToken,
                              icon: const Icon(Icons.key_rounded),
                              label: const Text('Generar token'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Usa este token en Tasker como Authorization: Bearer <token> para enviar notificaciones de pago.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        if (tokens.isEmpty)
                          Text(
                            'No hay tokens activos.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          )
                        else
                          ...tokens.map(
                            (t) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.vpn_key_outlined),
                              title: Text(
                                t['label']?.toString().trim().isNotEmpty == true
                                    ? t['label'].toString()
                                    : 'Token sin etiqueta',
                              ),
                              subtitle: Text(
                                'Creado: ${t['created_at'] ?? '-'}'
                                '${t['last_used_at'] != null ? ' · Último uso: ${t['last_used_at']}' : ''}',
                              ),
                              trailing: OutlinedButton(
                                onPressed: () => _revokeToken(t['id'].toString()),
                                child: const Text('Revocar'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
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
                    final hint = Map<String, dynamic>.from((t['reconciliation_hint'] as Map?) ?? const {});
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
                            if (hint.isNotEmpty) ...[
                              if ((hint['bank_match_status']?.toString() ?? '') == 'suggested')
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Match bancario sugerido · score ${hint['bank_match_score'] ?? '-'}'
                                    '${hint['bank_detected_amount'] != null ? ' · Bs ${hint['bank_detected_amount']}' : ''}',
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
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
                                  onPressed: () => _approve(t),
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
