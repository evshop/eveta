/// Validaciones para email y teléfono Bolivia (+591 + 8 dígitos).
abstract final class AuthValidators {
  static final RegExp _email = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp boliviaPhoneFull = RegExp(r'^\+591\d{8}$');

  static bool isEmail(String value) => _email.hasMatch(value.trim());

  /// Solo los 8 dígitos locales (sin +591).
  static String? boliviaEightDigits(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa los 8 dígitos de tu celular';
    }
    final d = value.replaceAll(RegExp(r'\D'), '');
    if (d.length != 8) {
      return 'Debe tener exactamente 8 dígitos (Bolivia)';
    }
    return null;
  }

  static String e164FromEightDigits(String eightDigits) {
    final d = eightDigits.replaceAll(RegExp(r'\D'), '');
    return '+591$d';
  }

  static String? emailOnly(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tu correo electrónico';
    }
    final t = value.trim();
    if (!t.contains('@')) {
      return 'Falta el @ en el correo (ej. nombre@gmail.com)';
    }
    final at = t.indexOf('@');
    final local = t.substring(0, at);
    final domain = t.substring(at + 1);
    if (local.isEmpty) {
      return 'Escribe tu nombre o alias antes del @';
    }
    if (domain.isEmpty) {
      return 'Completa el dominio después del @ (ej. gmail.com)';
    }
    if (!domain.contains('.')) {
      return 'Falta la extensión del dominio (.com, .bo, .net, etc.)';
    }
    if (!isEmail(t)) {
      return 'Correo no válido. Revisa puntos, espacios o caracteres raros.';
    }
    return null;
  }

  /// Para campos que aceptan mezcla (p. ej. recuperación en un solo campo).
  static String normalizePhoneForLogin(String raw) {
    final s = raw.trim();
    if (s.contains('@')) return s.toLowerCase();
    final digits = s.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 8) return '+591$digits';
    if (digits.length == 11 && digits.startsWith('591')) {
      return '+591${digits.substring(3)}';
    }
    if (s.startsWith('+591')) {
      final local = digits.startsWith('591') && digits.length >= 11
          ? digits.substring(3)
          : (digits.length > 3 ? digits.substring(digits.length - 8) : digits);
      if (local.length == 8) return '+591$local';
    }
    return s;
  }

  static String? emailOrBoliviaPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa correo o teléfono';
    }
    final t = value.trim();
    if (isEmail(t)) return null;
    final phone = normalizePhoneForLogin(t);
    if (boliviaPhoneFull.hasMatch(phone)) return null;
    return 'Usa un correo válido o +591 y 8 dígitos';
  }

  static String? password(String? v, {int min = 6}) {
    if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
    if (v.length < min) return 'Mínimo $min caracteres';
    return null;
  }

  static String? confirmPassword(String? p1, String? p2) {
    if (p2 == null || p2.isEmpty) return 'Confirma tu contraseña';
    if (p1 != p2) return 'Las contraseñas no coinciden';
    return null;
  }
}
