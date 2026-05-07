import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._();

  static String _fromDartDefine(String name) =>
      const String.fromEnvironment(name, defaultValue: '');

  static String _fromDotenv(String name) => dotenv.env[name] ?? '';

  static String required(String name) {
    final fromDefine = _fromDartDefine(name).trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    final fromEnv = _fromDotenv(name).trim();
    if (fromEnv.isNotEmpty) return fromEnv;
    throw StateError('Missing required env: $name');
  }

  static String optional(String name, {String fallback = ''}) {
    final fromDefine = _fromDartDefine(name).trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    final fromEnv = _fromDotenv(name).trim();
    if (fromEnv.isNotEmpty) return fromEnv;
    return fallback;
  }
}

