import 'package:flutter/material.dart';

import '../services/wallet_admin_service.dart';

/// Panel para ver peticiones pendientes, filtrar notificaciones Tasker por monto exacto
/// y re-ejecutar el mismo RPC de conciliación que el webhook (tras script 047).
class WalletPaymentMatchScreen extends StatefulWidget {
  const WalletPaymentMatchScreen({super.key});

  @override
  State<WalletPaymentMatchScreen> createState() => _WalletPaymentMatchScreenState();
}

class _WalletPaymentMatchScreenState extends State<WalletPaymentMatchScreen> {
  late Future<_MatchData> _future;
  Map<String, dynamic>? _selected;
  final Set<String> _busyEventIds = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MatchData> _load() async {
    final topups = await WalletAdminService.fetchPendingTopupsForMatch();
    final events = await WalletAdminService.fetchBankIncomingEvents(limit: 120);
    return _MatchData(topups: topups, events: events);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  static double? _roundAmount(dynamic v) {
    if (v == null) return null;
    if (v is num) return (v.toDouble() * 100).round() / 100;
    final n = double.tryParse(v.toString());
    if (n == null) return null;
    return (n * 100).round() / 100;
  }

  static bool _withinLast24h(String? iso) {
    if (iso == null || iso.isEmpty) return false;
    final t = DateTime.tryParse(iso);
    if (t == null) return false;
    return t.isAfter(DateTime.now().subtract(const Duration(hours: 24)));
  }

  /// Replica el criterio de topup del script 046 (sin bloquear por evento).
  Map<String, dynamic>? _previewTopupForAmount(double amount, List<Map<String, dynamic>> topups) {
    Map<String, dynamic>? best;
    DateTime? bestCreated;
    for (final t in topups) {
      final st = t['status']?.toString() ?? '';
      if (st != 'pending_review' && st != 'pending_proof') continue;
      if (_roundAmount(t['amount']) != amount) continue;
      final exp = DateTime.tryParse(t['expires_at']?.toString() ?? '');
      if (exp == null || !exp.isAfter(DateTime.now())) continue;
      final cr = DateTime.tryParse(t['created_at']?.toString() ?? '');
      if (cr == null || !cr.isAfter(DateTime.now().subtract(const Duration(hours: 24)))) continue;
      if (best == null) {
        best = t;
        bestCreated = cr;
      } else if (bestCreated != null && cr.isAfter(bestCreated)) {
        best = t;
        bestCreated = cr;
      }
    }
    return best;
  }

  List<Map<String, dynamic>> _eventsSameAmount(
    double? amount,
    List<Map<String, dynamic>> events,
  ) {
    if (amount == null) return [];
    return events.where((e) {
      final da = _roundAmount(e['detected_amount']);
      if (da == null || da != amount) return false;
      final ra = e['received_at']?.toString();
      return _withinLast24h(ra);
    }).toList();
  }

  String _profileLine(Map<String, dynamic> topup) {
    final p = topup['profiles'];
    if (p is Map) {
      final name = p['full_name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
      final u = p['username']?.toString().trim();
      if (u != null && u.isNotEmpty) return '@$u';
      final em = p['email']?.toString().trim();
      if (em != null && em.isNotEmpty) return em;
    }
    final uid = topup['user_id']?.toString().trim() ?? '';
    if (uid.isEmpty) return '—';
    if (uid.length > 14) return '${uid.substring(0, 8)}…';
    return 'Usuario $uid';
  }

  Future<void> _runMatch(String eventId) async {
    setState(() => _busyEventIds.add(eventId));
    try {
      final rows = await WalletAdminService.adminRetryMatchBankEvent(eventId);
      if (!mounted) return;
      final msg = rows.isEmpty
          ? 'Sin filas de respuesta (revisa permisos RPC 047).'
          : rows.map((r) => '${r['match_status']} (topup ${r['topup_id']})').join(' · ');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _busyEventIds.remove(eventId));
    }
  }

  String _fmtMoney(double? v) {
    if (v == null) return '—';
    return 'Bs ${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<_MatchData>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Error al cargar', style: TextStyle(color: scheme.error, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${snap.error}'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _reload, child: const Text('Reintentar')),
            ],
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        final topups = data.topups;
        final events = data.events;
        final selected = _selected;
        final selAmount = selected == null ? null : _roundAmount(selected['amount']);

        final sameAmountEvents = _eventsSameAmount(selAmount, events);
        final previewForSelection =
            selAmount == null ? null : _previewTopupForAmount(selAmount, topups);

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Conciliar pagos (Tasker)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(tooltip: 'Actualizar', onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
              ],
            ),
            Text(
              'Comparación en servidor (046): round(detected_amount,2) del evento Tasker = round(amount,2) de la petición en eVetaShop (incluye centavos de verificación). '
              'Además: notificación reciente (<24 h), petición creada <24 h, sin vencer, estados pending_review / pending_proof. '
              '“Conciliar” re-ejecuta el RPC (script 047).',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 14),
            Text('Peticiones pendientes', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 8),
            if (topups.isEmpty)
              Text('No hay recargas pendientes en ventana 24 h.', style: TextStyle(color: scheme.onSurfaceVariant))
            else
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: topups.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final t = topups[i];
                    final id = t['id'].toString();
                    final sel = selected != null && selected['id'].toString() == id;
                    final amt = _roundAmount(t['amount']);
                    return SizedBox(
                      width: 200,
                      child: Material(
                        color: sel ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _selected = Map<String, dynamic>.from(t)),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t['reference_code']?.toString() ?? '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: sel ? scheme.onPrimaryContainer : scheme.onSurface,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _fmtMoney(amt),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: sel ? scheme.onPrimaryContainer : scheme.primary,
                                  ),
                                ),
                                Text(
                                  t['status']?.toString() ?? '',
                                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Petición seleccionada',
              style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: selected == null
                    ? Text(
                        'Toca una petición arriba para ver el detalle y filtrar notificaciones por el mismo monto.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selected['reference_code']?.toString() ?? '—',
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                                ),
                              ),
                              Chip(
                                label: Text(selected['status']?.toString() ?? ''),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _fmtMoney(selAmount),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: scheme.primary),
                          ),
                          const SizedBox(height: 6),
                          Text('Usuario: ${_profileLine(selected)}', style: TextStyle(color: scheme.onSurfaceVariant)),
                          Text(
                            'Creada: ${selected['created_at'] ?? '—'} · Vence: ${selected['expires_at'] ?? '—'}',
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                          if (previewForSelection != null &&
                              previewForSelection['id']?.toString() != selected['id']?.toString()) ...[
                            const SizedBox(height: 10),
                            Material(
                              color: scheme.errorContainer.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  'Hay otra petición más reciente con el mismo monto; el motor del servidor podría acreditar a esa primero.',
                                  style: TextStyle(color: scheme.onErrorContainer, fontSize: 12, height: 1.35),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              selAmount == null
                  ? 'Notificaciones con el mismo monto'
                  : 'Notificaciones Tasker con monto ${_fmtMoney(selAmount)} (últimas 24 h)',
              style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            if (selected == null)
              Text(
                'Selecciona una petición para listar coincidencias por monto.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else if (sameAmountEvents.isEmpty)
              Text(
                'Ninguna notificación reciente con ese monto exacto. Revisa Tasker o el parseo del monto en el webhook.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              ...sameAmountEvents.map((e) {
                final eid = e['id'].toString();
                final busy = _busyEventIds.contains(eid);
                final preview = _previewTopupForAmount(_roundAmount(e['detected_amount'])!, topups);
                final previewId = preview?['id']?.toString();
                final selId = selected['id']?.toString();
                final mismatch = previewId != null && selId != null && previewId != selId;
                final status = e['match_status']?.toString() ?? '—';
                final received = e['received_at']?.toString() ?? '—';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${e['bank_app'] ?? 'App'} · $received',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(status, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (e['title']?.toString().trim().isNotEmpty == true)
                              ? e['title'].toString()
                              : (e['body']?.toString().trim().isNotEmpty == true ? e['body'].toString() : '—'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                        if (mismatch) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Atención: con la regla del servidor, este evento emparejaría primero con ${preview?['reference_code'] ?? previewId}.',
                            style: TextStyle(fontSize: 11, color: scheme.tertiary, fontWeight: FontWeight.w600),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: busy ? null : () => _runMatch(eid),
                            icon: busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.verified_rounded, size: 20),
                            label: Text(busy ? 'Conciliando…' : 'Conciliar / acreditar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _MatchData {
  _MatchData({required this.topups, required this.events});

  final List<Map<String, dynamic>> topups;
  final List<Map<String, dynamic>> events;
}
