import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/sky_service.dart';
import '../services/wallpaper_refresh_service.dart';

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
  static const _channel = MethodChannel('windowsdemeter.com/wallpaper');

  final SkyService _skyService = SkyService();
  Timer? _refreshTimer;
  String? _svgString;
  double _xOffset = 0.5;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleWallpaperChannel);
    _refreshSvg();
    _refreshTimer = Timer.periodic(
      kWallpaperRefreshInterval,
      (_) => _refreshSvg(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSvg();
    }
  }

  Future<void> _refreshSvg() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(kWallpaperLatKey) ?? -33.5227;
      final lon = prefs.getDouble(kWallpaperLonKey) ?? -70.5983;
      final svg = await _skyService.getMapSvgMobile(
        lat: lat,
        lng: lon,
        date: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _svgString = svg;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _handleWallpaperChannel(MethodCall call) async {
    if (call.method != 'onOffsetsChanged') return;

    final args = Map<String, dynamic>.from(call.arguments as Map);
    if (!mounted) return;

    setState(() {
      _xOffset = (args['x'] as num?)?.toDouble() ?? 0.5;
    });
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