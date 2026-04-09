import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

        // Try to get profile data
        final response = await Supabase.instance.client
            .from('profiles')
            .select('full_name, shop_name')
            .eq('id', user.id)
            .maybeSingle();

        if (response != null) {
          setState(() {
            _shopName = response['shop_name']?.toString().trim() ?? '';
            if (_shopName.isEmpty) _shopName = 'Sin tienda registrada';

            _sellerName = response['full_name']?.toString().trim() ?? '';
            if (_sellerName.isEmpty) _sellerName = 'Sin nombre registrado';
          });
        } else {
          setState(() {
            _shopName = 'Sin tienda registrada';
            _sellerName = 'Sin nombre registrado';
          });
        }
      }
    } catch (e) {
      setState(() {
        _userEmail = 'vendedor@tiendasj.com';
        _shopName = 'Tienda Vendedor SJ';
        _sellerName = 'Vendedor';
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      // Ignorar el error si falla el signOut de Supabase (ej. si no hay sesión activa real)
      debugPrint('Error al cerrar sesión en Supabase: $e');
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Tienda', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFF09CB6B),
                    child: Icon(Icons.store, size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _shopName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Vendedor: $_sellerName',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userEmail,
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildMenuSection([
              _buildMenuItem(
                Icons.settings,
                'Configuración de tienda',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StoreSettingsScreen(),
                    ),
                  );
                  await _loadUserData();
                },
              ),
              _buildMenuItem(Icons.payment, 'Métodos de pago'),
              _buildMenuItem(Icons.local_shipping, 'Envíos'),
            ]),
            const SizedBox(height: 16),
            _buildMenuSection([
              _buildMenuItem(Icons.help_outline, 'Centro de ayuda'),
              _buildMenuItem(Icons.info_outline, 'Acerca de'),
            ]),
            const SizedBox(height: 16),
            Container(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                onTap: () => _logout(context),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(List<Widget> children) {
    return Container(
      color: Colors.white,
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap ?? () {},
    );
  }
}
