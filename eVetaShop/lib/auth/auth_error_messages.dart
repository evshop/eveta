import 'package:gotrue/gotrue.dart';

/// Convierte errores de Supabase/GoTrue en textos claros para el usuario.
String friendlyAuthError(Object error) {
  if (error is AuthException) {
    return _fromMessageAndCode(error.message, error.code);
  }
  final raw = error.toString();
  final extracted = _extractLegacyMessage(raw);
  if (extracted != null) {
    return _fromMessageAndCode(extracted, null);
  }
  return 'Algo salió mal. Intenta de nuevo en un momento.';
}

String? _extractLegacyMessage(String raw) {
  const needle = 'message: ';
  final i = raw.indexOf(needle);
  if (i < 0) return null;
  final from = i + needle.length;
  final end = raw.indexOf(', statusCode:', from);
  if (end < 0) return null;
  return raw.substring(from, end);
}

String _fromMessageAndCode(String message, String? code) {
  final m = message.toLowerCase();
  final c = code?.toLowerCase();

  if (c == 'invalid_credentials' ||
      m.contains('invalid login credentials') ||
      m.contains('invalid email or password')) {
    return 'Correo o contraseña incorrectos. Revisa los datos e inténtalo de nuevo.';
  }
  if (m.contains('email not confirmed') || c == 'email_not_confirmed') {
    return 'Confirma tu correo antes de iniciar sesión (revisa la bandeja de entrada).';
  }
  if (m.contains('user already registered') || c == 'user_already_exists') {
    return 'Ese correo ya tiene cuenta. Inicia sesión o usa otro correo.';
  }
  if (m.contains('signup_disabled') || m.contains('signups not allowed')) {
    return 'El registro no está disponible en este momento.';
  }
  if (m.contains('network') || m.contains('socket') || m.contains('connection')) {
    return 'Sin conexión o el servidor no respondió. Revisa tu internet.';
  }
  if (m.contains('too many requests') || c == 'over_request_rate_limit') {
    return 'Demasiados intentos. Espera un momento y vuelve a intentar.';
  }

  if (message.trim().isNotEmpty &&
      !message.contains('AuthApiException') &&
      !message.contains('AuthException(')) {
    return message;
  }
  return 'No se pudo completar la acción. Intenta de nuevo.';
}
