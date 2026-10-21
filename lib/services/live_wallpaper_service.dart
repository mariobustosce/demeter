import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Canal compartido con el lado nativo.
///
/// Lo atienden dos handlers distintos: `MainActivity` en el proceso de la app
/// (que reenvía al engine del fondo animado) y el propio engine del fondo
/// dentro de `CelestialWallpaperService`.
const MethodChannel kWallpaperChannel = MethodChannel(
  'windowsdemeter.com/wallpaper',
);

/// Puente hacia el fondo de pantalla animado (`CelestialWallpaperService`).
class LiveWallpaperService {
  LiveWallpaperService._();

  /// Abre el selector de Android para activar el fondo animado de la app.
  ///
  /// Devuelve `false` si el sistema no ofrece el selector (algunos launchers
  /// de terceros) o si la plataforma no es Android.
  static Future<bool> openPicker() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await kWallpaperChannel.invokeMethod<bool>(
        'openLiveWallpaperPicker',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('No se pudo abrir el selector de fondo animado: ${e.message}');
      return false;
    }
  }

  /// `true` si el fondo animado de la app está activo ahora mismo.
  static Future<bool> isActive() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await kWallpaperChannel.invokeMethod<bool>(
        'isLiveWallpaperActive',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('No se pudo consultar el fondo animado: ${e.message}');
      return false;
    }
  }

  /// Envía los datos del cielo al engine del fondo animado para que se
  /// redibuje sin volver a pedirlos al servidor.
  ///
  /// Es best-effort: si el fondo no está activo, nadie escucha.
  static Future<void> syncSkyData(Map<String, dynamic> data) async {
    if (!Platform.isAndroid) return;
    try {
      await kWallpaperChannel.invokeMethod('updateData', data);
    } catch (e) {
      debugPrint('Fondo animado no disponible para sincronizar: $e');
    }
  }
}
