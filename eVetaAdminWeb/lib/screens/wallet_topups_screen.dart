import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/wallet_admin_service.dart';

class WalletTopupsScreen extends StatefulWidget {
  const WalletTopupsScreen({super.key});

  @override
  State<WalletTopupsScreen> createState() => _WalletTopupsScreenState();
}

class _WalletTopupsScreenState extends State<WalletTopupsScreen> {
  late Future<List<Map<String, dynamic>>> _tokensFuture;
  late Future<List<Map<String, dynamic>>> _qrgenTokensFuture;
  late Future<List<Map<String, dynamic>>> _bankEventsFuture;
  RealtimeChannel? _bankEventsRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _tokensFuture = WalletAdminService.fetchWebhookTokens();
    _qrgenTokensFuture = WalletAdminService.fetchQrgenTokens();
    _bankEventsFuture = WalletAdminService.fetchBankIncomingEvents();
    _subscribeBankIncomingRealtime();
  }

  void _subscribeBankIncomingRealtime() {
    _bankEventsRealtimeChannel = Supabase.instance.client
        .channel('wallet_admin_bank_incoming_events')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bank_incoming_events',
          callback: (_) {
            if (!mounted) return;
            setState(() {
              _bankEventsFuture = WalletAdminService.fetchBankIncomingEvents();
            });
          },
        );
    _bankEventsRealtimeChannel!.subscribe();
  }

  @override
  void dispose() {
    _bankEventsRealtimeChannel?.unsubscribe();
    super.dispose();
  }

  bool _rowLooksLikeUnexpandedTaskerVars(Map<String, dynamic> e) {
    final buf = StringBuffer()
      ..write(e['title'] ?? '')
      ..write(' ')
      ..write(e['body'] ?? '')
      ..write(' ')
      ..write(e['detected_reference'] ?? '');
    final raw = e['raw_payload'];
    if (raw is Map) {
      try {
        buf.write(jsonEncode(raw));
      } catch (_) {}
    }
    return RegExp(r'%[a-z_][a-z0-9_]*', caseSensitive: false).hasMatch(buf.toString());
  }

  String _bankEventStatusLabel(String? status) {
    switch (status) {
      case 'matched_confirmed':
        return 'Verificado — acreditado en wallet';
      case 'matched_suggested':
        return 'Coincidencia sin acreditar (revisar vencimiento de la recarga)';
      case 'unmatched':
        return 'Sin coincidencia';
      case 'discarded':
        return 'Descartado';
      default:
        return (status != null && status.isNotEmpty) ? status : '—';
    }
  }

  Future<void> _reload() async {
    setState(() {
      _tokensFuture = WalletAdminService.fetchWebhookTokens();
      _qrgenTokensFuture = WalletAdminService.fetchQrgenTokens();
      _bankEventsFuture = WalletAdminService.fetchBankIncomingEvents();
    });
    await _tokensFuture;
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

    Map<String, dynamic> created;
    try {
      created = await WalletAdminService.createWebhookToken(
        label: labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar token Tasker: $e')),
      );
      return;
    }
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

  Future<void> _createQrgenToken() async {
    final labelCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generar token QRGen (Termux)'),
        content: TextField(
          controller: labelCtrl,
          decoration: const InputDecoration(
            labelText: 'Etiqueta (opcional)',
            hintText: 'Ej: Samsung A55 (Termux)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generar')),
        ],
      ),
    );
    if (ok != true) return;

    Map<String, dynamic> created;
    try {
      created = await WalletAdminService.createQrgenToken(
        label: labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar token QRGen: $e')),
      );
      return;
    }
    if (!mounted) return;
    final token = created['token']?.toString() ?? '';
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se recibió token desde el servidor. Revisa el RPC.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Token QRGen generado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Pégalo en tu script Termux como QRGEN_TOKEN.'),
            const SizedBox(height: 10),
            SelectableText(
              token,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Token copiado. Pégalo en Termux.')),
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

  Future<void> _revokeQrgenToken(String tokenId) async {
    await WalletAdminService.revokeQrgenToken(tokenId);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recargas Wallet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tokens para Tasker / Termux y notificaciones bancarias. La conciliación por monto es automática (ver script 043 en Supabase).',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 12),
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
                      'Authorization: Bearer <token> al llamar la Edge Function tasker-bank-webhook.',
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
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _qrgenTokensFuture,
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
                            'Tokens generador QR (Termux)',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _createQrgenToken,
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: const Text('Generar token'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Para el worker qrgen-next-topup en el dispositivo con Termux.',
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
                          leading: const Icon(Icons.memory_outlined),
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
                            onPressed: () => _revokeQrgenToken(t['id'].toString()),
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
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _bankEventsFuture,
          builder: (context, bankSnap) {
            if (bankSnap.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Notificaciones bancarias recibidas',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error al cargar: ${bankSnap.error}',
                        style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Si habla de permisos o RLS, ejecuta 038_profile_is_admin_include_portal.sql.',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }
            final bankRows = bankSnap.data ?? const [];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Notificaciones bancarias recibidas',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tiempo real (Realtime). Conciliación: monto exacto y ventana 24 h (SQL 043). '
                      'Si ves %antitle en el JSON, corrige la tarea Tasker.',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    if (bankRows.isEmpty)
                      Text(
                        'No hay eventos bancarios todavía.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      )
                    else
                      ...bankRows.take(10).map((e) {
                        final payload = e['raw_payload'];
                        final payloadPretty = payload == null
                            ? null
                            : const JsonEncoder.withIndent('  ').convert(payload);
                        final detectedAmount = e['detected_amount'];
                        final amountText = detectedAmount == null ? '-' : detectedAmount.toString();
                        final refText = (e['detected_reference']?.toString().trim().isNotEmpty == true)
                            ? e['detected_reference'].toString()
                            : '-';
                        final matchedRef = WalletAdminService.matchedTopupReferenceFromBankEvent(
                          Map<String, dynamic>.from(e),
                        );
                        final matchStatus = e['match_status']?.toString();
                        final statusLabel = _bankEventStatusLabel(matchStatus);
                        final receivedAt = e['received_at']?.toString() ?? '-';
                        final appText = (e['bank_app']?.toString().trim().isNotEmpty == true)
                            ? e['bank_app'].toString()
                            : '-';
                        final senderText = (e['detected_sender']?.toString().trim().isNotEmpty == true)
                            ? e['detected_sender'].toString()
                            : '-';
                        final titleText = e['title']?.toString() ?? '';
                        final bodyText = e['body']?.toString() ?? '';
                        final titleRefPart = (matchedRef != null && matchedRef.isNotEmpty)
                            ? matchedRef
                            : refText;

                        final verifiedWithRef =
                            matchStatus == 'matched_confirmed' && (matchedRef?.isNotEmpty ?? false);
                        final subtitle = verifiedWithRef
                            ? '$statusLabel · Recibido: $matchedRef'
                            : '$statusLabel · Recibido: $receivedAt';

                        return ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          leading: const Icon(Icons.notifications_active_outlined),
                          title: Text(
                            'Bs $amountText · $titleRefPart',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          childrenPadding: const EdgeInsets.only(left: 44, right: 8, bottom: 10),
                          children: [
                            if (_rowLooksLikeUnexpandedTaskerVars(
                              Map<String, dynamic>.from(e),
                            )) ...[
                              Material(
                                color: scheme.errorContainer.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    'Tasker mandó variables sin sustituir (%antitle, %antext, …). Revisa el cuerpo HTTP.',
                                    style: TextStyle(
                                      color: scheme.onErrorContainer,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (matchedRef != null && matchedRef.isNotEmpty) ...[
                              SelectableText(
                                'Código de recarga (EV): $matchedRef',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'App: $appText\nSender: $senderText',
                                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                  ),
                                ),
                                if (e['matched_topup_id'] != null)
                                  Text(
                                    'Topup id: ${e['matched_topup_id']}',
                                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (titleText.trim().isNotEmpty)
                              SelectableText(
                                'Título: $titleText',
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (bodyText.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              SelectableText(
                                'Body: $bodyText',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                            if (payloadPretty != null) ...[
                              const SizedBox(height: 8),
                              SelectableText(
                                payloadPretty,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                              ),
                            ],
                          ],
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
