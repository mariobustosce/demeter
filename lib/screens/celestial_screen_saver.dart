import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/sky_service.dart';

class CelestialScreenSaver extends StatefulWidget {
  final String? svgString;
  final double? lat;
  final double? lon;
  final DateTime? date;

  const CelestialScreenSaver({
    Key? key,
    this.svgString,
    this.lat,
    this.lon,
    this.date,
  }) : super(key: key);

  @override
  State<CelestialScreenSaver> createState() => _CelestialScreenSaverState();
}

class _CelestialScreenSaverState extends State<CelestialScreenSaver>
    with WidgetsBindingObserver {
  String? _svgString;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.svgString != null && widget.svgString!.isNotEmpty) {
      _svgString = widget.svgString;
      _loading = false;
    } else {
      _fetchSvg();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchSvg();
    }
  }

  Future<void> _fetchSvg() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final service = SkyService();
      final svg = await service.getMapSvgMobile(
        lat: widget.lat,
        lng: widget.lon,
        date: widget.date ?? DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _svgString = svg;
          _loading = false;
          if (svg == null || svg.isEmpty) {
            _error = "No se recibió el mapa del servidor.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white54,
        title: const Text(
          "Cielo Celestial",
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF4FD0E7)),
            SizedBox(height: 16),
            Text("Cargando cielo celestial...", style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    if (_error != null || _svgString == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error ?? "No se pudo cargar el mapa celestial.",
            style: const TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: SvgPicture.string(
        _svgString!,
        fit: BoxFit.contain,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height - kToolbarHeight,
      ),
    );
  }
}

