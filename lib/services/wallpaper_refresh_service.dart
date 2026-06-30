import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart' show SvgStringLoader, vg;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sky_service.dart';

const String kWallpaperLatKey = 'wallpaper_lat';
const String kWallpaperLonKey = 'wallpaper_lon';
const String kWallpaperTargetKey = 'wallpaper_target';
// Flag para detectar reinicios de MIUI tras cambiar el wallpaper y evitar bucles
const String kWallpaperJustAppliedKey = 'wallpaper_just_applied';

Future<void> persistWallpaperSettings({
  required double lat,
  required double lon,
  required WallpaperTarget target,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final targetIndex = [
    WallpaperTarget.home,
    WallpaperTarget.lock,
    WallpaperTarget.both,
  ].indexOf(target);

  await prefs.setDouble(kWallpaperLatKey, lat);
  await prefs.setDouble(kWallpaperLonKey, lon);
  await prefs.setInt(kWallpaperTargetKey, targetIndex);
}

Future<void> refreshWallpaperFromServer({DateTime? date}) async {
  if (!Platform.isAndroid) return;

  final prefs = await SharedPreferences.getInstance();

  // Leer el target que el usuario seleccionó y guardó en persistWallpaperSettings.
  // Si no hay ninguno guardado, usamos both como fallback seguro.
  final targetIndex = prefs.getInt(kWallpaperTargetKey);
  final _targets = [WallpaperTarget.home, WallpaperTarget.lock, WallpaperTarget.both];
  final target = (targetIndex != null && targetIndex >= 0 && targetIndex < _targets.length)
      ? _targets[targetIndex]
      : WallpaperTarget.both;

  // Ya no usamos "_getCurrentPosition" aquí para no pedir permisos en segundo plano.
  // Es mejor usar siempre la ultima ubicación que la app registró cuando estuvo en primer plano.
  final lat = prefs.getDouble(kWallpaperLatKey) ?? -33.5227;
  final lon = prefs.getDouble(kWallpaperLonKey) ?? -70.5983;

  if (kDebugMode) {
    debugPrint('Actualizando wallpaper: lat=$lat, lon=$lon, target=$target');
  }

  try {
    final svgString = await SkyService().getMapSvgMobile(
      lat: lat,
      lng: lon,
      date: date ?? DateTime.now(),
    );
    if (svgString == null || svgString.isEmpty) {
      if (kDebugMode) debugPrint('Error: SVG vacío o nulo');
      return;
    }

    // Obtener el tamaño físico de la pantalla para renderizar en resolución nativa
    final physicalSize = ui.PlatformDispatcher.instance.views.first.physicalSize;
    // Proteger contra tamaño (0,0) si se ejecuta en background sin vista activa
    final imgWidth = math.max(math.min(physicalSize.width.toInt(), physicalSize.height.toInt()), 1080);
    final imgHeight = math.max(math.max(physicalSize.width.toInt(), physicalSize.height.toInt()), 1920);

    if (kDebugMode) {
      debugPrint('Generando imagen PNG: ${imgWidth}x$imgHeight');
    }

    // Limpiamos los elementos no soportados por flutter_svg para evitar DecodeException
    final cleanSvg = svgString
        .replaceAll(RegExp(r'<filter[^>]*>.*?</filter>', dotAll: true), '')
        .replaceAll(RegExp(r'<animate[^>]*>.*?</animate>', dotAll: true), '')
        .replaceAll(RegExp(r'<animate[^>]*/>'), '')
        .replaceAll(RegExp(r'filter="[^"]*"'), '');

    // Renderizar SVG a PNG (debe ejecutarse en isolate principal)
    final pictureInfo = await vg.loadPicture(SvgStringLoader(cleanSvg), null);
    final image = await pictureInfo.picture.toImage(imgWidth, imgHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    pictureInfo.picture.dispose();
    image.dispose();
    
    if (byteData == null) {
      if (kDebugMode) debugPrint('Error: No se pudo generar PNG');
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/celestial_wallpaper_bg.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());

    if (kDebugMode) {
      debugPrint('Aplicando wallpaper a: $target');
    }

    // Guardamos el flag ANTES de aplicar el wallpaper para sobrevivir el reinicio de MIUI.
    // En MIUI/Xiaomi, al cambiar el fondo de pantalla el sistema destruye y recrea
    // la MainActivity. Al guardar el flag primero, la app detecta al reiniciar que
    // fue una recarga forzada por el sistema y no vuelve a aplicar el wallpaper.
    await prefs.setBool(kWallpaperJustAppliedKey, true);

    // Usamos una sola llamada atómica. En Android esto llama a
    // WallpaperManager.setBitmap(bitmap, null, true, FLAG_SYSTEM | FLAG_LOCK)
    // en un único IPC, evitando el problema de callback perdido de la doble llamada.
    await AsyncWallpaper.setWallpaper(
      WallpaperRequest(
        source: file.path,
        sourceType: WallpaperSourceType.file,
        target: target,
      ),
    );

    if (kDebugMode) {
      debugPrint('Wallpaper aplicado exitosamente a $target');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('refreshWallpaperFromServer error: $e');
    }
  }
}