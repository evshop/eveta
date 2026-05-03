import 'dart:async';

import 'package:eveta/utils/wallet_resume_prefs.dart';
import 'package:eveta/utils/wallet_service.dart';
import 'package:flutter/material.dart';
import 'topup_qr_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _withdrawAmountCtrl = TextEditingController();
  bool _loading = true;
  bool _showTopup = false;
  bool _showWithdraw = false;
  double _balance = 0;
  List<Map<String, dynamic>> _topups = const [];
  Set<String> _resumeIds = {};
  Timer? _historyTick;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _historyTick?.cancel();
    _amountCtrl.dispose();
    _withdrawAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final values = await Future.wait<dynamic>([
        WalletService.getBalance(),
        WalletService.getMyTopups(),
      ]);
      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(values[1] as List);
      final resume = await WalletResumePrefs.pruneAndGetValid(list);
      setState(() {
        _balance = values[0] as double;
        _topups = list;
        _resumeIds = resume;
      });
      _syncHistoryCountdownTimer();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _visibleTopups() {
    return _topups.where((t) => _includeTopupInHistory(t)).toList();
  }

  bool _includeTopupInHistory(Map<String, dynamic> t) {
    final status = t['status']?.toString() ?? '';
    final id = t['id']?.toString() ?? '';

    if (status == 'approved' || status == 'rejected') return true;
    if (status == 'expired') return false;

    if (WalletService.isTopupExpired(t) &&
        status == 'pending_proof' &&
        true) {
      return false;
    }

    if (status == 'pending_proof') {
      return _resumeIds.contains(id);
    }
    return false;
  }

  void _syncHistoryCountdownTimer() {
    final visible = _visibleTopups();
    final needs = visible.any((t) {
      final st = t['status']?.toString() ?? '';
      final id = t['id']?.toString() ?? '';
      if (st != 'pending_proof' || !_resumeIds.contains(id)) return false;
      return !WalletService.isTopupExpired(t);
    });
    if (needs) {
      _historyTick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
      });
    } else {
      _historyTick?.cancel();
      _historyTick = null;
    }
  }

  Future<void> _openTopupFlow() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _snack('Ingresa un monto válido.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TopupQrScreen(amount: amount),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openTopupFromHistory(String topupId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TopupQrScreen(existingTopupId: topupId),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  String _countdownForTile(Map<String, dynamic> t) {
    final exp = WalletService.parseTopupExpiresAt(t);
    if (exp == null) return '';
    final left = exp.difference(DateTime.now());
    if (left.isNegative) return 'Expirado';
    final m = left.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = left.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
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
                            onPressed: _openTopupFlow,
                            icon: const Icon(Icons.qr_code_rounded),
                            label: const Text('Generar QR'),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Método de verificación: se agrega un monto pequeño en centavos para identificar tu pago. Si sales sin pagar, la recarga aparecerá aquí con cuenta regresiva.',
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.35),
                          ),
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
                  else if (_visibleTopups().isEmpty)
                    Text(
                      'No hay recargas para mostrar. Las pendientes solo aparecen si saliste de la pantalla del QR sin pagar, o si ya enviaste comprobante / fueron procesadas.',
                      style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
                    )
                  else
                    ..._visibleTopups().map((t) {
                      final status = t['status']?.toString() ?? 'pending_proof';
                      final color = switch (status) {
                        'approved' => Colors.green,
                        'rejected' => scheme.error,
                        _ => Colors.orange,
                      };
                      final id = t['id'].toString();
                      final showCd = status == 'pending_proof' &&
                          _resumeIds.contains(id) &&
                          !WalletService.isTopupExpired(t);
                      return Card(
                        child: ListTile(
                          title: Text(
                            'Bs ${t['amount']} · ${t['reference_code']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_statusLabel(status)),
                              if (showCd)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Vence en ${_countdownForTile(t)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Icon(Icons.circle, size: 12, color: color),
                          onTap: (status == 'approved' || status == 'rejected')
                              ? null
                              : () => _openTopupFromHistory(id),
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
