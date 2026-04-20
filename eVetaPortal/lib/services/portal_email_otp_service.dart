import 'package:supabase_flutter/supabase_flutter.dart';

class PortalEmailOtpService {
  static SupabaseClient get _client => Supabase.instance.client;

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static Future<void> sendForgotPasswordCode(String email) async {
    final normalized = _normalizeEmail(email);
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw AuthException('Correo inválido.');
    }

    final response = await _client.functions.invoke(
      'send-email-otp',
      body: {
        'email': normalized,
        'purpose': 'password_reset',
        'require_portal_access': true,
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
