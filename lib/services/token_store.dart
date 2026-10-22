import 'package:shared_preferences/shared_preferences.dart';

/// Dónde vive el token Sanctum. Todo acceso pasa por aquí, así que mudarlo al
/// almacén seguro (fase 1, paso 2) toca un solo archivo.
class TokenStore {
  static const String _key = 'sanctum_token';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_key);
    return (token == null || token.isEmpty) ? null : token;
  }

  Future<void> write(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
