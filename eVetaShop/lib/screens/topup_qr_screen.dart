import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:eveta/utils/wallet_resume_prefs.dart';
import 'package:eveta/utils/wallet_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Recarga nueva: [amount] obligatorio. Reanudar: [existingTopupId] (desde historial).
class TopupQrScreen extends StatefulWidget {
  TopupQrScreen({
    super.key,
    this.amount,
    this.existingTopupId,
  }) : assert(
          (existingTopupId ?? '').trim().isNotEmpty || ((amount ?? 0) > 0),
        );

  final double? amount;
  final String? existingTopupId;

  @override
  State<TopupQrScreen> createState() => _TopupQrScreenState();
}

class _TopupQrScreenState extends State<TopupQrScreen> {
  bool _creating = true;
  String? _error;

  Map<String, dynamic>? _topup;
  Timer? _poll;
  int _ticks = 0;
  bool _savingQr = false;
  Timer? _countdownTimer;
  DateTime _now = DateTime.now();

  bool get _isResume => (widget.existingTopupId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isResume) {
      _loadExisting((widget.existingTopupId ?? '').trim());
    } else {
      _startNew(widget.amount!);
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _countdownTimer?.cancel();
    final captured = _topup;
    if (captured != null && _error == null) {
      unawaited(WalletResumePrefs.markLeftWithoutCompleting(captured));
    }
    super.dispose();
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

  Future<void> _startNew(double amount) async {
    setState(() {
      _creating = true;
      _error = null;
      _topup = null;
    });

    try {
      final created = await WalletService.createTopupRequest(amount: amount);
      final topupId = created['topup_id']?.toString() ?? created['id']?.toString() ?? '';
      if (topupId.isEmpty) {
        throw Exception('No se recibió topup_id.');
      }
      final fresh = await WalletService.getTopupById(topupId);
      if (!mounted) return;
      setState(() {
        _topup = fresh ?? created;
        _creating = false;
      });
      _startPolling(topupId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadExisting(String topupId) async {
    setState(() {
      _creating = true;
      _error = null;
      _topup = null;
    });
    try {
      final fresh = await WalletService.getTopupById(topupId);
      if (!mounted) return;
      if (fresh == null) {
        setState(() {
          _creating = false;
          _error = 'No se encontró la recarga.';
        });
        return;
      }
      if (WalletService.isTopupExpired(fresh)) {
        await WalletResumePrefs.removeId(topupId);
        setState(() {
          _creating = false;
          _error = 'Esta solicitud expiró (pasaron 10 minutos). Genera un QR nuevo.';
        });
        return;
      }
      setState(() {
        _topup = fresh;
        _creating = false;
      });
      _startPolling(topupId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = e.toString();
      });
    }
  }

  void _startPolling(String topupId) {
    _poll?.cancel();
    _ticks = 0;
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      _ticks++;
      if (!mounted) return;
      if (_ticks >= 120) {
        _poll?.cancel();
        return;
      }
      try {
        final fresh = await WalletService.getTopupById(topupId);
        if (!mounted || fresh == null) return;
        setState(() => _topup = fresh);
        if (WalletService.isTopupExpired(fresh)) {
          _poll?.cancel();
          await WalletResumePrefs.removeId(topupId);
        }
        final raw = WalletService.rawQrTextFromTopup(fresh);
        if (raw != null && raw.isNotEmpty) {
          _poll?.cancel();
        }
      } catch (_) {
        // ignore
      }
    });
  }

  Future<Uint8List?> _buildQrPngBytes(String raw) async {
    final painter = QrPainter(
      data: raw,
      version: QrVersions.auto,
      gapless: true,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
    );
    final ByteData? pngData = await painter.toImageData(900, format: ui.ImageByteFormat.png);
    if (pngData == null) return null;
    return pngData.buffer.asUint8List();
  }

  Future<void> _shareQrPng(Uint8List bytes, String code) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/eveta_topup_$code.png');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'QR de recarga $code');
  }

