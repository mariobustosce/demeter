import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dónde vive el token Sanctum: en el almacén seguro (Keystore en Android,
/// Keychain en iOS). Todo acceso pasa por aquí.
class TokenStore {
  static const String _key = 'sanctum_token';

  // En iOS el token no sale del equipo: no va en copias ni pasa a otro iPhone.
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<String?> read() async {
    final token = await _secure.read(key: _key);
    return (token == null || token.isEmpty) ? null : token;
  }

  Future<void> write(String token) => _secure.write(key: _key, value: token);

  Future<void> clear() => _secure.delete(key: _key);

  /// Mueve al almacén seguro el token que las versiones anteriores dejaban en
  /// SharedPreferences, en texto plano, y borra la clave vieja. Se llama al
  /// arrancar. Si falla, la clave vieja queda y se reintenta en el próximo
  /// arranque.
  Future<void> migrateLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_key);
      if (legacy == null) return;
      // Si ya hay un token seguro, es de un login más nuevo: el viejo sobra.
      if (legacy.isNotEmpty && await read() == null) await write(legacy);
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('No se pudo migrar el token (${e.runtimeType}).');
    }
  }
}
