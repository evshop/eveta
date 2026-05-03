import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/wallet_admin_service.dart';

class WalletTopupsScreen extends StatefulWidget {
  const WalletTopupsScreen({super.key});

  @override
  State<WalletTopupsScreen> createState() => _WalletTopupsScreenState();
}

class _WalletTopupsScreenState extends State<WalletTopupsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  late Future<List<Map<String, dynamic>>> _tokensFuture;
  late Future<List<Map<String, dynamic>>> _qrgenTokensFuture;
  late Future<List<Map<String, dynamic>>> _bankEventsFuture;
  late Future<List<Map<String, dynamic>>> _qrAuditFuture;
  String _status = 'pending_proof';
  Timer? _bankEventsPoll;

  @override
  void initState() {
    super.initState();
    _future = WalletAdminService.fetchTopups(status: _status);
    _tokensFuture = WalletAdminService.fetchWebhookTokens();
    _qrgenTokensFuture = WalletAdminService.fetchQrgenTokens();
    _bankEventsFuture = WalletAdminService.fetchBankIncomingEvents();
    _qrAuditFuture = WalletAdminService.fetchQrGenerationAudit();
    _bankEventsPoll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() {
        _bankEventsFuture = WalletAdminService.fetchBankIncomingEvents();
      });
    });
  }

  @override
  void dispose() {
    _bankEventsPoll?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _future = WalletAdminService.fetchTopups(status: _status));
    setState(() => _tokensFuture = WalletAdminService.fetchWebhookTokens());
    setState(() => _qrgenTokensFuture = WalletAdminService.fetchQrgenTokens());
    setState(() => _bankEventsFuture = WalletAdminService.fetchBankIncomingEvents());
    setState(() => _qrAuditFuture = WalletAdminService.fetchQrGenerationAudit());
    await _future;
  }

  Future<void> _attachQrSource(String topupId) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer archivo QR.')),
      );
      return;
    }

    final ext = (file.extension ?? '').toLowerCase();
    final mimeType = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'image/png',
    };

    final result = await WalletAdminService.uploadAndDecodeTopupQr(
      topupId: topupId,
      fileBytes: bytes,
      fileName: file.name,
      mimeType: mimeType,
      provider: 'yape',
    );
    if (!mounted) return;
    final raw = result['raw_qr_text']?.toString() ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR guardado'),
        content: SelectableText(
          raw,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: raw));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Copiar texto plano'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
    await _reload();
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
        return ListView(
          padding: const EdgeInsets.all(12),
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
                                'Tokens generador QR (Termux 24/7)',
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
                          'Este token lo usa tu teléfono con Termux para: (1) pedir la siguiente recarga pendiente '
                          'y (2) subir la imagen del QR para decodificar.',
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
                            'Si el mensaje habla de permisos o RLS, ejecuta en Supabase el script '
                            '038_profile_is_admin_include_portal.sql y confirma que tu usuario tiene '
                            'is_admin en profiles o profiles_portal.',
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
                          'Eventos de Tasker (se actualizan solos cada ~20 s). Revisa también título/cuerpo si el monto detectado sale vacío.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
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
                            final appText = (e['bank_app']?.toString().trim().isNotEmpty == true)
                                ? e['bank_app'].toString()
                                : '-';
                            final senderText = (e['detected_sender']?.toString().trim().isNotEmpty == true)
                                ? e['detected_sender'].toString()
                                : '-';
                            final receivedAt = e['received_at']?.toString() ?? '-';
                            final detectedAt = e['detected_at']?.toString();
                            final titleText = e['title']?.toString() ?? '';
                            final bodyText = e['body']?.toString() ?? '';

                            return ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              leading: const Icon(Icons.notifications_active_outlined),
                              title: Text(
                                'Bs $amountText · Ref $refText',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'Estado: ${e['match_status'] ?? '-'} · Recibido: $receivedAt'
                                '${detectedAt != null ? ' · Detectado: $detectedAt' : ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              childrenPadding: const EdgeInsets.only(left: 44, right: 8, bottom: 10),
                              children: [
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
                                        'Topup: ${e['matched_topup_id']}',
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Pendientes QR (pending_proof)'),
                  selected: _status == 'pending_proof',
                  onSelected: (v) {
                    if (!v) return;
                    setState(() {
                      _status = 'pending_proof';
                      _future = WalletAdminService.fetchTopups(status: _status);
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Pendientes revisión (pending_review)'),
                  selected: _status == 'pending_review',
                  onSelected: (v) {
                    if (!v) return;
                    setState(() {
                      _status = 'pending_review';
                      _future = WalletAdminService.fetchTopups(status: _status);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Center(child: Text('No hay recargas pendientes de revisión.'))
            else
              ...rows.map((t) {
                    final profile = Map<String, dynamic>.from((t['profiles'] as Map?) ?? const {});
                    final hint = Map<String, dynamic>.from((t['reconciliation_hint'] as Map?) ?? const {});
                    final userLabel = profile['full_name']?.toString().trim().isNotEmpty == true
                        ? profile['full_name'].toString()
                        : (profile['username']?.toString().trim().isNotEmpty == true
                              ? profile['username'].toString()
                              : (profile['email']?.toString() ?? 'Usuario'));
                    final proofUrl = t['proof_url']?.toString() ?? '';
                final qrSources = List<Map<String, dynamic>>.from(
                  (t['wallet_topup_qr_sources'] as List?) ?? const [],
                );
                final qrSource = qrSources.isNotEmpty ? qrSources.first : null;
                final rawQrText = qrSource?['raw_qr_text']?.toString() ?? '';
                final decodedOk = qrSource?['decoded_ok'] == true;
                final decodedAt = qrSource?['decoded_at']?.toString();
                final qrProvider = qrSource?['provider']?.toString() ?? 'yape';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
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
                          SelectableText(
                            'Topup ID: ${t['id']}',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                            Text('Usuario: $userLabel'),
                            const SizedBox(height: 4),
                          if ((t['created_at']?.toString().trim().isNotEmpty ?? false))
                            Text(
                              'Creado: ${t['created_at']}',
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                            ),
                          const SizedBox(height: 8),
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
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'QR decodificado (${qrProvider.toUpperCase()})',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  qrSource == null
                                      ? 'Aún no hay QR procesado por el worker.'
                                      : (decodedOk
                                          ? 'OK · ${decodedAt ?? '-'}'
                                          : 'No decodificado'),
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                ),
                                if (rawQrText.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    rawQrText,
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          await Clipboard.setData(ClipboardData(text: rawQrText));
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Texto plano QR copiado.')),
                                          );
                                        },
                                        icon: const Icon(Icons.copy_rounded),
                                        label: const Text('Copiar texto plano'),
                                      ),
                                      SizedBox(
                                        width: 150,
                                        height: 150,
                                        child: Card(
                                          margin: EdgeInsets.zero,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Center(
                                              child: QrImageView(
                                                data: rawQrText,
                                                size: 130,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                            if (proofUrl.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: proofUrl));
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('URL copiada.')),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Copiar URL comprobante'),
                              ),
                            ],
                            const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                              children: [
                              if (_status == 'pending_proof') ...[
                                FilledButton.icon(
                                  onPressed: () => _attachQrSource(t['id'].toString()),
                                  icon: const Icon(Icons.qr_code_2_rounded),
                                  label: const Text('Subir QR Yape'),
                                ),
                              ],
                              FilledButton.icon(
                                onPressed: _status == 'pending_review' ? () => _approve(t) : null,
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('Aprobar'),
                                ),
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
                  ),
                );
              }).toList(),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _qrAuditFuture,
                  builder: (context, auditSnap) {
                    final auditRows = auditSnap.data ?? const [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Monitor de generación QR (Termux -> decode -> QR)',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Actualizar monitor',
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Esta sección muestra el pipeline completo: solicitud de recarga, claim del worker, '
                          'texto plano extraído y QR final generado para validar que funciona.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        if (auditRows.isEmpty)
                          Text(
                            'Aún no hay registros para auditar.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          )
                        else
                          ...auditRows.map((row) {
                            final profile = Map<String, dynamic>.from(
                              (row['profiles'] as Map?) ?? const {},
                            );
                            final hint = Map<String, dynamic>.from(
                              (row['reconciliation_hint'] as Map?) ?? const {},
                            );
                            final qrSources = List<Map<String, dynamic>>.from(
                              (row['wallet_topup_qr_sources'] as List?) ?? const [],
                            );
                            final qrSource = qrSources.isNotEmpty ? qrSources.first : null;
                            final raw = qrSource?['raw_qr_text']?.toString() ?? '';
                            final userLabel = profile['full_name']?.toString().trim().isNotEmpty == true
                                ? profile['full_name'].toString()
                                : (profile['username']?.toString().trim().isNotEmpty == true
                                      ? profile['username'].toString()
                                      : (profile['email']?.toString() ?? 'Usuario'));
                            final claimed = hint['qrgen_claimed'] == true;
                            final worker = hint['qrgen_worker_id']?.toString();
                            final claimedAt = hint['qrgen_claimed_at']?.toString();
                            final stageText = !claimed
                                ? '1/4 Pendiente de claim por worker'
                                : (raw.isEmpty
                                    ? '2/4 Claim hecho, falta upload/decode'
                                    : '4/4 Texto plano listo y QR generado');
                            final stageColor = !claimed
                                ? scheme.onSurfaceVariant
                                : (raw.isEmpty ? Colors.orange : Colors.green);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bs ${row['amount']} · ${row['reference_code']} · ${row['status']}',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      stageText,
                                      style: TextStyle(
                                        color: stageColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Usuario: $userLabel',
                                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                    ),
                                    Text(
                                      'Claim worker: ${claimed ? 'sí' : 'no'}'
                                      '${worker != null && worker.isNotEmpty ? ' · $worker' : ''}'
                                      '${claimedAt != null ? ' · $claimedAt' : ''}',
                                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    if (raw.isEmpty)
                                      Text(
                                        claimed
                                            ? 'Reclamada pero sin texto plano aún. Revisa script Termux (adb pull/upload).'
                                            : 'Aún no reclamada por el worker (qrgen-next-topup).',
                                        style: TextStyle(color: scheme.onSurfaceVariant),
                                      )
                                    else
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        crossAxisAlignment: WrapCrossAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 170,
                                            height: 170,
                                            child: Card(
                                              child: Padding(
                                                padding: const EdgeInsets.all(8),
                                                child: Center(
                                                  child: QrImageView(
                                                    data: raw,
                                                    size: 145,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 550),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Texto plano extraído:',
                                                  style: TextStyle(fontWeight: FontWeight.w700),
                                                ),
                                                const SizedBox(height: 4),
                                                SelectableText(
                                                  raw,
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                OutlinedButton.icon(
                                                  onPressed: () async {
                                                    await Clipboard.setData(ClipboardData(text: raw));
                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Texto plano copiado.'),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(Icons.copy_rounded),
                                                  label: const Text('Copiar texto plano'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  },
                ),
                ),
              ),
          ],
        );
      },
    );
  }
}
