import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:eveta/common_widget/eveta_circular_back_button.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eveta/screens/privacy_screen.dart';
import 'package:eveta/screens/terms_screen.dart';
import 'package:eveta/utils/auth_service.dart';

/// Pantalla para completar el perfil después de iniciar sesión con Google.
/// El usuario ingresa: username, teléfono y contraseña (para poder iniciar con email/número + contraseña después).
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController.text = AuthService.currentUserEmail ?? '';
    _hydrateExistingProfileData();
  }

  Future<void> _hydrateExistingProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('username, phone')
        .eq('id', user.id)
        .maybeSingle();
    if (!mounted || profile == null) return;
    _usernameController.text = (profile['username'] ?? '').toString();
    final phone = (profile['phone'] ?? '').toString();
    _phoneController.text = phone.replaceFirst('+591', '');
  }

  String _buildPhoneWithPrefix() => '+591${_phoneController.text.trim()}';

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleComplete() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordController.text;
    if (password != _confirmPasswordController.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService.completeProfileFromGoogle(
        username: _usernameController.text.trim(),
        phone: _buildPhoneWithPrefix(),
        password: password,
      );
      await AuthService.persistSessionUser(
        AuthService.currentUserEmail ?? '',
      );

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } catch (e) {
      final raw = e.toString();
      setState(() {
        _error = raw
            .replaceFirst('AuthException(message: ', '')
            .replaceAll(')', '')
            .trim();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completa tu cuenta'),
        backgroundColor: const Color(0xFF09CB6B),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: const EvetaCircularBackButton(
          variant: EvetaCircularBackVariant.onDarkBackground,
        ),
        leadingWidth: 56,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Vinculaste tu cuenta de Google. Completa estos datos para poder iniciar sesión también con correo o número y contraseña.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Correo (de Google)',
                  labelStyle: TextStyle(color: Colors.grey.shade600),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Nombre de usuario',
                  labelStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF09CB6B)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 3) ? 'Mínimo 3 caracteres' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: InputDecoration(
                  labelText: 'Número de teléfono',
                  prefixText: '+591 ',
                  labelStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF09CB6B)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Número obligatorio';
                  if (v.trim().length != 8) return 'Debe tener 8 dígitos';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Contraseña (para iniciar con correo/número después)',
                  labelStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF09CB6B)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  labelStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF09CB6B)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Confirma tu contraseña' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  children: [
                    const TextSpan(text: 'Al completar aceptas nuestros '),
                    TextSpan(
                      text: 'Términos y Condiciones',
                      style: const TextStyle(
                        color: Color(0xFF09CB6B),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TermsScreen()),
                          );
                        },
                    ),
                    const TextSpan(text: ' y '),
                    TextSpan(
                      text: 'Política de Privacidad',
                      style: const TextStyle(
                        color: Color(0xFF09CB6B),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                          );
                        },
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF09CB6B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Completar y entrar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