  Future<void> _saveQrToGallery() async {
    final topup = _topup;
    if (topup == null || _savingQr) return;
    final raw = WalletService.rawQrTextFromTopup(topup);
    if (raw == null || raw.isEmpty) return;
    final code = topup['reference_code']?.toString() ?? 'topup';

    setState(() => _savingQr = true);
    try {
      final bytes = await _buildQrPngBytes(raw);
      if (bytes == null) {
        _snack('No se pudo generar la imagen del QR.', isError: true);
        return;
      }

      if (kIsWeb) {
        await _shareQrPng(bytes, code);
        _snack('Usa el menú del sistema para guardar o compartir el archivo.');
        return;
      }

      try {
        if (!await Gal.hasAccess(toAlbum: true)) {
          final granted = await Gal.requestAccess(toAlbum: true);
          if (!granted) {
            _snack('Permiso denegado. Puedes usar Compartir para enviar el PNG.', isError: true);
            return;
          }
        }
        final name = 'eveta_topup_${code}_${DateTime.now().millisecondsSinceEpoch}';
        await Gal.putImageBytes(bytes, name: name);
        if (mounted) _snack('QR guardado en la galería (Fotos).');
      } on GalException catch (e) {
        if (mounted) {
          _snack('No se pudo guardar en la galería (${e.type}). Usa Compartir.', isError: true);
        }
      } catch (_) {
        if (mounted) {
          _snack('No se pudo guardar en la galería. Usa Compartir.', isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _savingQr = false);
    }
  }

  Future<void> _shareQr() async {
    final topup = _topup;
    if (topup == null) return;
    final raw = WalletService.rawQrTextFromTopup(topup);
    if (raw == null || raw.isEmpty) return;
    final code = topup['reference_code']?.toString() ?? 'topup';
    final bytes = await _buildQrPngBytes(raw);
    if (bytes == null) {
      _snack('No se pudo generar la imagen del QR.', isError: true);
      return;
    }
    await _shareQrPng(bytes, code);
  }

  void _showVerificationInfo(double base, double delta, double pay) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Método de verificación', style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onSurface)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'Para identificar tu pago automáticamente, usamos un monto único en centavos.\n\n'
                  'Monto a acreditar: Bs ${base.toStringAsFixed(2)}\n'
                  'Centavos de verificación: Bs ${delta.toStringAsFixed(2)}\n'
                  'Monto a pagar: Bs ${pay.toStringAsFixed(2)}\n\n'
                  'Este monto en centavos es solo para verificación y no es un cargo por uso.',
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _qrOrPlaceholder({
    required Map<String, dynamic>? topup,
    required bool expired,
    required ColorScheme scheme,
  }) {
    final q = topup == null ? null : WalletService.rawQrTextFromTopup(topup);
    if (q == null || q.isEmpty || expired) {
      return SizedBox(
        width: 260,
        height: 260,
        child: Center(
          child: Icon(
            Icons.qr_code_2_rounded,
            size: 70,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
        ),
      );
    }
    return QrImageView(
      data: q,
      size: 260,
      backgroundColor: Colors.white,
      embeddedImage: const AssetImage('assets/images/ic_app_icon.png'),
      embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(56, 56)),
    );
  }

  String? _countdownLabel(Map<String, dynamic> topup) {
    final exp = WalletService.parseTopupExpiresAt(topup);
    if (exp == null) return null;
    var left = exp.difference(_now);
    if (left.isNegative) left = Duration.zero;
    final m = left.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = left.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topup = _topup;
    final code = topup?['reference_code']?.toString() ?? '';
    final double payAmount = (topup?['amount'] is num)
        ? (topup!['amount'] as num).toDouble()
        : double.tryParse(topup?['amount']?.toString() ?? '') ?? (widget.amount ?? 0).toDouble();
    final double baseAmount =
        topup == null ? (widget.amount ?? 0).toDouble() : WalletService.requestedAmountFromTopup(topup);
    final double delta = topup == null ? 0.0 : WalletService.verificationDeltaFromTopup(topup);
    final raw = topup == null ? null : WalletService.rawQrTextFromTopup(topup);
    final hasQr = raw != null && raw.isNotEmpty;
    final waiting = !_creating && topup != null && !hasQr;
    final status = topup?['status']?.toString() ?? '';
    final expired = topup != null && WalletService.isTopupExpired(topup);

    final cd = topup != null && !expired ? _countdownLabel(topup) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR de recarga'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () async {
              final id = topup?['id']?.toString();
              if (id == null || id.isEmpty) return;
              final fresh = await WalletService.getTopupById(id);
              if (!mounted || fresh == null) return;
              setState(() => _topup = fresh);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    if (_creating)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                              'Cargando...',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Column(
                          children: [
                            Icon(Icons.error_outline_rounded, color: scheme.error, size: 40),
                            const SizedBox(height: 10),
                            Text(
                              'No se pudo mostrar el QR',
                              style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            if (!_isResume)
                              FilledButton.icon(
                                onPressed: () => _startNew(widget.amount!),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Reintentar'),
                              ),
                          ],
                        ),
                      )
                    else ...[
                      if (expired)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(Icons.timer_off_rounded, color: scheme.onErrorContainer),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Este QR ya no es válido (10 minutos). Vuelve a Wallet y genera uno nuevo.',
                                      style: TextStyle(
                                        color: scheme.onErrorContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (cd != null && !expired)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.timer_outlined, size: 20, color: scheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Vence en $cd',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (waiting) ...[
                        Text(
                          'Generando QR de pago...',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: const LinearProgressIndicator(minHeight: 7),
                        ),
                        const SizedBox(height: 18),
                      ],
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EAEF),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: _qrOrPlaceholder(topup: topup, expired: expired, scheme: scheme),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('Bs ${baseAmount.toStringAsFixed(2)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              code,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: topup == null ? null : () => _showVerificationInfo(baseAmount, delta, payAmount),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.surfaceContainerHigh,
                                border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
                              ),
                              child: Icon(Icons.priority_high_rounded, size: 16, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Método de verificación • Paga: Bs ${payAmount.toStringAsFixed(2)} (+${delta.toStringAsFixed(2)})',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      if (status == 'approved')
                        Text(
                          'Pago verificado. Saldo acreditado.',
                          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (hasQr && !expired && !_savingQr) ? _saveQrToGallery : null,
                      icon: _savingQr
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(_savingQr ? 'Guardando...' : 'Guardar en galería'),
                    ),
                  ),
                  if (hasQr && !expired) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _savingQr ? null : _shareQr,
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Compartir PNG'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
