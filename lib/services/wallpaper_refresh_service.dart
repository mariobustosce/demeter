import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart' show SvgStringLoader, vg;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'sky_service.dart';

/// Tiempo mínimo entre refrescos automáticos disparados al volver la app al
/// primer plano. El refresco manual (pull-to-refresh o botón) lo ignora.
const Duration kWallpaperRefreshInterval = Duration(minutes: 15);

const String kWallpaperAutoEnabledKey = 'wallpaper_auto_enabled';
const String kWallpaperLatKey = 'wallpaper_lat';
const String kWallpaperLonKey = 'wallpaper_lon';
const String kWallpaperTargetKey = 'wallpaper_target';
const String kWallpaperLastRefreshKey = 'wallpaper_last_refresh';

/// Color de relleno para las zonas que el mapa no cubre.
const int _kWallpaperBackgroundColor = 0xFF0A0A0F;

/// Resolución de respaldo si no podemos leer el tamaño real de la pantalla.
const ui.Size _kFallbackScreenSize = ui.Size(1080, 1920);

/// Orden estable de [WallpaperTarget] para persistirlo como índice.
///
/// No usamos `WallpaperTarget.index` directamente para que un reordenamiento
/// del enum en el paquete no invalide las preferencias ya guardadas.
const List<WallpaperTarget> _kTargetOrder = <WallpaperTarget>[
  WallpaperTarget.home,
  WallpaperTarget.lock,
  WallpaperTarget.both,
];

/// Falla al generar o aplicar el fondo. Se propaga hasta la UI para que el
/// usuario vea el motivo real en lugar de un falso "aplicado".
class WallpaperRefreshException implements Exception {
  const WallpaperRefreshException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Log que sobrevive a release (donde `debugPrint` está anulado por
/// rendimiento). Solo lo usamos para fallas del wallpaper, que de otro modo
/// serían invisibles.
void _logWallpaper(String message, {Object? error}) {
  developer.log(message, name: 'wallpaper', error: error);
  if (kDebugMode) debugPrint('[wallpaper] $message');
}

// ---------------------------------------------------------------------------
// Preferencias
// ---------------------------------------------------------------------------

/// Indica si el usuario habilitó el refresco automático. Por defecto `false`:
/// el fondo no se toca hasta que lo pida explícitamente.
Future<bool> isWallpaperAutoRefreshEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kWallpaperAutoEnabledKey) ?? false;
}

/// Activa o desactiva el refresco automático. Solo debe llamarse desde una
/// acción explícita del usuario.
Future<void> setWallpaperAutoRefreshEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kWallpaperAutoEnabledKey, enabled);
  if (!enabled) {
    // Olvidamos la marca de tiempo para que al reactivar se refresque de
    // inmediato en vez de esperar el resto del intervalo.
    await prefs.remove(kWallpaperLastRefreshKey);
  }
}

/// Destino elegido por el usuario, o `null` si nunca aplicó un fondo.
Future<WallpaperTarget?> loadWallpaperTarget() async {
  final prefs = await SharedPreferences.getInstance();
  final index = prefs.getInt(kWallpaperTargetKey);
  if (index == null || index < 0 || index >= _kTargetOrder.length) return null;
  return _kTargetOrder[index];
}

/// `true` si ya existe una configuración completa de fondo (coordenadas y
/// destino), es decir el usuario aplicó el fondo al menos una vez.
Future<bool> hasWallpaperConfig() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(kWallpaperLatKey) &&
      prefs.containsKey(kWallpaperLonKey) &&
      prefs.containsKey(kWallpaperTargetKey);
}

/// Guarda coordenadas y destino. No toca el flag de auto-refresco: eso es
/// decisión aparte del usuario.
Future<void> persistWallpaperSettings({
  required double lat,
  required double lon,
  required WallpaperTarget target,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(kWallpaperLatKey, lat);
  await prefs.setDouble(kWallpaperLonKey, lon);
  await prefs.setInt(kWallpaperTargetKey, _kTargetOrder.indexOf(target));
}

/// Actualiza solo las coordenadas conocidas, sin marcar el fondo como
/// configurado. La usa el home cada vez que resuelve una ubicación nueva.
Future<void> persistWallpaperCoordinates({
  required double lat,
  required double lon,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(kWallpaperLatKey, lat);
  await prefs.setDouble(kWallpaperLonKey, lon);
}

/// Momento del último refresco aplicado con éxito.
Future<DateTime?> lastWallpaperRefresh() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kWallpaperLastRefreshKey);
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}

// ---------------------------------------------------------------------------
// Refresco
// ---------------------------------------------------------------------------

