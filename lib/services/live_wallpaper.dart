import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/wallpaper_link.dart';

// La prueba técnica de la fase 5 (docs/medicion-fondo-animado.md). Se elige al
// compilar con --dart-define; la app publicada no los lleva.
const String _kPainter = String.fromEnvironment('FONDO_PINTOR');
const int _kFps = int.fromEnvironment('FONDO_FPS');
const bool _kMeasure = bool.fromEnvironment('FONDO_MEDIR');

/// Lo que quedó puesto en el fondo animado del teléfono.
typedef WallpaperChoice = ({int favoriteId, WallpaperMode mode});

/// Puente con el fondo animado nativo (`CelestialWallpaperService`, solo
/// Android). El servicio corre en su propio proceso y lee lo que `MainActivity`
/// deja en un archivo privado, fuera del backup.
class LiveWallpaper {
  LiveWallpaper({MethodChannel? channel, bool? android, String? webBase})
      : _channel = channel ?? const MethodChannel('windowsdemeter.com/wallpaper'),
        _android = android ?? Platform.isAndroid,
        _webBase = webBase;

  /// La que usa la app. Los tests pueden reemplazarla.
  static LiveWallpaper instance = LiveWallpaper();

  final MethodChannel _channel;
  final bool _android;
  final String? _webBase;

  /// `false` fuera de Android o si el teléfono no admite fondos animados.
  Future<bool> isSupported() async => await _ask<bool>('isSupported') ?? false;

  /// `true` si el fondo de pantalla de ahora es el nuestro.
  Future<bool> isActive() async => await _ask<bool>('isActive') ?? false;

  /// El favorito y el modo guardados, aunque el fondo no esté puesto.
  Future<WallpaperChoice?> current() async {
    final raw = await _ask<Map<Object?, Object?>>('current');
    final id = raw?['favorito'];
    final mode = WallpaperMode.fromName(raw?['modo'] as String?);
    if (id is! int || mode == null) return null;
    return (favoriteId: id, mode: mode);
  }

  /// Deja [url] (una de `urls` del fondo) para el servicio, que la carga al
  /// volver a verse. Lanza si no es la página del fondo o no se pudo guardar.
  Future<void> configure(
    String url, {
    required int favoriteId,
    required WallpaperMode mode,
  }) async {
    if (!_android) throw UnsupportedError('El fondo animado es solo de Android.');
    if (!isWallpaperUrl(url, webBase: _webBase)) {
      throw ArgumentError('No es la página del fondo animado.');
    }
    await _channel.invokeMethod<bool>('configure', {
      'url': url,
      'favorito': favoriteId,
      'modo': mode.name,
      if (_kPainter.isNotEmpty) 'pintor': _kPainter,
      if (_kFps > 0) 'fps': _kFps,
      if (_kMeasure) 'medir': true,
    });
  }

  /// El selector de Android, ya en nuestro fondo. `false` si el teléfono no
  /// lo abre.
  Future<bool> openPicker() async => await _ask<bool>('openPicker') ?? false;

  /// Solo `/lively/m/…` de nuestro servidor, por el mismo esquema y puerto.
  static bool isWallpaperUrl(String url, {String? webBase}) {
    final uri = Uri.tryParse(url);
    final base = Uri.parse(webBase ?? kWebBase);
    return uri != null &&
        uri.scheme == base.scheme &&
        uri.host == base.host &&
        uri.port == base.port &&
        uri.userInfo.isEmpty &&
        uri.path.startsWith('/lively/m/') &&
        !uri.pathSegments.any((s) => s == '..' || s == '.');
  }

  /// `null` fuera de Android o si el lado nativo falla. El error no lleva la
  /// URL.
  Future<T?> _ask<T>(String method) async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<T>(method);
    } on PlatformException catch (e) {
      debugPrint('Fondo animado: $method falló (${e.code}).');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// Lo que dejó el fondo de pantalla anterior a la fase 5: sus prefs (con
/// coordenadas) y el PNG que rasterizaba. Nunca lanza.
Future<void> forgetLegacyWallpaper() async {
  const keys = [
    'wallpaper_auto_enabled',
    'wallpaper_lat',
    'wallpaper_lon',
    'wallpaper_target',
    'wallpaper_last_refresh',
  ];
  try {
    final prefs = await SharedPreferences.getInstance();
    for (final key in keys) {
      if (prefs.containsKey(key)) await prefs.remove(key);
    }
    final png = File('${(await getTemporaryDirectory()).path}/celestial_wallpaper_bg.png');
    if (await png.exists()) await png.delete();
  } catch (e) {
    debugPrint('No se limpió el fondo anterior (${e.runtimeType}).');
  }
}
