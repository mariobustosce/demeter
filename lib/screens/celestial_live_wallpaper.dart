import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../services/live_wallpaper_service.dart';
import '../services/sky_service.dart';
import '../services/wallpaper_refresh_service.dart';

/// Tiempo mínimo entre descargas del mapa dentro del fondo animado.
///
/// El fondo se hace visible en cada desbloqueo de pantalla; sin este límite
/// pedíamos el SVG al servidor decenas de veces por hora.
const Duration _kLiveRefreshInterval = Duration(minutes: 15);

class CelestialLiveWallpaperApp extends StatelessWidget {
  const CelestialLiveWallpaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFF0A0A0F),
        child: CelestialLiveWallpaper(),
      ),
    );
  }
}

class CelestialLiveWallpaper extends StatefulWidget {
  const CelestialLiveWallpaper({super.key});

  @override
  State<CelestialLiveWallpaper> createState() => _CelestialLiveWallpaperState();
}

class _CelestialLiveWallpaperState extends State<CelestialLiveWallpaper>
    with WidgetsBindingObserver {
  final SkyService _skyService = SkyService();
  String? _svgString;
  double _xOffset = 0.5;
  bool _loading = true;
  bool _fetching = false;
  DateTime? _lastFetch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    kWallpaperChannel.setMethodCallHandler(_handleWallpaperChannel);
    _refreshSvg(force: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    kWallpaperChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSvg();
    }
  }

  /// Descarga el mapa del cielo. Con [force] en `false` respeta
  /// [_kLiveRefreshInterval] y evita descargas solapadas.
  Future<void> _refreshSvg({bool force = false}) async {
    if (_fetching) return;

    if (!force && _lastFetch != null) {
      if (DateTime.now().difference(_lastFetch!) < _kLiveRefreshInterval) return;
    }

    _fetching = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(kWallpaperLatKey) ?? kDefaultLatitude;
      final lon = prefs.getDouble(kWallpaperLonKey) ?? kDefaultLongitude;
      final svg = await _skyService.getMapSvgMobile(
        lat: lat,
        lng: lon,
        date: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        // Si la descarga falla mantenemos el último cielo dibujado en pantalla
        // en lugar de dejar el fondo en negro.
        if (svg != null && svg.isNotEmpty) {
          _svgString = svg;
          _lastFetch = DateTime.now();
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _fetching = false;
    }
  }

  Future<void> _handleWallpaperChannel(MethodCall call) async {
    switch (call.method) {
      case 'onOffsetsChanged':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        if (!mounted) return;
        setState(() {
          _xOffset = (args['x'] as num?)?.toDouble() ?? 0.5;
        });

      // La app en primer plano acaba de recibir datos nuevos del cielo, así
      // que aprovechamos para redibujar sin esperar el intervalo.
      case 'updateData':
        await _refreshSvg(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _svgString == null || _svgString!.isEmpty) {
      return const SizedBox.expand();
    }

    final horizontalShift = (_xOffset - 0.5) * 40;

    return SizedBox.expand(
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(horizontalShift, 0),
          child: SvgPicture.string(
            _svgString!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }
}
