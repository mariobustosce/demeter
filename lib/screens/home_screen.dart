import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:async_wallpaper/async_wallpaper.dart';
import '../services/auth_service.dart';
import '../services/sky_service.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user.dart';
import 'astral_charts_screen.dart';
import 'oracle_consultations_screen.dart';

// Colores celestiales (WindowsDemeter)
const backgroundColor = Color(0xFF0A0A0F);
const accentCyan = Color(0xFF4FD0E7);
const accentPurple = Color(0xFF8B5CF6);
const cardBackground = Color(0xEF0F172A);
const textColor = Color(0xFFF7FAFC);
const secondaryTextColor = Color(0xFF94A3B8);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  final SkyService _skyService = SkyService();

  late Future<User?> _userFuture;
  late Future<Map<String, dynamic>?> _skyMapFuture;
  late Future<Map<String, dynamic>> _astralProfileFuture;

  // Controles del Cielo
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userFuture = _authService.getMe();

    // Asignar futures simulados primero para que FutureBuilder espere sin fallar
    _skyMapFuture = Future.value(null);
    _astralProfileFuture = Future<Map<String, dynamic>>.delayed(
      const Duration(
        days: 1,
      ), // Simula carga perpetua hasta que respondan los correctos
      () => {},
    );

    _initLocationAndData();
  }

  Future<void> _initLocationAndData() async {
    try {
      // Intentamos obtener la ubicación inicial para rellenar los campos
      // Usamos el servicio de geolocator directamente o asumimos valores por defecto
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          // SOLO UNA PETICION de locación, evitamos llamadas duplicadas y crash de LocationManager
          final pos = await Geolocator.getCurrentPosition();
          if (mounted) {
            setState(() {
              _latController.text = pos.latitude.toString();
              _lonController.text = pos.longitude.toString();
            });
          }
        }
      }
    } catch (e) {
      print("Error obteniendo ubicación inicial UI: $e");
    }

    if (mounted) {
      // Una vez la ubicación fue resuelta (o falló), hace mos una única llamada a las API
      _updateSkyData(initial: true);
    }
  }

  void _updateSkyData({bool initial = false}) {
    // Si no es un año válido, no hacemos nada para evitar crashes
    if (_selectedDate.year < 0) return;

    final dt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    double? lat = double.tryParse(_latController.text);
    double? lon = double.tryParse(_lonController.text);

    // Limpiamos los futures para que el FutureBuilder muestre el loader
    if (!initial) {
      setState(() {
        _skyMapFuture = Future.value(null);
      });
    }

    final skyFuture = _skyService.getCelestialMap(lat: lat, lng: lon, date: dt);
    final astralFuture = _skyService.getAstralProfile(
      lat: lat,
      lng: lon,
      date: dt,
    );

    setState(() {
      _skyMapFuture = skyFuture;
      _astralProfileFuture = astralFuture;
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: accentCyan,
              onPrimary: backgroundColor,
              surface: cardBackground,
              onSurface: textColor,
            ),
            dialogTheme: DialogThemeData(backgroundColor: backgroundColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _updateSkyData();
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: accentCyan,
              onPrimary: backgroundColor,
              surface: cardBackground,
              onSurface: textColor,
            ),
            dialogTheme: DialogThemeData(backgroundColor: backgroundColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
      _updateSkyData();
    }
  }

  Future<void> _searchLocationAddress() async {
    final query = _locationController.text;
    if (query.isEmpty) return;

    // Mostrar loading o algo visual podría ser útil, pero por ahora directo
    final result = await _skyService.searchLocation(query);
    if (result != null && mounted) {
      setState(() {
        _latController.text = result['lat'].toString();
        _lonController.text = result['lon'].toString();
      });
      _updateSkyData();
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ubicación no encontrada")),
        );
    }
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "--:--";
    }
  }

  String _timeRemaining(String isoString) {
    try {
      final target = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = target.difference(now);

      if (difference.isNegative) return "Finalizado";
      return "${difference.inHours}h ${difference.inMinutes.remainder(60)}m";
    } catch (e) {
      return "";
    }
  }

  Future<void> _setWallpaper(String svgString) async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preparando fondo de pantalla..."),
          duration: Duration(seconds: 2),
        ),
      );

      // 1. Convertir SVG a una imagen de alta resolución (tipo fondo de pantalla)
      final pictureInfo = await vg.loadPicture(
        SvgStringLoader(svgString),
        null,
      );

      // Renderizamos a una resolución apropiada (1080x2400 por ejemplo)
      final image = await pictureInfo.picture.toImage(1080, 2400);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null)
        throw Exception("Error al procesar la imagen celeste.");

      // 2. Guardar en un archivo temporal
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/oraculo_bg_wallpaper.png');
      await file.writeAsBytes(pngBytes);

      // 3. Establecer como fondo de pantalla
      final result = await AsyncWallpaper.setWallpaper(
        WallpaperRequest(
          source: file.path,
          sourceType: WallpaperSourceType.file,
          target: WallpaperTarget.both,
        ),
      );

      if (mounted) {
        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("¡Fondo de pantalla actualizado con éxito!"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "No se pudo establecer el fondo. Error: ${result.error?.message ?? 'Desconocido'}",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error interno: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  bool _isBodyVisible(String? riseStr, String? setStr) {
    if (riseStr == null || setStr == null) return false;
    try {
      final rise = DateTime.parse(riseStr);
      final setTime = DateTime.parse(setStr);
      final current = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Si ambos tienen igual fecha aproximada pero la puesta cruza a la madrugada
      if (setTime.isAfter(rise)) {
        return current.isAfter(rise) && current.isBefore(setTime);
      } else {
        // La puesta de sol está registrada como hora "menor", típicamente al día siguiente
        return current.isAfter(rise) || current.isBefore(setTime);
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              size: 20,
              color: secondaryTextColor,
            ),
            tooltip: "Cerrar sesión",
            onPressed: () async {
              await _authService.logout();
              if (mounted) Navigator.pushReplacementNamed(context, "/login");
            },
          ),
          title: Container(
            height: 38,
            decoration: BoxDecoration(
              color: cardBackground.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accentCyan.withOpacity(0.1)),
            ),
            child: TabBar(
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: accentCyan.withOpacity(0.1),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: accentCyan,
              unselectedLabelColor: secondaryTextColor,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
              tabs: const [
                Tab(text: "HOME"),
                Tab(text: "CONSULTAS"),
                Tab(text: "CARTAS"),
              ],
            ),
          ),
          centerTitle: true,
          actions: [
            FutureBuilder<Map<String, dynamic>?>(
              future: _skyMapFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data?["svg"] != null) {
                  return IconButton(
                    icon: const Icon(
                      Icons.wallpaper_rounded,
                      size: 20,
                      color: accentCyan,
                    ),
                    tooltip: "Establecer como fondo de pantalla",
                    onPressed: () => _setWallpaper(snapshot.data!["svg"]),
                  );
                }
                return const SizedBox(width: 48); // Espacio simétrico
              },
            ),
          ],
        ),
        body: TabBarView(
          physics:
              const NeverScrollableScrollPhysics(), // Evita conflicto con gestos
          children: [
            // TAB 1: HOME
            Column(
              children: [
                // 1. ZONA ESTÁTICA: HORIZONTE DEL ORÁCULO (SVG)
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: cardBackground,
                    border: Border(
                      bottom: BorderSide(
                        color: accentCyan.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: FutureBuilder<Map<String, dynamic>?>(
                    future: _skyMapFuture,
                    builder: (context, skySnapshot) {
                      Widget svgContent;
                      String locationText = "Conectando con los astros...";

                      if (skySnapshot.connectionState ==
                          ConnectionState.waiting) {
                        svgContent = const Expanded(
                          child: Center(
                            child: CircularProgressIndicator(color: accentCyan),
                          ),
                        );
                      } else if (skySnapshot.hasData &&
                          skySnapshot.data?['svg'] != null) {
                        final data = skySnapshot.data!;
                        locationText =
                            data['location'] ?? "Ubicación desconocida";

                        svgContent = Expanded(
                          child: ClipRect(
                            child: InteractiveViewer(
                              boundaryMargin: const EdgeInsets.all(
                                double.infinity,
                              ),
                              minScale: 0.1,
                              maxScale: 10.0,
                              alignment: Alignment.center,
                              child: SvgPicture.string(
                                data['svg'].toString().trim(),
                                width: double.infinity,
                                height: double.infinity,
                                fit:
                                    BoxFit.contain, // Centrado de forma natural
                                placeholderBuilder: (context) => const Center(
                                  child: CircularProgressIndicator(
                                    color: accentCyan,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      } else {
                        svgContent = const Expanded(
                          child: Center(
                            child: Text(
                              "No se pudo revelar el horizonte.",
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          const SizedBox(height: 10),
                          const Text(
                            "Horizonte del Oráculo",
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            locationText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 5),
                          svgContent,
                        ],
                      );
                    },
                  ),
                ),

                // 2. ZONA SCROLLABLE
                Expanded(
                  child: Stack(
                    children: [
                      // Fondo gradiente
                      Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.topCenter,
                            radius: 1.0,
                            colors: [
                              accentCyan.withOpacity(0.05),
                              backgroundColor,
                            ],
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FutureBuilder<User?>(
                              future: _userFuture,
                              builder: (context, userSnapshot) {
                                return const SizedBox.shrink();
                              },
                            ),

                            FutureBuilder<Map<String, dynamic>>(
                              future: _astralProfileFuture,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: accentPurple,
                                      ),
                                    ),
                                  );
                                }

                                final physics =
                                    snapshot.data!['physics']
                                        as Map<String, dynamic>?;
                                final astro =
                                    snapshot.data!['astrology']
                                        as Map<String, dynamic>?;
                                final planetary =
                                    snapshot.data!['planetary']
                                        as Map<String, dynamic>?;

                                // Si falta astro, no mostramos nada.
                                if (astro == null || astro.isEmpty)
                                  return const SizedBox.shrink();

                                final daily = physics?['daily'];
                                final extended = physics?['extended'];
                                final hasPhysics =
                                    daily != null && extended != null;

                                // Datos seguros para la sección física de Sol
                                final sunrise =
                                    hasPhysics &&
                                        daily['sunrise'] != null &&
                                        (daily['sunrise'] as List).isNotEmpty
                                    ? daily['sunrise'][0]
                                    : null;
                                final sunset =
                                    hasPhysics &&
                                        daily['sunset'] != null &&
                                        (daily['sunset'] as List).isNotEmpty
                                    ? daily['sunset'][0]
                                    : null;
                                final daylightSeconds =
                                    hasPhysics &&
                                        daily['daylight_duration'] != null &&
                                        (daily['daylight_duration'] as List)
                                            .isNotEmpty
                                    ? daily['daylight_duration'][0]
                                    : 0.0;
                                final maxUv =
                                    hasPhysics &&
                                        daily['uv_index_max'] != null &&
                                        (daily['uv_index_max'] as List)
                                            .isNotEmpty
                                    ? daily['uv_index_max'][0]
                                    : 0.0;

                                // Datos extendidos (Luna y Eventos Solares)
                                final moonrise = hasPhysics
                                    ? extended['moonrise']
                                    : null;
                                final moonset = hasPhysics
                                    ? extended['moonset']
                                    : null;
                                final moonPhaseVal = hasPhysics
                                    ? (extended['moon_phase'] as double)
                                    : 0.0;
                                final moonAgeDays = hasPhysics
                                    ? extended['moon_age_days']
                                    : 0.0;
                                final season = hasPhysics
                                    ? extended['season']
                                    : 'Desconocida';
                                final solarNoon = hasPhysics
                                    ? extended['solar_noon']
                                    : null;
                                final distanceMoon = hasPhysics
                                    ? extended['distance_to_earth_km']
                                    : 0.0;

                                // Procesamiento de Planetas de AstronomyAPI
                                final planetaryDataFound =
                                    planetary?['data']?['table']?['rows'];
                                final realPlanets = (planetaryDataFound is List)
                                    ? planetaryDataFound
                                    : [];

                                // Filtrar Solo Tierra de la lista de planetas para no duplicarlos en la sección de abajo
                                final visiblePlanetsList = realPlanets.where((
                                  r,
                                ) {
                                  final name = r['cells'][0]['name'];
                                  return name != 'Earth';
                                }).toList();

                                // --- AGREGAR LUNA ---
                                bool hasMoon = visiblePlanetsList.any(
                                  (r) =>
                                      r['cells'][0]['name']
                                              .toString()
                                              .toLowerCase() ==
                                          'moon' ||
                                      r['cells'][0]['name']
                                              .toString()
                                              .toLowerCase() ==
                                          'luna',
                                );
                                if (!hasMoon) {
                                  bool moonVisible = _isBodyVisible(
                                    moonrise?.toString(),
                                    moonset?.toString(),
                                  );
                                  visiblePlanetsList.insert(0, {
                                    'cells': [
                                      {
                                        'name': 'Moon',
                                        'extra': {
                                          'is_visible': moonVisible,
                                          'rise': moonrise,
                                          'set': moonset,
                                        },
                                        // Posición simulada según visibilidad
                                        'position': {
                                          'horizontal': {
                                            'altitude': {
                                              'degrees': moonVisible
                                                  ? 45.2
                                                  : -15.5,
                                            },
                                            'azimuth': {'degrees': 180.5},
                                          },
                                        },
                                      },
                                    ],
                                  });
                                }

                                // --- AGREGAR SOL ---
                                bool hasSun = visiblePlanetsList.any(
                                  (r) =>
                                      r['cells'][0]['name']
                                              .toString()
                                              .toLowerCase() ==
                                          'sun' ||
                                      r['cells'][0]['name']
                                              .toString()
                                              .toLowerCase() ==
                                          'sol',
                                );
                                if (!hasSun) {
                                  bool sunVisible = _isBodyVisible(
                                    sunrise?.toString(),
                                    sunset?.toString(),
                                  );
                                  visiblePlanetsList.insert(0, {
                                    'cells': [
                                      {
                                        'name': 'Sun',
                                        'extra': {
                                          'is_visible': sunVisible,
                                          'rise': sunrise,
                                          'set': sunset,
                                        },
                                        // Posición simulada según visibilidad
                                        'position': {
                                          'horizontal': {
                                            'altitude': {
                                              'degrees': sunVisible
                                                  ? 23.6
                                                  : -23.6,
                                            },
                                            'azimuth': {'degrees': 287.9},
                                          },
                                        },
                                      },
                                    ],
                                  });
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 20.0,
                                  ),
                                  child: Column(
                                    children: [
                                      // 1. CICLOS CELESTIALES (SOL Y LUNA DETALLADOS)
                                      if (sunrise != null &&
                                          sunset != null) ...[
                                        _buildSectionTitle(
                                          "LUMINARIAS Y CICLOS",
                                        ),

                                        // --- TARJETA DEL SOL ---
                                        Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 15,
                                          ),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.orange.withOpacity(0.2),
                                                Colors.redAccent.withOpacity(
                                                  0.1,
                                                ),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: Colors.orangeAccent
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.wb_sunny,
                                                        color:
                                                            Colors.orangeAccent,
                                                        size: 32,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            "SOL",
                                                            style: TextStyle(
                                                              color: textColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                          Text(
                                                            "${(daylightSeconds / 3600).toStringAsFixed(1)}h de Luz  |  Índice UV: $maxUv",
                                                            style: const TextStyle(
                                                              color:
                                                                  secondaryTextColor,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.arrow_upward,
                                                            size: 14,
                                                            color:
                                                                Colors.orange,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            _formatTime(
                                                              sunrise,
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  color:
                                                                      textColor,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .arrow_downward,
                                                            size: 14,
                                                            color: Colors
                                                                .deepOrange,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            _formatTime(sunset),
                                                            style:
                                                                const TextStyle(
                                                                  color:
                                                                      textColor,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              // Fila extra de datos solares
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    "Estación: $season",
                                                    style: const TextStyle(
                                                      color: accentCyan,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (solarNoon != null)
                                                    Text(
                                                      "Cénit: ${_formatTime(solarNoon)}",
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              // Barra de progreso del día
                                              LayoutBuilder(
                                                builder: (context, constraints) {
                                                  final now = DateTime.now();
                                                  DateTime? start, end;

                                                  try {
                                                    start = DateTime.parse(
                                                      sunrise,
                                                    );
                                                    end = DateTime.parse(
                                                      sunset,
                                                    );
                                                  } catch (_) {}

                                                  double progress = 0.0;
                                                  if (start != null &&
                                                      end != null) {
                                                    final total = end
                                                        .difference(start)
                                                        .inMinutes;
                                                    final current = now
                                                        .difference(start)
                                                        .inMinutes;
                                                    progress = (total > 0)
                                                        ? (current / total)
                                                              .clamp(0.0, 1.0)
                                                        : 0.0;
                                                    if (now.isAfter(end))
                                                      progress = 1.0;
                                                    if (now.isBefore(start))
                                                      progress = 0.0;
                                                  }

                                                  return Column(
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        child:
                                                            LinearProgressIndicator(
                                                              value: progress,
                                                              backgroundColor:
                                                                  Colors
                                                                      .black26,
                                                              color: Colors
                                                                  .orangeAccent,
                                                              minHeight: 6,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      Text(
                                                        progress >= 1.0
                                                            ? "El sol se ha puesto"
                                                            : (progress <= 0.0
                                                                  ? "Esperando el amanecer"
                                                                  : "Curso Solar: ${(progress * 100).toInt()}%"),
                                                        style: const TextStyle(
                                                          color:
                                                              secondaryTextColor,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),

                                        // --- TARJETA DE LA LUNA ---
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(
                                                  0xFF1A237E,
                                                ).withOpacity(0.4),
                                                const Color(
                                                  0xFF4A148C,
                                                ).withOpacity(0.2),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: accentPurple.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        moonPhaseVal > 0.4 &&
                                                                moonPhaseVal <
                                                                    0.6
                                                            ? Icons.circle
                                                            : Icons
                                                                  .nightlight_round,
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                        size: 32,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            "LUNA",
                                                            style: TextStyle(
                                                              color: textColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                          Text(
                                                            _getMoonPhaseName(
                                                              moonPhaseVal,
                                                            ),
                                                            style: const TextStyle(
                                                              color:
                                                                  secondaryTextColor,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.arrow_upward,
                                                            size: 14,
                                                            color: accentPurple,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            moonrise != null
                                                                ? _formatTime(
                                                                    moonrise,
                                                                  )
                                                                : "--:--",
                                                            style:
                                                                const TextStyle(
                                                                  color:
                                                                      textColor,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .arrow_downward,
                                                            size: 14,
                                                            color:
                                                                Colors.blueGrey,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            moonset != null
                                                                ? _formatTime(
                                                                    moonset,
                                                                  )
                                                                : "--:--",
                                                            style:
                                                                const TextStyle(
                                                                  color:
                                                                      textColor,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              // Detalles extendidos de la Luna
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    "Edad: $moonAgeDays días",
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  Text(
                                                    "Distancia: ${distanceMoon.toInt()} km",
                                                    style: const TextStyle(
                                                      color: accentPurple,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              // Barra de Iluminación
                                              Builder(
                                                builder: (context) {
                                                  // Fórmula astronómica precisa: (1 - cos(fase * 2π)) / 2
                                                  // phase 0.0 (Nueva) -> 0%
                                                  // phase 0.25 (Creciente) -> 50%
                                                  // phase 0.5 (Llena) -> 100%
                                                  final illumination =
                                                      0.5 *
                                                      (1 -
                                                          math.cos(
                                                            moonPhaseVal *
                                                                2 *
                                                                math.pi,
                                                          ));

                                                  return Column(
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        child:
                                                            LinearProgressIndicator(
                                                              value:
                                                                  illumination,
                                                              backgroundColor:
                                                                  Colors
                                                                      .black26,
                                                              color: Colors
                                                                  .grey
                                                                  .shade300,
                                                              minHeight: 6,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      Text(
                                                        "Iluminación: $illumination %",
                                                        style: const TextStyle(
                                                          color:
                                                              secondaryTextColor,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 30),
                                      ],

                                      // 2. VISIBILIDAD DE PLANETAS REALES
                                      if (visiblePlanetsList.isNotEmpty) ...[
                                        _buildSectionTitle("🌌 Planetas"),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: cardBackground.withOpacity(
                                              0.4,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                            border: Border.all(
                                              color: Colors.white10,
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            children: visiblePlanetsList.map((
                                              planetRow,
                                            ) {
                                              final cells =
                                                  planetRow['cells'] as List;
                                              if (cells.isEmpty)
                                                return const SizedBox.shrink();

                                              final rawName =
                                                  cells[0]['name'] ??
                                                  'Cuerpo Celeste';
                                              final nameMap = {
                                                'Sun': 'sol',
                                                'Moon': 'luna',
                                                'Mercury': 'mercurio',
                                                'Venus': 'venus',
                                                'Mars': 'marte',
                                                'Jupiter': 'júpiter',
                                                'Saturn': 'saturno',
                                                'Uranus': 'urano',
                                                'Neptune': 'neptuno',
                                                'Pluto': 'plutón',
                                              };
                                              final name =
                                                  nameMap[rawName] ??
                                                  rawName.toLowerCase();

                                              final symbolMap = {
                                                'Sun': '☀️',
                                                'Moon': '🌙',
                                                'Mercury': '☿',
                                                'Venus': '♀',
                                                'Mars': '♂',
                                                'Jupiter': '♃',
                                                'Saturn': '♄',
                                                'Uranus': '⛢',
                                                'Neptune': '♆',
                                                'Pluto': '♇',
                                              };
                                              final symbol =
                                                  symbolMap[rawName] ?? '✨';

                                              final extra = cells[0]['extra'];
                                              final positionCtx =
                                                  cells[0]['position']?['horizontal'];

                                              final isVisible =
                                                  extra != null &&
                                                  extra['is_visible'] == true;

                                              String altStr = "N/A";
                                              String azStr = "N/A";

                                              if (positionCtx != null) {
                                                final alt =
                                                    positionCtx['altitude']?['degrees'];
                                                if (alt != null)
                                                  altStr =
                                                      double.tryParse(
                                                        alt.toString(),
                                                      )?.toStringAsFixed(1) ??
                                                      alt.toString();
                                                final az =
                                                    positionCtx['azimuth']?['degrees'];
                                                if (az != null)
                                                  azStr =
                                                      double.tryParse(
                                                        az.toString(),
                                                      )?.toStringAsFixed(1) ??
                                                      az.toString();
                                              }

                                              return Container(
                                                margin: const EdgeInsets.only(
                                                  bottom: 15,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    // Izquierda (Simbolo + Nombre + Ojo)
                                                    Row(
                                                      children: [
                                                        Text(
                                                          symbol,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 16,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          name,
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    textColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 15,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Container(
                                                          decoration: BoxDecoration(
                                                            color: isVisible
                                                                ? Colors
                                                                      .greenAccent
                                                                      .withOpacity(
                                                                        0.1,
                                                                      )
                                                                : Colors
                                                                      .redAccent
                                                                      .withOpacity(
                                                                        0.1,
                                                                      ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            border: Border.all(
                                                              color: isVisible
                                                                  ? Colors
                                                                        .greenAccent
                                                                        .withOpacity(
                                                                          0.4,
                                                                        )
                                                                  : Colors
                                                                        .redAccent
                                                                        .withOpacity(
                                                                          0.4,
                                                                        ),
                                                              width: 1,
                                                            ),
                                                            boxShadow: isVisible
                                                                ? [
                                                                    BoxShadow(
                                                                      color: Colors
                                                                          .greenAccent
                                                                          .withOpacity(
                                                                            0.2,
                                                                          ),
                                                                      blurRadius:
                                                                          8,
                                                                      spreadRadius:
                                                                          2,
                                                                    ),
                                                                  ]
                                                                : [],
                                                          ),
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                          child: Icon(
                                                            isVisible
                                                                ? Icons
                                                                      .visibility
                                                                : Icons
                                                                      .visibility_off,
                                                            color: isVisible
                                                                ? Colors
                                                                      .green
                                                                      .shade300
                                                                : Colors
                                                                      .red
                                                                      .shade300,
                                                            size: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    // Derecha (Línea + Alt/Az)
                                                    Row(
                                                      children: [
                                                        Container(
                                                          width: 1.5,
                                                          height: 25,
                                                          color: Colors.white24,
                                                          margin:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 10,
                                                              ),
                                                        ),
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                const Icon(
                                                                  Icons
                                                                      .signal_cellular_alt_rounded,
                                                                  color: Colors
                                                                      .grey,
                                                                  size: 12,
                                                                ),
                                                                const SizedBox(
                                                                  width: 4,
                                                                ),
                                                                Text(
                                                                  "Altitud: ",
                                                                  style: TextStyle(
                                                                    color:
                                                                        secondaryTextColor,
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  "$altStr°",
                                                                  style: const TextStyle(
                                                                    color:
                                                                        accentCyan,
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Row(
                                                              children: [
                                                                const Icon(
                                                                  Icons.explore,
                                                                  color: Colors
                                                                      .orangeAccent,
                                                                  size: 12,
                                                                ),
                                                                const SizedBox(
                                                                  width: 4,
                                                                ),
                                                                Text(
                                                                  "Azimut:",
                                                                  style: TextStyle(
                                                                    color:
                                                                        secondaryTextColor,
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  "$azStr°",
                                                                  style: const TextStyle(
                                                                    color:
                                                                        accentCyan,
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        const SizedBox(height: 30),
                                      ],

                                      // 3. LOS TRES GRANDES (Siempre visible)
                                      _buildSectionTitle(
                                        "IDENTIDAD ASTRAL (Big 3)",
                                      ),
                                      Row(
                                        children: [
                                          _buildAstroChip(
                                            "Sol",
                                            astro['big_three']['sun'],
                                            Icons.wb_sunny,
                                            Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildAstroChip(
                                            "Luna",
                                            astro['big_three']['moon'],
                                            Icons.dark_mode,
                                            Colors.blueGrey,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildAstroChip(
                                            "Asc",
                                            astro['big_three']['ascendant'],
                                            Icons.arrow_upward,
                                            accentCyan,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 30),

                                      // 3. POSICIONES PLANETARIAS
                                      _buildSectionTitle(
                                        "TRÁNSITOS PLANETARIOS",
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(15),
                                        decoration: BoxDecoration(
                                          color: cardBackground.withOpacity(
                                            0.5,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          border: Border.all(
                                            color: accentCyan.withOpacity(0.1),
                                          ),
                                        ),
                                        child: Column(
                                          children: (astro['planets'] as List)
                                              .map<Widget>(
                                                (p) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 8.0,
                                                      ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.circle,
                                                            size: 8,
                                                            color: accentPurple,
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Text(
                                                            p['name'],
                                                            style:
                                                                const TextStyle(
                                                                  color:
                                                                      textColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      Text(
                                                        "${p['sign']} ${p['deg']}",
                                                        style: const TextStyle(
                                                          color: accentCyan,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                      const SizedBox(height: 30),

                                      // 4. CASAS Y ASPECTOS
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildSectionTitle(
                                                  "CASAS ACTIVAS",
                                                ),
                                                ...(astro['houses'] as Map)
                                                    .entries
                                                    .map(
                                                      (e) => Text(
                                                        "Casa ${e.key.replaceAll('C', '')}: ${e.value}",
                                                        style: const TextStyle(
                                                          color:
                                                              secondaryTextColor,
                                                          height: 1.5,
                                                        ),
                                                      ),
                                                    ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildSectionTitle("ASPECTOS"),
                                                ...(astro['aspects'] as List).map(
                                                  (a) => Text(
                                                    "• ${a['planet1']} ${a['type']} ${a['planet2']}",
                                                    style: const TextStyle(
                                                      color: secondaryTextColor,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 40),

                                      // --- CONTROLES DEL CIELO (REQ. USUARIO) ---
                                      _buildSectionTitle(
                                        "CONFIGURACIÓN CELESTIAL",
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        margin: const EdgeInsets.only(
                                          bottom: 30,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cardBackground.withOpacity(
                                            0.6,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          border: Border.all(
                                            color: accentPurple.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            // Fecha y Hora
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: InkWell(
                                                    onTap: _pickDate,
                                                    child: InputDecorator(
                                                      decoration: InputDecoration(
                                                        labelText: "Fecha",
                                                        labelStyle: const TextStyle(
                                                          color:
                                                              secondaryTextColor,
                                                        ),
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                        prefixIcon: const Icon(
                                                          Icons.calendar_today,
                                                          color: accentCyan,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                                                        style: const TextStyle(
                                                          color: textColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: InkWell(
                                                    onTap: _pickTime,
                                                    child: InputDecorator(
                                                      decoration: InputDecoration(
                                                        labelText: "Hora",
                                                        labelStyle: const TextStyle(
                                                          color:
                                                              secondaryTextColor,
                                                        ),
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                        prefixIcon: const Icon(
                                                          Icons.access_time,
                                                          color: accentCyan,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        "${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}",
                                                        style: const TextStyle(
                                                          color: textColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 15),
                                            // Buscador de Ubicación
                                            TextField(
                                              controller: _locationController,
                                              style: const TextStyle(
                                                color: textColor,
                                              ),
                                              onEditingComplete:
                                                  _searchLocationAddress, // Buscar al presionar Enter en teclado soft
                                              decoration: InputDecoration(
                                                labelText:
                                                    "Buscar Ubicación (Ej: Madrid, España)",
                                                helperText:
                                                    "Presiona Enter o la lupa para buscar",
                                                helperStyle: TextStyle(
                                                  color: secondaryTextColor
                                                      .withOpacity(0.5),
                                                ),
                                                hintText: "Ej: Paris, France",
                                                hintStyle: TextStyle(
                                                  color: secondaryTextColor
                                                      .withOpacity(0.5),
                                                ),
                                                labelStyle: const TextStyle(
                                                  color: secondaryTextColor,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                prefixIcon: const Icon(
                                                  Icons.location_city,
                                                  color: accentPurple,
                                                ),
                                                suffixIcon: IconButton(
                                                  icon: const Icon(
                                                    Icons.search,
                                                    color: accentCyan,
                                                  ),
                                                  onPressed:
                                                      _searchLocationAddress,
                                                  tooltip: "Buscar coordenadas",
                                                ),
                                              ),
                                              onSubmitted: (_) =>
                                                  _searchLocationAddress(),
                                            ),
                                            const SizedBox(height: 15),
                                            // Latitud y Longitud
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: _latController,
                                                    style: const TextStyle(
                                                      color: textColor,
                                                    ),
                                                    keyboardType:
                                                        const TextInputType.numberWithOptions(
                                                          decimal: true,
                                                          signed: true,
                                                        ),
                                                    decoration: InputDecoration(
                                                      labelText: "Latitud",
                                                      labelStyle: const TextStyle(
                                                        color:
                                                            secondaryTextColor,
                                                      ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                    ),
                                                    onSubmitted: (_) =>
                                                        _updateSkyData(),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: TextField(
                                                    controller: _lonController,
                                                    style: const TextStyle(
                                                      color: textColor,
                                                    ),
                                                    keyboardType:
                                                        const TextInputType.numberWithOptions(
                                                          decimal: true,
                                                          signed: true,
                                                        ),
                                                    decoration: InputDecoration(
                                                      labelText: "Longitud",
                                                      labelStyle: const TextStyle(
                                                        color:
                                                            secondaryTextColor,
                                                      ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                    ),
                                                    onSubmitted: (_) =>
                                                        _updateSkyData(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            SizedBox(
                                              width: double.infinity,
                                              child: TextButton.icon(
                                                onPressed: () =>
                                                    _updateSkyData(),
                                                icon: const Icon(
                                                  Icons.refresh,
                                                  color: accentCyan,
                                                ),
                                                label: const Text(
                                                  "Refrescar Cielo",
                                                  style: TextStyle(
                                                    color: accentCyan,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // --- BOTÓN PREGUNTA AL ORÁCULO ---
                                      ElevatedButton.icon(
                                        onPressed: () {},
                                        icon: const Icon(Icons.auto_awesome),
                                        label: const Text(
                                          "CONSULTAR CARTA NATAL COMPLETA",
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accentCyan,
                                          foregroundColor: backgroundColor,
                                          minimumSize: const Size(
                                            double.infinity,
                                            55,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ), // Cierra Expanded de la zona scrollable
              ],
            ), // Cierra Column de TAB 1
            // FIN TAB 1

            // TAB 2: CONSULTAS
            const OracleConsultationsScreen(),

            // TAB 3: CARTAS ASTRALES
            const AstralChartsScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF4FD0E7),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
        ),
      ),
    );
  }

  Widget _buildCycleCard({
    required String title,
    required String time,
    required String remaining,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
            Text(
              time,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              remaining,
              textAlign: TextAlign.center,
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAstroChip(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(color: secondaryTextColor, fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper para interpretar la fase lunar (0.0 a 1.0)
  String _getMoonPhaseName(double phase) {
    if (phase < 0.05 || phase > 0.95) return "Luna Nueva";
    if (phase >= 0.05 && phase < 0.25) return "Luna Creciente";
    if (phase >= 0.25 && phase < 0.45) return "Cuarto Creciente";
    if (phase >= 0.45 && phase < 0.55) return "Luna Llena";
    if (phase >= 0.55 && phase < 0.75) return "Luna Menguante";
    if (phase >= 0.75 && phase < 0.95) return "Cuarto Menguante";
    return "Fase Lunar";
  }
}
