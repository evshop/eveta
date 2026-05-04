import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/eveta_theme_controller.dart' show evetaThemeMode, kEvetaPortalThemeModePref;
import '../widgets/portal/portal_haptics.dart';
import '../widgets/portal/portal_soft_card.dart';
import '../widgets/portal/portal_tokens.dart';
import '../widgets/portal_cached_image.dart';
import 'appearance_settings_screen.dart';
import 'store_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userEmail = 'Cargando...';
  String _shopName = 'Cargando...';
  String _sellerName = 'Cargando...';
  String? _shopLogoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        setState(() {
          _userEmail = user.email ?? 'vendedor@tiendasj.com';
        });

        final response = await Supabase.instance.client
            .from('profiles_portal')
            .select('full_name, shop_name, shop_logo_url')
            .eq('auth_user_id', user.id)
            .maybeSingle();

        if (response != null) {
          setState(() {
            _shopName = response['shop_name']?.toString().trim() ?? '';
            if (_shopName.isEmpty) _shopName = 'Sin tienda registrada';

            _sellerName = response['full_name']?.toString().trim() ?? '';
            if (_sellerName.isEmpty) _sellerName = 'Sin nombre registrado';

            final rawLogo = response['shop_logo_url']?.toString().trim();
            _shopLogoUrl = (rawLogo == null || rawLogo.isEmpty) ? null : rawLogo;
          });
        } else {
          setState(() {
            _shopName = 'Sin tienda registrada';
            _sellerName = 'Sin nombre registrado';
            _shopLogoUrl = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        _userEmail = 'vendedor@tiendasj.com';
        _shopName = 'Tienda Vendedor SJ';
        _sellerName = 'Vendedor';
        _shopLogoUrl = null;
      });
    }
  }

  Future<void> _showLogoutConfirmDialog(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PortalTokens.radius2xl)),
          insetPadding: const EdgeInsets.symmetric(horizontal: PortalTokens.space2, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PortalTokens.space3,
              PortalTokens.space3,
              PortalTokens.space3,
              PortalTokens.space2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(PortalTokens.radiusMd),
                      ),
                      child: Icon(Icons.logout_rounded, color: scheme.error, size: 26),
                    ),
                    const SizedBox(width: PortalTokens.space2),
                    Expanded(
                      child: Text(
                        '¿Cerrar sesión?',
                        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PortalTokens.space2),
                Text(
                  'Vas a salir de eVeta Portal. Podrás volver a entrar cuando quieras con tu correo y contraseña.',
                  style: tt.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: PortalTokens.space3),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          portalHapticLight();
                          Navigator.pop(ctx, false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.onSurface,
                          side: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: PortalTokens.space2),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          portalHapticMedium();
                          Navigator.pop(ctx, true);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Sí, salir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await _logout(context);
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('Error al cerrar sesión en Supabase: $e');
    } finally {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getInt(kEvetaPortalThemeModePref);
      await prefs.clear();
      if (savedTheme != null) {
        await prefs.setInt(kEvetaPortalThemeModePref, savedTheme);
      }
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Mi tienda', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            PortalTokens.space2,
            PortalTokens.space1,
            PortalTokens.space2,
            PortalTokens.space4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PortalSoftCard(
                padding: const EdgeInsets.all(PortalTokens.space3),
                radius: PortalTokens.radius2xl,
                child: Column(
                  children: [
                    _ShopAvatar(
                      logoUrl: _shopLogoUrl,
                      scheme: scheme,
                    ),
                    const SizedBox(height: PortalTokens.space2),
                    Text(
                      _shopName,
                      textAlign: TextAlign.center,
                      style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
                    ),
                    const SizedBox(height: PortalTokens.space1),
                    Text(
                      _sellerName,
                      textAlign: TextAlign.center,
                      style: tt.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _userEmail,
                      textAlign: TextAlign.center,
                      style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PortalTokens.space3),
              Text(
                'CUENTA',
                style: tt.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: PortalTokens.space1),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: evetaThemeMode,
                builder: (context, mode, _) {
                  return _ProfileTileCard(
                    icon: Icons.palette_outlined,
                    title: 'Apariencia',
                    subtitle: AppearanceSettingsScreen.labelFor(mode),
                    onTap: () {
                      portalHapticLight();
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const AppearanceSettingsScreen()),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: PortalTokens.space2),
              Text(
                'TIENDA',
                style: tt.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: PortalTokens.space1),
              _ProfileTileCard(
                icon: Icons.tune_rounded,
                title: 'Configuración de tienda',
                subtitle: 'Nombre, datos y preferencias',
                onTap: () async {
                  portalHapticLight();
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const StoreSettingsScreen()),
                  );
                  await _loadUserData();
                },
              ),
              const SizedBox(height: 8),
              _ProfileTileCard(
                icon: Icons.payments_outlined,
                title: 'Métodos de pago',
                subtitle: 'Próximamente',
                enabled: false,
                onTap: () => portalHapticSelect(),
              ),
              const SizedBox(height: 8),
              _ProfileTileCard(
                icon: Icons.local_shipping_outlined,
                title: 'Envíos',
                subtitle: 'Próximamente',
                enabled: false,
                onTap: () => portalHapticSelect(),
              ),
              const SizedBox(height: PortalTokens.space3),
              Text(
                'SOPORTE',
                style: tt.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: PortalTokens.space1),
              _ProfileTileCard(
                icon: Icons.help_outline_rounded,
                title: 'Centro de ayuda',
                onTap: () => portalHapticLight(),
              ),
              const SizedBox(height: 8),
              _ProfileTileCard(
                icon: Icons.info_outline_rounded,
                title: 'Acerca de eVeta Portal',
                onTap: () => portalHapticLight(),
              ),
              const SizedBox(height: PortalTokens.space3),
              PortalSoftCard(
                padding: const EdgeInsets.symmetric(horizontal: PortalTokens.space2, vertical: 4),
                radius: PortalTokens.radiusXl,
                child: ListTile(
                  onTap: () {
                    portalHapticLight();
                    _showLogoutConfirmDialog(context);
                  },
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(PortalTokens.radiusMd),
                      border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
                    ),
                    child: Icon(Icons.logout_rounded, color: scheme.error, size: 24),
                  ),
                  title: Text(
                    'Cerrar sesión',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Salir de tu cuenta en este dispositivo',
                    style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: scheme.error.withValues(alpha: 0.8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar: logo de tienda si existe en Supabase; si no, icono de tienda.
class _ShopAvatar extends StatelessWidget {
  const _ShopAvatar({
    required this.logoUrl,
    required this.scheme,
  });

  final String? logoUrl;
  final ColorScheme scheme;

  static const double _size = 104;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: hasLogo ? 0.15 : 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: hasLogo
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.2), width: 2),
                ),
                child: PortalCachedImage(
                  imageUrl: logoUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 256,
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: 0.35),
                      scheme.primary.withValues(alpha: 0.12),
                    ],
                  ),
                ),
                child: Icon(Icons.storefront_rounded, size: 48, color: scheme.primary),
              ),
      ),
    );
  }
}

class _ProfileTileCard extends StatelessWidget {
  const _ProfileTileCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PortalSoftCard(
        padding: EdgeInsets.zero,
        radius: PortalTokens.radiusXl,
        child: ListTile(
          onTap: enabled ? onTap : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: PortalTokens.space2, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: enabled ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(PortalTokens.radiusMd),
            ),
            child: Icon(icon, color: enabled ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.45)),
          ),
          title: Text(title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: subtitle != null
              ? Text(subtitle!, style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant))
              : null,
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: enabled ? scheme.outline : scheme.outline.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}
