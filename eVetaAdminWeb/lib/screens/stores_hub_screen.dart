import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../theme/admin_theme.dart';
import '../utils/cloudinary_image_url.dart';
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
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Error al cargar tiendas: $e'),
        ),
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

  Future<void> _editPortalNote(Map<String, dynamic> p) async {
    final id = p['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final ctrl = TextEditingController(text: p['admin_portal_note']?.toString() ?? '');
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nota de acceso al portal'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Guarda aquí la contraseña o una pista solo para tu equipo (requiere columna admin_portal_note en Supabase). '
                'Supabase Auth no permite leer la contraseña real del usuario.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.35),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Texto (visible solo para admins)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await AuthService.updateAdminPortalNoteForAdmin(profileId: id, note: ctrl.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Text('Nota guardada'),
            ),
          );
        }
        await _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      }
    }
    ctrl.dispose();
  }

  Future<void> _confirmDeletePartner(Map<String, dynamic> p) async {
    final id = p['id']?.toString() ?? '';
    final name = p['shop_name']?.toString().trim();
    final label = (name != null && name.isNotEmpty) ? name : 'esta tienda';
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tienda'),
        content: Text(
          'Se borrarán todos los productos de «$label», la tienda dejará de aparecer como verificada '
          'y se limpiarán los datos de escaparate. La cuenta en Auth sigue existiendo: '
          'puedes borrarla en Supabase → Authentication si lo necesitas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AuthService.deletePartnerStoreForAdmin(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Tienda eliminada del panel.'),
        ),
      );
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
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
                    'Se creará una cuenta para el portal eVeta. La contraseña quedará copiada en la nota interna si configuraste la columna en la base.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
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
                        final r = await AuthService.createPartnerSellerAccount(
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
        fullCtrl.dispose();
        shopCtrl.dispose();
        descCtrl.dispose();
      });
    }

    if (created != null && mounted) {
      final em = created['email'] ?? '';
      final pw = created['password'] ?? '';
      final newUid = created['userId'] ?? '';
      if (newUid.isNotEmpty) {
        await AuthService.trySaveInitialPortalNote(
          userId: newUid,
          email: em,
          password: pw,
        );
      }
      if (!mounted) return;
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
                  'La cuenta puede iniciar sesión en el portal eVeta. Si añadiste la columna admin_portal_note, la contraseña inicial también quedó en la nota de la tienda.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, height: 1.35),
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
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mi tienda',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StoreCard(
                    title: (myName != null && myName.isNotEmpty) ? myName : 'Ver mi catálogo',
                    subtitle: myEmail.isNotEmpty ? myEmail : 'Tu cuenta administrador',
                    verified: true,
                    isMine: true,
                    logoUrl: _myProfile?['shop_logo_url']?.toString(),
                    onTap: _openMyStore,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'TIENDAS VERIFICADAS',
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
                        onPressed: _showCreatePartnerDialog,
                        icon: const Icon(Icons.add_business_rounded, size: 20),
                        label: const Text('Nueva tienda'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca la tarjeta para ver el catálogo. El candado guarda o muestra la nota de acceso (contraseña o pista).',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  if (_partners.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                          child: Text(
                            'Aún no hay otras tiendas. Pulsa «Nueva tienda» para crear una cuenta de vendedor.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (final p in _partners) ...[
                          Builder(
                            builder: (context) {
                              final id = p['id']?.toString() ?? '';
                              final name = p['shop_name']?.toString().trim();
                              final email = p['email']?.toString() ?? '';
                              final note = p['admin_portal_note']?.toString();
                              return _StoreCard(
                                title: (name != null && name.isNotEmpty) ? name : 'Sin nombre',
                                subtitle: email,
                                verified: true,
                                isMine: false,
                                logoUrl: p['shop_logo_url']?.toString(),
                                hasPortalNote: note != null && note.isNotEmpty,
                                onTap: id.isEmpty ? null : () => _openPartner(p),
                                onPortalNote: id.isEmpty ? null : () => _editPortalNote(p),
                                onDelete: id.isEmpty ? null : () => _confirmDeletePartner(p),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
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

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.title,
    required this.subtitle,
    required this.verified,
    required this.isMine,
    this.logoUrl,
    this.hasPortalNote = false,
    this.onTap,
    this.onPortalNote,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final bool verified;
  final bool isMine;
  final String? logoUrl;
  final bool hasPortalNote;
  final VoidCallback? onTap;
  final VoidCallback? onPortalNote;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget avatar;
    final u = logoUrl?.trim();
    if (u != null && u.isNotEmpty) {
      avatar = CircleAvatar(
        radius: 26,
        backgroundColor: scheme.surfaceContainerHighest,
        backgroundImage: NetworkImage(evetaImageDeliveryUrl(u, EvetaImageDelivery.thumb)),
      );
    } else {
      avatar = CircleAvatar(
        radius: 26,
        backgroundColor: isMine ? scheme.primary.withValues(alpha: 0.15) : scheme.surfaceContainerHighest,
        child: Icon(
          isMine ? Icons.storefront_rounded : Icons.verified_rounded,
          color: isMine ? scheme.primary : scheme.primary,
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ),
                            if (verified)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  'Verificada',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                        if (hasPortalNote)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Icon(Icons.key_rounded, size: 14, color: scheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Nota de acceso guardada',
                                  style: TextStyle(fontSize: 11, color: scheme.primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: const Text('Ver catálogo'),
                  ),
                  if (onPortalNote != null)
                    OutlinedButton.icon(
                      onPressed: onPortalNote,
                      icon: Icon(
                        Icons.vpn_key_rounded,
                        size: 18,
                        color: hasPortalNote ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      label: const Text('Acceso portal'),
                    ),
                  if (onDelete != null)
                    OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_outline_rounded, size: 18, color: scheme.error),
                      label: Text('Eliminar', style: TextStyle(color: scheme.error)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
