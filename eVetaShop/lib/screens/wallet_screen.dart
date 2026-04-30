import 'dart:async';
import 'dart:typed_data';

import 'package:eveta/utils/wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _withdrawAmountCtrl = TextEditingController();
  bool _loading = true;
  bool _creating = false;
  bool _uploading = false;
  bool _showTopup = false;
  bool _showWithdraw = false;
  double _balance = 0;
  List<Map<String, dynamic>> _topups = const [];
  Map<String, dynamic>? _activeTopup;
  Timer? _qrPollTimer;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _qrPollTimer?.cancel();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _withdrawAmountCtrl.dispose();
    super.dispose();
  }

  void _syncQrPollTimer() {
    _qrPollTimer?.cancel();
    final active = _activeTopup;
    if (active == null) return;
    final status = active['status']?.toString() ?? '';
    final raw = WalletService.rawQrTextFromTopup(active);
    if (status != 'pending_proof' || raw != null) return;

    _qrPollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      try {
        await _reload();
        if (!mounted) return;
        final t = _topupById(active['id']?.toString());
        if (t != null) {
          setState(() => _activeTopup = t);
        }
        final updated = _activeTopup;
        if (updated == null) return;
        final done = WalletService.rawQrTextFromTopup(updated) != null ||
            (updated['status']?.toString() != 'pending_proof');
        if (done) {
          _qrPollTimer?.cancel();
          _qrPollTimer = null;
        }
      } catch (_) {
        // Silencioso: siguiente tick reintenta
      }
    });
  }

  Map<String, dynamic>? _topupById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final row in _topups) {
      if (row['id']?.toString() == id) return row;
    }
    return null;
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final values = await Future.wait<dynamic>([
        WalletService.getBalance(),
        WalletService.getMyTopups(),
      ]);
      if (!mounted) return;
      setState(() {
        _balance = values[0] as double;
        _topups = List<Map<String, dynamic>>.from(values[1] as List);
        final aid = _activeTopup?['id']?.toString();
        if (aid != null) {
          final fresh = _topupById(aid);
          if (fresh != null) _activeTopup = fresh;
        }
      });
      _syncQrPollTimer();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTopup() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _snack('Ingresa un monto válido.');
      return;
    }
    setState(() => _creating = true);
    try {
      final topup = await WalletService.createTopupRequest(amount: amount);
      if (!mounted) return;
      setState(() => _activeTopup = topup);
      await _reload();
      _snack(
        'Solicitud enviada. El QR de pago (Yape) aparecerá aquí cuando el generador lo procese; '
        'luego puedes pagar y subir comprobante si lo pide el admin.',
      );
    } catch (e) {
      _snack('No se pudo crear la recarga: $e', isError: true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _pickAndUploadProof(String topupId) async {
    setState(() => _uploading = true);
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      final ext = _extensionFromName(file.name);
      final proofUrl = await WalletService.uploadProofImage(
        bytes: bytes,
        extension: ext,
      );
      Map<String, dynamic>? topup;
      for (final row in _topups) {
        if (row['id'].toString() == topupId) {
          topup = row;
          break;
        }
      }
      if (topup == null && _activeTopup != null && _activeTopup!['id'].toString() == topupId) {
        topup = _activeTopup;
      }
      await WalletService.submitTopupProof(
        topupId: topupId,
        proofUrl: proofUrl,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        hint: <String, dynamic>{
          'topup_reference_code': topup?['reference_code']?.toString(),
          'topup_amount': topup?['amount'],
          'proof_uploaded_at': DateTime.now().toIso8601String(),
        },
      );
      _noteCtrl.clear();
      await _reload();
      _snack('Comprobante enviado para revisión.');
    } catch (e) {
      _snack('No se pudo subir el comprobante: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _extensionFromName(String name) {
    final idx = name.lastIndexOf('.');
    if (idx < 0 || idx == name.length - 1) return 'jpg';
    return name.substring(idx + 1).toLowerCase();
  }

  void _snack(String text, {bool isError = false}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? scheme.error : scheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _BalanceCard(
                    balance: _balance,
                    isDark: isDark,
                    onRefresh: _reload,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'Recargar saldo',
                          icon: Icons.qr_code_rounded,
                          filled: true,
                          onTap: () {
                            setState(() {
                              _showTopup = !_showTopup;
                              if (_showTopup) _showWithdraw = false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          label: 'Retirar saldo',
                          icon: Icons.south_west_rounded,
                          filled: false,
                          onTap: () {
                            setState(() {
                              _showWithdraw = !_showWithdraw;
                              if (_showWithdraw) _showTopup = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_showTopup) ...[
                    const SizedBox(height: 12),
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Recargar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Monto (Bs)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _creating ? null : _createTopup,
                            icon: const Icon(Icons.qr_code_rounded),
                            label: Text(_creating ? 'Generando...' : 'Generar QR'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _activeTopup == null || _uploading
                                ? null
                                : () => _pickAndUploadProof(_activeTopup!['id'].toString()),
                            icon: const Icon(Icons.upload_file_rounded),
                            label: Text(_uploading ? 'Subiendo...' : 'Subir comprobante'),
                          ),
                          if (_activeTopup != null) ...[
                            const SizedBox(height: 14),
                            Builder(
                              builder: (context) {
                                final rawPay = WalletService.rawQrTextFromTopup(_activeTopup!);
                                final pendingGen = (_activeTopup!['status']?.toString() == 'pending_proof') &&
                                    (rawPay == null || rawPay.isEmpty);
                                final qrData = (rawPay != null && rawPay.isNotEmpty)
                                    ? rawPay
                                    : 'EVETA_TOPUP:${_activeTopup!['reference_code']}:${_activeTopup!['amount']}';
                                return Column(
                                  children: [
                                    if (pendingGen) ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          children: [
                                            TweenAnimationBuilder<double>(
                                              tween: Tween(begin: 0.75, end: 1.15),
                                              duration: const Duration(milliseconds: 900),
                                              curve: Curves.easeInOut,
                                              builder: (context, value, child) => Transform.scale(
                                                scale: value,
                                                child: Icon(
                                                  Icons.qr_code_2_rounded,
                                                  size: 30,
                                                  color: scheme.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Generando QR de pago...',
                                              style: TextStyle(
                                                color: scheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(999),
                                              child: const LinearProgressIndicator(minHeight: 7),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Referencia ${_activeTopup!['reference_code']} · Bs ${_activeTopup!['amount']}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                      ),
                                    ] else ...[
                                      Center(
                                        child: QrImageView(
                                          data: qrData,
                                          size: 250,
                                          embeddedImage: const AssetImage('assets/images/ic_app_icon.png'),
                                          embeddedImageStyle: QrEmbeddedImageStyle(
                                            size: const Size(54, 54),
                                          ),
                                          eyeStyle: QrEyeStyle(
                                            eyeShape: QrEyeShape.square,
                                            color: scheme.onSurface,
                                          ),
                                          dataModuleStyle: QrDataModuleStyle(
                                            dataModuleShape: QrDataModuleShape.square,
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (rawPay != null && rawPay.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Escanea con la app de pago para completar la recarga',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Código: ${_activeTopup!['reference_code']}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Monto: Bs ${_activeTopup!['amount']}',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              'Mensaje (Yape): ${WalletService.suggestedYapeMessage(_activeTopup!['reference_code']?.toString() ?? '')}',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'El generador remoto usa estos mismos datos; el QR grande lleva el payload que Yape necesita.',
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _noteCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nota (opcional)',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (_showWithdraw) ...[
                    const SizedBox(height: 12),
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Retirar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _withdrawAmountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Monto (Bs)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _snack('Retiro: próximamente (UI lista).'),
                                  icon: const Icon(Icons.qr_code_scanner_rounded),
                                  label: const Text('Escanear QR'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _snack('Retiro: próximamente (UI lista).'),
                                  icon: const Icon(Icons.upload_file_rounded),
                                  label: const Text('Subir QR'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text('Historial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (_topups.isEmpty)
                    Text(
                      'Aún no tienes recargas registradas.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    )
                  else
                    ..._topups.map((t) {
                      final status = t['status']?.toString() ?? 'pending_proof';
                      final color = switch (status) {
                        'approved' => Colors.green,
                        'rejected' => scheme.error,
                        _ => Colors.orange,
                      };
                      return Card(
                        child: ListTile(
                          title: Text(
                            'Bs ${t['amount']} · ${t['reference_code']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            _statusLabel(status),
                          ),
                          trailing: Icon(Icons.circle, size: 12, color: color),
                          onTap: status == 'pending_proof'
                              ? () {
                                  setState(() => _activeTopup = t);
                                  _syncQrPollTimer();
                                  _snack('Recarga seleccionada. Si falta el QR de pago, se actualizará solo.');
                                }
                              : null,
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending_proof':
        return 'Pendiente de comprobante';
      case 'pending_review':
        return 'Pendiente de aprobación admin';
      case 'approved':
        return 'Aprobada y acreditada';
      case 'rejected':
        return 'Rechazada por admin';
      case 'expired':
        return 'Expirada';
      default:
        return status;
    }
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.isDark,
    required this.onRefresh,
  });

  final double balance;
  final bool isDark;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              scheme.surfaceContainerHighest.withValues(alpha: 0.95),
              scheme.surfaceContainerHigh.withValues(alpha: 0.85),
            ]
          : [
              scheme.primary.withValues(alpha: 0.10),
              scheme.surfaceContainerHighest.withValues(alpha: 0.95),
            ],
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: grad,
        border: Border.all(color: scheme.outline.withValues(alpha: isDark ? 0.28 : 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo disponible',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bs ${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
    return SizedBox(
      height: 48,
      child: filled
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                side: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
              ),
              child: child,
            ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.72 : 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: isDark ? 0.30 : 0.18)),
      ),
      child: child,
    );
  }
}
