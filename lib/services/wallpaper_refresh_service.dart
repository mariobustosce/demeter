import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart' show SvgStringLoader, vg;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'sky_service.dart';

const Duration kWallpaperRefreshInterval = Duration(minutes: 15);
const String kWallpaperTask = 'celestialWallpaperUpdate';
const String kWallpaperAutoEnabledKey = 'wallpaper_auto_enabled';
const String kWallpaperLatKey = 'wallpaper_lat';
const String kWallpaperLonKey = 'wallpaper_lon';
const String kWallpaperTargetKey = 'wallpaper_target';
const String kWallpaperLastRefreshKey = 'wallpaper_last_refresh';

Future<void> initializeWallpaperRefreshWorker() async {
  if (!Platform.isAndroid) return; // Solo Android soporta Workmanager y AsyncWallpaper

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await scheduleWallpaperRefresh();
}

Future<void> scheduleWallpaperRefresh({
  Duration initialDelay = const Duration(minutes: 2),
}) async {
  if (!Platform.isAndroid) return;

  debugPrint('scheduleWallpaperRefresh: active, initialDelay=$initialDelay');

  await Workmanager().registerPeriodicTask(
    kWallpaperTask, // Un id simple para la tarea
    kWallpaperTask,
    frequency: kWallpaperRefreshInterval,
    initialDelay: initialDelay,
    // Usamos keep para que si la app se abre no se reinicie el contador del task
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}

Future<void> cancelWallpaperRefresh() async {
  if (!Platform.isAndroid) return;
  await Workmanager().cancelByUniqueName(kWallpaperTask);
}

Future<void> persistWallpaperSettings({
  required double lat,
  required double lon,
  required WallpaperTarget target,
  bool autoRefreshEnabled = true,
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
  await prefs.setBool(kWallpaperAutoEnabledKey, autoRefreshEnabled);
}

Future<void> refreshWallpaperFromServer({DateTime? date}) async {
  if (!Platform.isAndroid) return;

  final prefs = await SharedPreferences.getInstance();
  
  // Siempre usar BOTH para las actualizaciones periódicas o de inicio
  // para asegurar que el usuario vea el cambio en ambos lados
  final target = WallpaperTarget.both;

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
    final physicalSize = ui.window.physicalSize;
    final imgWidth = math.min(physicalSize.width.toInt(), physicalSize.height.toInt());
    final imgHeight = math.max(physicalSize.width.toInt(), physicalSize.height.toInt());

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
    
    if (target == WallpaperTarget.both) {
      // Algunos dispositivos (ej: Huawei/Xiaomi) fallan al pasar 'both' de una vez.
      // Mejor aplicarlo en dos pasos: primero home, luego lock.
      await AsyncWallpaper.setWallpaper(
        WallpaperRequest(
          source: file.path,
          sourceType: WallpaperSourceType.file,
          target: WallpaperTarget.home,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      await AsyncWallpaper.setWallpaper(
        WallpaperRequest(
          source: file.path,
          sourceType: WallpaperSourceType.file,
          target: WallpaperTarget.lock,
        ),
      );
    } else {
      await AsyncWallpaper.setWallpaper(
        WallpaperRequest(
          source: file.path,
          sourceType: WallpaperSourceType.file,
          target: target,
        ),
      );
    }

    await prefs.setString(kWallpaperLastRefreshKey, DateTime.now().toIso8601String());
    if (kDebugMode) {
      debugPrint('Wallpaper aplicado exitosamente a $target');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('refreshWallpaperFromServer error: $e');
    }
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  // Necesario para usar Flutter rendering (vg.loadPicture, picture.toImage) en background
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('callbackDispatcher: background task started');

  Workmanager().executeTask((task, inputData) async {
    debugPrint('callbackDispatcher: task=$task');
    if (task != kWallpaperTask) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final autoRefreshEnabled = prefs.getBool(kWallpaperAutoEnabledKey) ?? false;
      if (!autoRefreshEnabled) {
        debugPrint('callbackDispatcher: wallpaper refresh disabled');
        return true;
      }

      await refreshWallpaperFromServer(date: DateTime.now());
    } catch (e) {
      // Si falla, el workmanager lo reintentará conforme a sus políticas
      debugPrint('callbackDispatcher error: $e');
    }

    return true;
  });
}