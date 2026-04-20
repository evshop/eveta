import 'package:supabase_flutter/supabase_flutter.dart';

class PortalEmailOtpService {
  static SupabaseClient get _client => Supabase.instance.client;

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static Future<void> sendForgotPasswordCode(String email) async {
    final normalized = _normalizeEmail(email);
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw AuthException('Correo inválido.');
    }

    final profile = await _client
        .from('profiles')
        .select('id,is_admin,is_seller')
        .ilike('email', normalized)
        .maybeSingle();

    if (profile == null) {
      throw AuthException('No existe una cuenta con ese correo en el portal.');
    }
    final isAdmin = profile['is_admin'] == true;
    final isSeller = profile['is_seller'] == true;
    if (!isAdmin && !isSeller) {
      throw AuthException('Ese correo no tiene acceso al portal.');
    }

    final response = await _client.functions.invoke(
      'send-email-otp',
      body: {
        'email': normalized,
        'purpose': 'password_reset',
      },
    );
    if (response.status != 200) {
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw PortalOtpException(
          message: data['error'].toString(),
          statusCode: response.status,
        );
      }
      throw PortalOtpException(
        message: 'No se pudo enviar el codigo al correo.',
        statusCode: response.status,
      );
    }
  }

  static Future<String> verifyForgotPasswordCode({
    required String email,
    required String code,
  }) async {
    final response = await _client.functions.invoke(
      'verify-email-otp',
      body: {
        'email': _normalizeEmail(email),
        'code': code.trim(),
        'purpose': 'password_reset',
      },
    );
    if (response.status != 200) {
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw PortalOtpException(
          message: data['error'].toString(),
          statusCode: response.status,
        );
      }
      throw PortalOtpException(
        message: 'Codigo invalido.',
        statusCode: response.status,
      );
    }
    final data = response.data;
    if (data is Map && data['reset_token'] != null) {
      return data['reset_token'].toString();
    }
    throw AuthException('No se recibió token para continuar.');
  }

  static Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    final response = await _client.functions.invoke(
      'complete-email-otp-password-reset',
      body: {
        'email': _normalizeEmail(email),
        'reset_token': resetToken.trim(),
        'new_password': newPassword,
      },
    );
    if (response.status != 200) {
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw PortalOtpException(
          message: data['error'].toString(),
          statusCode: response.status,
        );
      }
      throw PortalOtpException(
        message: 'No se pudo actualizar la contrasena.',
        statusCode: response.status,
      );
    }
  }
}

class PortalOtpException implements Exception {
  const PortalOtpException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
