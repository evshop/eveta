import 'package:flutter/material.dart';
import 'package:eveta/common_widget/eveta_circular_back_button.dart';
import 'package:eveta/screens/appearance_settings_screen.dart';
import 'package:eveta/screens/saved_addresses_screen.dart';
import 'package:eveta/screens/login_screen.dart';
import 'package:eveta/screens/my_orders_screen.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/theme/eveta_theme_controller.dart';
import 'package:eveta/ui/shop/eveta_ios_settings_group.dart';
import 'package:eveta/utils/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('full_name, username, email, phone')
        .eq('id', user.id)
        .maybeSingle();
    if (!mounted) return;
    setState(() {
      _profile = profile ?? {'email': user.email ?? ''};
    });
  }

  String _initials(String text) {
    final parts = text.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'EV';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String get _displayName {
    final name = _profile?['username']?.toString().trim();
    final fullName = _profile?['full_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    if (fullName != null && fullName.isNotEmpty) return fullName;
    return 'Usuario';
  }

  String get _displayEmail {
    final email = _profile?['email']?.toString().trim();
    return (email == null || email.isEmpty) ? '-' : email;
  }

  String get _displayPhone {
    final phone = _profile?['phone']?.toString().trim();
    return (phone == null || phone.isEmpty) ? '-' : phone;
  }

  void _showLogoutDialog(BuildContext dialogContext) {
    final scheme = Theme.of(dialogContext).colorScheme;
    showDialog<void>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg)),
        title: const Text('¿Cerrar sesión?'),
        content: const Text('¿Seguro que quieres salir de tu cuenta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
            onPressed: () async {
              Navigator.pop(ctx);
              await _handleLogout();
            },
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Text(
                  'Cuenta',
                  style: tt.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.1,
                    fontSize: 34,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: scheme.brightness == Brightness.dark ? 0.35 : 0.22),
                    width: 0.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => _ProfileDetailsScreen(
                            name: _displayName,
                            email: _displayEmail,
                            phone: _displayPhone,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: scheme.primary.withValues(alpha: 0.18),
                            child: Text(
                              _initials(_displayName),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayName,
                                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _displayEmail,
                                  style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant.withValues(alpha: 0.55), size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: EvetaIosSettingsGroupSpacer()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EvetaIosSettingsGroup(
                children: [
                  EvetaIosSettingsTile(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Mis compras',
                    onTap: () {
                      Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const MyOrdersScreen()));
                    },
                  ),
                  EvetaIosSettingsTile(
                    icon: Icons.location_on_outlined,
                    title: 'Direcciones',
                    showDividerAbove: true,
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const SavedAddressesScreen()),
                      );
                    },
                  ),
                  EvetaIosSettingsTile(
                    icon: Icons.payment_outlined,
                    title: 'Métodos de pago',
                    showDividerAbove: true,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Próximamente'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: scheme.primary,
                        ),
                      );
                    },
                  ),
                  EvetaIosSettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Ayuda y soporte',
                    showDividerAbove: true,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Escríbenos desde la app o correo de contacto.'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: scheme.primary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: EvetaIosSettingsGroupSpacer()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EvetaIosSettingsGroup(
                children: [
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: evetaThemeMode,
                    builder: (context, mode, _) {
                      return EvetaIosSettingsTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'Apariencia',
                        subtitle: ShopAppearanceSettingsScreen.labelFor(mode),
                        trailing: Icon(Icons.palette_outlined, color: scheme.onSurfaceVariant.withValues(alpha: 0.65), size: 22),
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(builder: (_) => const ShopAppearanceSettingsScreen()),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: EvetaIosSettingsGroupSpacer()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EvetaIosSettingsGroup(
                children: [
                  EvetaIosSettingsTile(
                    icon: Icons.logout_rounded,
                    title: 'Cerrar sesión',
                    destructive: true,
                    trailing: const SizedBox.shrink(),
                    onTap: () => _showLogoutDialog(context),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _ProfileDetailsScreen extends StatelessWidget {
  const _ProfileDetailsScreen({
    required this.name,
    required this.email,
    required this.phone,
  });

  final String name;
  final String email;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Mi información'),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: const EvetaCircularBackButton(variant: EvetaCircularBackVariant.onLightBackground),
        leadingWidth: 56,
      ),
      body: ListView(
        padding: const EdgeInsets.all(EvetaShopDimens.spaceLg),
        children: [
          _tile(context, 'Nombre', name, Icons.person_outline_rounded),
          const SizedBox(height: EvetaShopDimens.spaceSm),
          _tile(context, 'Correo', email, Icons.email_outlined),
          const SizedBox(height: EvetaShopDimens.spaceSm),
          _tile(context, 'Teléfono', phone, Icons.phone_outlined),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(EvetaShopDimens.radiusLg),
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        subtitle: Text(value, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600, fontSize: 16)),
      ),
    );
  }
}
