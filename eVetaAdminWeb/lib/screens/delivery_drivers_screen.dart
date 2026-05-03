import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/admin_theme.dart';

class DeliveryDriversScreen extends StatefulWidget {
  const DeliveryDriversScreen({super.key});

  @override
  State<DeliveryDriversScreen> createState() => _DeliveryDriversScreenState();
}

class _DeliveryDriversScreenState extends State<DeliveryDriversScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _drivers = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final list = await AuthService.fetchDeliveryDriversForAdmin();
      if (!mounted) return;
      setState(() {
        _drivers = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Error al cargar repartidores: $e'),
        ),
      );
    }
  }

  Future<void> _showCreateDriverDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final pass2Ctrl = TextEditingController();
    final nameCtrl = TextEditingController();
    var busy = false;
    var showPass = false;
    var showPass2 = false;

    final created = await showDialog<Map<String, String>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Nuevo repartidor'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Se creará una cuenta para iniciar sesión en eVetaDelivery.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo (inicio de sesión)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    obscureText: !showPass,
                    decoration: InputDecoration(
                      labelText: 'Contraseña (mín. 6 caracteres)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: showPass ? 'Ocultar' : 'Mostrar',
                        onPressed: () => setDlg(() => showPass = !showPass),
                        icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pass2Ctrl,
                    obscureText: !showPass2,
                    decoration: InputDecoration(
                      labelText: 'Repetir contraseña',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: showPass2 ? 'Ocultar' : 'Mostrar',
                        onPressed: () => setDlg(() => showPass2 = !showPass2),
                        icon: Icon(showPass2 ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext, null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      final p1 = passCtrl.text;
                      final p2 = pass2Ctrl.text;
                      final full = nameCtrl.text.trim();
                      if (email.isEmpty || p1.length < 6 || full.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Completa correo, contraseña (6+) y nombre.'),
                          ),
                        );
                        return;
                      }
                      if (p1 != p2) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Las contraseñas no coinciden.')),
                        );
                        return;
                      }
                      setDlg(() => busy = true);
                      try {
                        final r = await AuthService.createDeliveryDriverAccount(
                          email: email,
                          password: p1,
                          fullName: full,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, <String, String>{
                            'email': r.email,
                            'password': p1,
                            'userId': r.userId,
                          });
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setDlg(() => busy = false);
                      }
                    },
              child: const Text('Crear cuenta'),
            ),
          ],
        ),
      ),
    );

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        emailCtrl.dispose();
        passCtrl.dispose();
        pass2Ctrl.dispose();
        nameCtrl.dispose();
      });
    }

    if (created != null && mounted) {
      final em = created['email'] ?? '';
      final pw = created['password'] ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Repartidor creado'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Estas credenciales son para iniciar sesión en eVetaDelivery.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                SelectableText('Correo: $em', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                SelectableText(
                  'Contraseña: $pw',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: 'Correo: $em\nContraseña: $pw'));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Credenciales copiadas')),
                  );
                }
              },
              child: const Text('Copiar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'REPARTIDORES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        onPressed: _showCreateDriverDialog,
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                        label: const Text('Nuevo repartidor'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea y administra cuentas que inician sesión en la app eVetaDelivery.',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                  else if (_drivers.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                          child: Text(
                            'Aún no hay repartidores. Pulsa «Nuevo repartidor» para crear una cuenta.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                          ),
                        ),
                      ),
                    )
                  else
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Correo')),
                            DataColumn(label: Text('Nombre')),
                            DataColumn(label: Text('Activo')),
                            DataColumn(label: Text('Creado')),
                          ],
                          rows: [
                            for (final d in _drivers)
                              DataRow(
                                cells: [
                                  DataCell(Text(d['email']?.toString() ?? '')),
                                  DataCell(Text(d['full_name']?.toString() ?? '')),
                                  DataCell(Text((d['is_active'] == true) ? 'Sí' : 'No')),
                                  DataCell(Text((d['created_at'] ?? '').toString())),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

