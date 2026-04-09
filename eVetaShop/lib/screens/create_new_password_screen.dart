import 'package:flutter/material.dart';
import 'package:eveta/auth/auth_validators.dart';
import 'package:eveta/auth/widgets/auth_primary_button.dart';
import 'package:eveta/auth/widgets/auth_text_field.dart';
import 'package:eveta/utils/auth_service.dart';

class CreateNewPasswordScreen extends StatefulWidget {
  const CreateNewPasswordScreen({super.key, this.phoneForSignupProfile});

  /// Si viene de registro por SMS, guarda perfil con teléfono. Si es null, solo cambia contraseña (recovery / email link).
  final String? phoneForSignupProfile;

  @override
  State<CreateNewPasswordScreen> createState() => _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _ob1 = true;
  bool _ob2 = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.phoneForSignupProfile != null) {
        await AuthService.finalizePhoneSignup(
          phoneE164: widget.phoneForSignupProfile!,
          password: _p1.text,
        );
      } else {
        await AuthService.updatePassword(_p1.text);
      }
      final email = AuthService.currentUserEmail;
      if (email != null) {
        await AuthService.persistSessionUser(email);
      } else if (widget.phoneForSignupProfile != null) {
        await AuthService.persistSessionUser(widget.phoneForSignupProfile!);
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: scheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Nueva contraseña', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 12),
                Text(
                  'Elige una contraseña segura para tu cuenta.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                ),
                const SizedBox(height: 28),
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: scheme.error)),
                  const SizedBox(height: 16),
                ],
                AuthTextField(
                  controller: _p1,
                  label: 'Nueva contraseña',
                  obscure: _ob1,
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: scheme.onSurface.withValues(alpha: 0.45)),
                  suffix: IconButton(
                    icon: Icon(_ob1 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _ob1 = !_ob1),
                  ),
                  validator: AuthValidators.password,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _p2,
                  label: 'Confirmar contraseña',
                  obscure: _ob2,
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: scheme.onSurface.withValues(alpha: 0.45)),
                  suffix: IconButton(
                    icon: Icon(_ob2 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _ob2 = !_ob2),
                  ),
                  validator: (v) => AuthValidators.confirmPassword(_p1.text, v),
                ),
                const SizedBox(height: 28),
                AuthPrimaryButton(label: 'Guardar', onPressed: _save, loading: _loading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
