import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'official_store_screen.dart';
import 'partner_store_edit_screen.dart';

/// Listado estilo secciones: primero "Mi tienda", luego tiendas verificadas.
class StoresHubScreen extends StatefulWidget {
  const StoresHubScreen({super.key});

  @override
  State<StoresHubScreen> createState() => _StoresHubScreenState();
}

class _StoresHubScreenState extends State<StoresHubScreen> {
  bool _loading = true;
  Map<String, dynamic>? _myProfile;
  List<Map<String, dynamic>> _partners = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final my = await AuthService.fetchMyProfile();
      final list = await AuthService.fetchVerifiedPartnerStores();
      if (!mounted) return;
      setState(() {
        _myProfile = my;
        _partners = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar tiendas: $e')),
      );
    }
  }

  Future<void> _openMyStore() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: const Text('Mi tienda'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: OfficialStoreScreen(),
          ),
        ),
      ),
    );
    _refresh();
  }

  Future<void> _openPartner(String profileId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: const Text('Editar tienda'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PartnerStoreEditScreen(profileId: profileId),
          ),
        ),
      ),
    );
    _refresh();
  }

  Future<void> _showCreatePartnerDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final pass2Ctrl = TextEditingController();
    final fullCtrl = TextEditingController();
    final shopCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var busy = false;
    var showPass = false;
    var showPass2 = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Nueva tienda verificada'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Se creará una cuenta para el portal eVeta. Anota la contraseña: solo se muestra una vez aquí.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
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
                        icon:
                            Icon(showPass2 ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: fullCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del responsable',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: shopCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la tienda',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
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
              onPressed: busy ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      final p1 = passCtrl.text;
                      final p2 = pass2Ctrl.text;
                      final full = fullCtrl.text.trim();
                      final shop = shopCtrl.text.trim();
                      if (email.isEmpty || p1.length < 6 || full.isEmpty || shop.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Completa correo, contraseña (6+), nombre y tienda.'),
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
                        await AuthService.createPartnerSellerAccount(
                          email: email,
                          password: p1,
                          fullName: full,
                          shopName: shop,
                          shopDescription: descCtrl.text.trim(),
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
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

    // Evita el crash: Flutter puede reconstruir una última vez el dialog
    // después de que `showDialog` retorna. Disponer al siguiente frame es seguro.
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        emailCtrl.dispose();
        passCtrl.dispose();
        pass2Ctrl.dispose();
        fullCtrl.dispose();
        shopCtrl.dispose();
        descCtrl.dispose();
      });
    }

    if (ok == true && mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tienda creada'),
          content: const Text(
            'La cuenta ya puede iniciar sesión en el portal eVeta con el correo y la contraseña que definiste.',
          ),
          actions: [
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final myName = _myProfile?['shop_name']?.toString().trim();
    final myEmail = _myProfile?['email']?.toString() ??
        Supabase.instance.client.auth.currentUser?.email ??
        '';

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mi tienda',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF09CB6B).withValues(alpha: 0.15),
                        child: const Icon(Icons.storefront, color: Color(0xFF09CB6B)),
                      ),
                      title: Text(
                        (myName != null && myName.isNotEmpty) ? myName : 'Configurar mi tienda',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        myEmail.isNotEmpty ? myEmail : 'Tu cuenta administrador',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openMyStore,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tiendas verificadas',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _showCreatePartnerDialog,
                        icon: const Icon(Icons.add_business_outlined),
                        label: const Text('Nueva tienda'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cuentas asociadas que pueden operar con eVeta. Inician sesión en el portal con el correo y contraseña que asignes.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  if (_partners.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Aún no hay otras tiendas. Pulsa «Nueva tienda» para crear una cuenta de vendedor.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ..._partners.map((p) {
                      final id = p['id']?.toString() ?? '';
                      final name = p['shop_name']?.toString().trim();
                      final sub = p['email']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey.shade200,
                              child: const Icon(Icons.verified_outlined, color: Color(0xFF09CB6B)),
                            ),
                            title: Text(
                              (name != null && name.isNotEmpty) ? name : 'Sin nombre',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: id.isEmpty ? null : () => _openPartner(id),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
