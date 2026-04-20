import 'package:shared_preferences/shared_preferences.dart';

const _kEmail = 'eveta_admin_saved_email';
const _kRemember = 'eveta_admin_remember_me';

class LoginPrefs {
  static Future<({String? email, bool remember})> load() async {
    final p = await SharedPreferences.getInstance();
    return (
      email: p.getString(_kEmail),
      remember: p.getBool(_kRemember) ?? false,
    );
  }

  static Future<void> saveRememberedEmail(String email, bool remember) async {
    final p = await SharedPreferences.getInstance();
    if (remember && email.trim().isNotEmpty) {
      await p.setBool(_kRemember, true);
      await p.setString(_kEmail, email.trim().toLowerCase());
    } else {
      await p.setBool(_kRemember, false);
      await p.remove(_kEmail);
    }
  }
}
