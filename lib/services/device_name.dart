import 'dart:math';

import 'package:flutter/foundation.dart';

import 'secure_storage.dart';

/// Nombre de esta instalación para el servidor, como `android:<uuid>`.
///
/// Entrar de nuevo con el mismo nombre revoca los tokens anteriores de esa
/// cuenta en este equipo. Se crea la primera vez y vive en el almacén seguro.
/// El logout no lo borra.
class DeviceName {
  static const String _key = 'device_name';

  // Una sola lectura por proceso: dos logins seguidos no crean dos nombres.
  static Future<String>? _pending;

  static Future<String> get() async {
    final pending = _pending ??= _loadOrCreate();
    try {
      return await pending;
    } catch (_) {
      _pending = null; // Se reintenta en el próximo login.
      rethrow;
    }
  }

  @visibleForTesting
  static void resetForTest() => _pending = null;

  static Future<String> _loadOrCreate() async {
    final saved = await secureStorage.read(key: _key);
    if (saved != null && saved.isNotEmpty) return saved;

    final name = '${defaultTargetPlatform.name.toLowerCase()}:${_uuidV4()}';
    await secureStorage.write(key: _key, value: name);
    return name;
  }

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Versión 4.
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variante RFC 4122.
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