/// Genera el mapa celeste del momento y lo aplica como fondo del sistema.
///
/// [target] manda sobre la preferencia guardada; si va en `null` se usa el
/// destino que el usuario eligió, y `both` como último recurso.
/// [screenSize] son píxeles físicos; si va en `null` se leen de la vista
/// actual.
///
/// Lanza [WallpaperRefreshException] con un mensaje legible ante cualquier
/// falla, para que quien llama pueda mostrarlo.
Future<void> refreshWallpaperFromServer({
  DateTime? date,
  WallpaperTarget? target,
  ui.Size? screenSize,
}) async {
  if (!Platform.isAndroid) {
    throw const WallpaperRefreshException(
      'El fondo de pantalla solo está disponible en Android.',
    );
  }

  final prefs = await SharedPreferences.getInstance();
  final effectiveTarget =
      target ?? await loadWallpaperTarget() ?? WallpaperTarget.both;

  // Usamos la última ubicación que la app registró en primer plano; nunca
  // pedimos GPS acá para no disparar permisos fuera de contexto.
  final lat = prefs.getDouble(kWallpaperLatKey) ?? kDefaultLatitude;
  final lon = prefs.getDouble(kWallpaperLonKey) ?? kDefaultLongitude;

  _logWallpaper('refresh lat=$lat lon=$lon target=$effectiveTarget');

  final svgString = await SkyService().getMapSvgMobile(
    lat: lat,
    lng: lon,
    date: date ?? DateTime.now(),
  );
  if (svgString == null || svgString.isEmpty) {
    throw const WallpaperRefreshException(
      'El servidor no devolvió el mapa celeste. Revisa tu conexión.',
    );
  }

  final file = await _renderWallpaperFile(svgString, screenSize: screenSize);
  await _applyToSystem(file, effectiveTarget);

  await prefs.setString(
    kWallpaperLastRefreshKey,
    DateTime.now().toIso8601String(),
  );
  _logWallpaper('aplicado correctamente en $effectiveTarget');
}

/// Rasteriza el SVG a un PNG del tamaño exacto de la pantalla y lo deja en el
/// directorio temporal.
Future<File> _renderWallpaperFile(
  String svgString, {
  ui.Size? screenSize,
}) async {
  final size = screenSize ?? _currentScreenSize();
  // El fondo se ve en vertical: lado corto = ancho, lado largo = alto.
  final width = math.max(1, math.min(size.width, size.height).round());
  final height = math.max(1, math.max(size.width, size.height).round());

  // flutter_svg no soporta filtros ni animaciones y lanza DecodeException si
  // aparecen, así que los quitamos antes de decodificar.
  final cleanSvg = svgString
      .replaceAll(RegExp(r'<filter[^>]*>.*?</filter>', dotAll: true), '')
      .replaceAll(RegExp(r'<animate[^>]*>.*?</animate>', dotAll: true), '')
      .replaceAll(RegExp(r'<animate[^>]*/>'), '')
      .replaceAll(RegExp(r'filter="[^"]*"'), '');

  ui.Picture? sourcePicture;
  ui.Picture? composedPicture;
  ui.Image? image;
  try {
    final pictureInfo = await vg.loadPicture(SvgStringLoader(cleanSvg), null);
    sourcePicture = pictureInfo.picture;

    // El SVG viene con su propio viewBox, así que hay que escalarlo y
    // centrarlo a mano: `toImage` solo recorta el lienzo, no ajusta nada.
    final src = pictureInfo.size;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    canvas.drawColor(
      const ui.Color(_kWallpaperBackgroundColor),
      ui.BlendMode.src,
    );

    if (src.width > 0 && src.height > 0) {
      // "cover": llena la pantalla y recorta el excedente, sin deformar.
      final scale = math.max(width / src.width, height / src.height);
      canvas.translate(
        (width - src.width * scale) / 2,
        (height - src.height * scale) / 2,
      );
      canvas.scale(scale);
    }
    canvas.drawPicture(sourcePicture);

    composedPicture = recorder.endRecording();
    image = await composedPicture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw const WallpaperRefreshException(
        'No se pudo generar la imagen del fondo.',
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/celestial_wallpaper_bg.png');
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    _logWallpaper('PNG generado ${width}x$height (${byteData.lengthInBytes} B)');
    return file;
  } on WallpaperRefreshException {
    rethrow;
  } catch (error) {
    _logWallpaper('error rasterizando el SVG', error: error);
    throw WallpaperRefreshException(
      'No se pudo dibujar el mapa celeste: $error',
    );
  } finally {
    image?.dispose();
    composedPicture?.dispose();
    sourcePicture?.dispose();
  }
}

/// Aplica el PNG al destino pedido, verificando el resultado de cada paso.
Future<void> _applyToSystem(File file, WallpaperTarget target) async {
  // Algunos dispositivos (Huawei/Xiaomi) fallan al pedir 'both' de una vez,
  // así que ese caso se aplica en dos pasos.
  final steps = target == WallpaperTarget.both
      ? <WallpaperTarget>[WallpaperTarget.home, WallpaperTarget.lock]
      : <WallpaperTarget>[target];

  for (var i = 0; i < steps.length; i++) {
    if (i > 0) await Future.delayed(const Duration(milliseconds: 500));

    final result = await AsyncWallpaper.setWallpaper(
      WallpaperRequest(
        source: file.path,
        sourceType: WallpaperSourceType.file,
        target: steps[i],
      ),
    );

    if (!result.isSuccess) {
      final message = result.error?.message ?? 'Error desconocido de Android.';
      _logWallpaper(
        'setWallpaper(${steps[i]}) falló: $message',
        error: result.error?.details,
      );
      throw WallpaperRefreshException(
        'Android rechazó aplicar el fondo: $message',
      );
    }
  }
}

/// Tamaño en píxeles físicos de la vista actual.
ui.Size _currentScreenSize() {
  final view = ui.PlatformDispatcher.instance.implicitView ??
      (ui.PlatformDispatcher.instance.views.isNotEmpty
          ? ui.PlatformDispatcher.instance.views.first
          : null);
  final size = view?.physicalSize;
  if (size == null || size.width < 1 || size.height < 1) {
    return _kFallbackScreenSize;
  }
  return size;
}
