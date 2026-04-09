import 'dart:io';
import 'dart:ui' as ui;

import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:flutter/foundation.dart';
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
  if (Platform.isIOS) return; // IOS no soporta cambios de fondo por Workmanager

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await scheduleWallpaperRefresh();
}

Future<void> scheduleWallpaperRefresh({
  Duration initialDelay = const Duration(minutes: 2),
}) async {
  if (Platform.isIOS) return;

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
  if (Platform.isIOS) return;
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
  final prefs = await SharedPreferences.getInstance();
  final targetIndex = prefs.getInt(kWallpaperTargetKey) ?? 2;

  // Ya no usamos "_getCurrentPosition" aquí para no pedir permisos en segundo plano.
  // Es mejor usar siempre la ultima ubicación que la app registró cuando estuvo en primer plano.
  final lat = prefs.getDouble(kWallpaperLatKey) ?? -33.5227;
  final lon = prefs.getDouble(kWallpaperLonKey) ?? -70.5983;

  try {
    final svgString = await SkyService().getMapSvgMobile(
      lat: lat,
      lng: lon,
      date: date ?? DateTime.now(),
    );
    if (svgString == null || svgString.isEmpty) return;

    final pictureInfo = await vg.loadPicture(SvgStringLoader(svgString), null);
    final image = await pictureInfo.picture.toImage(1080, 2400); 
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    pictureInfo.picture.dispose();
    image.dispose();
    if (byteData == null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/celestial_wallpaper_bg.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());

    final targets = [
      WallpaperTarget.home,
      WallpaperTarget.lock,
      WallpaperTarget.both,
    ];
    
    await AsyncWallpaper.setWallpaper(
      WallpaperRequest(
        source: file.path,
        sourceType: WallpaperSourceType.file,
        target: targets[targetIndex.clamp(0, targets.length - 1)],
      ),
    );

    await prefs.setString(kWallpaperLastRefreshKey, DateTime.now().toIso8601String());
  } catch (e) {
    if (kDebugMode) {
      print("Error refrescando wallpaper de fondo: $e");
    }
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kWallpaperTask) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final autoRefreshEnabled = prefs.getBool(kWallpaperAutoEnabledKey) ?? false;
      if (!autoRefreshEnabled) return true;

      await refreshWallpaperFromServer(date: DateTime.now());
    } catch (_) {
      // Si falla, el workmanager lo reintentará conforme a sus politicas
    }

    return true;
  });
}