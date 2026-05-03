import 'package:eveta/utils/wallet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recargas [pending_proof] sin comprobante: solo se listan en historial si el usuario
/// salió de la pantalla del QR (reanudación). Se guardan aquí los IDs.
class WalletResumePrefs {
  WalletResumePrefs._();

  static const _key = 'wallet_topup_resume_ids_v1';

  static Future<Set<String>> getIds() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_key) ?? []).toSet();
  }

  static Future<void> _save(Set<String> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, ids.toList());
  }

  static Future<void> addId(String id) async {
    if (id.isEmpty) return;
    final s = await getIds();
    s.add(id);
    await _save(s);
  }

  static Future<void> removeId(String id) async {
    if (id.isEmpty) return;
    final s = await getIds();
    if (s.remove(id)) await _save(s);
  }

  /// Al salir de la pantalla QR: si aún no pagó / no subió comprobante, queda reanudable en historial.
  static Future<void> markLeftWithoutCompleting(Map<String, dynamic> topup) async {
    final id = topup['id']?.toString();
    if (id == null || id.isEmpty) return;

    final status = topup['status']?.toString() ?? '';
    if (status == 'approved' || status == 'rejected' || status == 'expired') {
      await removeId(id);
      return;
    }

    final exp = WalletService.parseTopupExpiresAt(topup);
    if (exp != null && !exp.isAfter(DateTime.now())) {
      await removeId(id);
      return;
    }

    await addId(id);
  }

  /// Limpia IDs que ya no aplican (recarga desaparecida del servidor, expirada, cerrada).
  static Future<Set<String>> pruneAndGetValid(
    List<Map<String, dynamic>> serverTopups,
  ) async {
    final byId = <String, Map<String, dynamic>>{};
    for (final t in serverTopups) {
      final id = t['id']?.toString();
      if (id != null && id.isNotEmpty) byId[id] = t;
    }

    final now = DateTime.now();
    final current = await getIds();
    final next = <String>{};

    for (final id in current) {
      final t = byId[id];
      if (t == null) continue;

      final status = t['status']?.toString() ?? '';
      if (status != 'pending_proof') continue;

      final exp = WalletService.parseTopupExpiresAt(t);
      if (exp != null && !exp.isAfter(now)) continue;

      next.add(id);
    }

    await _save(next);
    return next;
  }
}
