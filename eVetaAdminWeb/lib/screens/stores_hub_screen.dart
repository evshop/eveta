import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'store_products_screen.dart';

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

  Widget _minimalStoreTile({
    required Widget leading,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E8EC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final name = _myProfile?['shop_name']?.toString().trim();
    final email = _myProfile?['email']?.toString() ??
        Supabase.instance.client.auth.currentUser?.email ??
        '';
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => StoreProductsScreen(
          sellerId: uid,
          storeTitle: (name != null && name.isNotEmpty) ? name : 'Mi tienda',
          subtitle: email,
          isOfficialAdminStore: true,
        ),
      ),
    );
    _refresh();
  }

  Future<void> _openPartner(Map<String, dynamic> p) async {
    final profileId = p['id']?.toString() ?? '';
    if (profileId.isEmpty) return;
    final rawName = p['shop_name']?.toString().trim() ?? '';
    final email = p['email']?.toString() ?? '';
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => StoreProductsScreen(
          sellerId: profileId,
          storeTitle: rawName.isNotEmpty ? rawName : 'Tienda',
          subtitle: email,
          isOfficialAdminStore: false,
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

    final created = await showDialog<Map<String, String>?>(
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
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, <String, String>{
                            'email': email,
                            'password': p1,
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

    if (created != null && mounted) {
      final em = created['email'] ?? '';
      final pw = created['password'] ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tienda creada'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'La cuenta puede iniciar sesión en el portal eVeta. Las contraseñas no se guardan en texto claro: '
                  'esta es la única vez que verás la contraseña aquí; cópiala o envía recuperación si se pierde.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 14),
                SelectableText('Correo: $em', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                SelectableText('Contraseña: $pw', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: 'Correo: $em\nContraseña: $pw'));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Credenciales copiadas al portapapeles')),
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _minimalStoreTile(
                    onTap: _openMyStore,
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF09CB6B).withValues(alpha: 0.12),
                      child: const Icon(Icons.storefront_rounded, color: Color(0xFF09CB6B)),
                    ),
                    title: (myName != null && myName.isNotEmpty) ? myName : 'Ver mi catálogo',
                    subtitle: myEmail.isNotEmpty ? myEmail : 'Tu cuenta administrador',
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tiendas verificadas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _showCreatePartnerDialog,
                        icon: const Icon(Icons.add_business_rounded, size: 20),
                        label: const Text('Nueva tienda'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca una tienda para ver sus productos como en la app. El ícono de ajustes abre la edición de datos de la tienda.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  if (_partners.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'Aún no hay otras tiendas. Pulsa «Nueva tienda» para crear una cuenta de vendedor.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                        ),
                      ),
                    )
                  else
                    ..._partners.map((p) {
                      final id = p['id']?.toString() ?? '';
                      final name = p['shop_name']?.toString().trim();
                      final sub = p['email']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _minimalStoreTile(
                          onTap: id.isEmpty ? null : () => _openPartner(p),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey.shade100,
                            child: const Icon(Icons.verified_rounded, color: Color(0xFF09CB6B)),
                          ),
                          title: (name != null && name.isNotEmpty) ? name : 'Sin nombre',
                          subtitle: sub,
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
