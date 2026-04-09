import 'package:flutter/material.dart';
import 'package:eveta/common_widget/eveta_circular_back_button.dart';
import 'package:eveta/utils/auth_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.phone,
    this.postVerificationEmail,
  });

  final String phone;
  final String? postVerificationEmail;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Ingresa el código de 6 dígitos');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService.verifyWhatsappOtp(phone: widget.phone, code: code);
      if (widget.postVerificationEmail != null && widget.postVerificationEmail!.isNotEmpty) {
        await AuthService.persistSessionUser(widget.postVerificationEmail!);
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('AuthException(message: ', '').replaceAll(')', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.sendWhatsappOtp(phone: widget.phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código reenviado por WhatsApp')),
      );
    } catch (e) {
      setState(() => _error = 'No se pudo reenviar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar WhatsApp'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: const EvetaCircularBackButton(
          variant: EvetaCircularBackVariant.onLightBackground,
        ),
        leadingWidth: 56,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ingresa el código enviado al ${widget.phone}'),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Código OTP',
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _verify,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verificar'),
            ),
            TextButton(
              onPressed: _isLoading ? null : _resend,
              child: const Text('Reenviar código'),
            ),
          ],
        ),
      ),
    );
  }
}
