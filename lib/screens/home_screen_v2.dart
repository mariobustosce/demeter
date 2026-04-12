import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:async_wallpaper/async_wallpaper.dart';
import '../services/auth_service.dart';
import '../services/sky_service.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'astral_charts_screen.dart';
import 'oracle_consultations_screen.dart';
import 'compatibility_screen.dart';
import 'celestial_screen_saver.dart'; // Importar el visor del Canvas
import 'profile_screen.dart'; // Importar perfil
import '../services/wallpaper_refresh_service.dart';

// Colores celestiales (WindowsDemeter)
const backgroundColor = Color(0xFF0A0A0F);
const accentCyan = Color(0xFF4FD0E7);
const accentPurple = Color(0xFF8B5CF6);
const cardBackground = Color(0xEF0F172A);
const textColor = Color(0xFFF7FAFC);
const secondaryTextColor = Color(0xFF94A3B8);

class HomeScreenV2 extends StatefulWidget {
  const HomeScreenV2({super.key});

  @override
  State<HomeScreenV2> createState() => _HomeScreenV2State();
}

class _HomeScreenV2State extends State<HomeScreenV2> with WidgetsBindingObserver, TickerProviderStateMixin {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  final SkyService _skyService = SkyService();

  late Future<User?> _userFuture;
  late Future<Map<String, dynamic>?> _canvasMapFuture; // JSON para datos astrales y botón wallpaper
  late Future<Map<String, dynamic>> _astralProfileFuture;
  late Future<String?> _svgFuture; // SVG del cielo para el mapa HOME

  // Controles del Cielo
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();
  final TransformationController _viewerController = TransformationController();
  Animation<Matrix4>? _animationReset;
  late AnimationController _animationControllerReset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationControllerReset = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        _viewerController.value = _animationReset!.value;
      });
    _userFuture = _authService.getMe();

    // Asignar futures simulados primero para que FutureBuilder espere sin fallar
    _canvasMapFuture = Future.value(null);
    _svgFuture = Future.value(null);
    _astralProfileFuture = Future<Map<String, dynamic>>.delayed(
      const Duration(
        days: 1,
      ), // Simula carga perpetua hasta que respondan los correctos
      () => {},
    );

    _initLocationAndData();
  }

  Future<void> _initLocationAndData() async {
    final now = DateTime.now();

    if (mounted) {
      setState(() {
        _selectedDate = DateTime(now.year, now.month, now.day);
        _selectedTime = TimeOfDay.fromDateTime(now);
        _locationController.clear();
        _latController.clear();
        _lonController.clear();
      });
    }

    String nextLat = "-33.4377";
    String nextLon = "-70.6511";

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
          nextLat = pos.latitude.toString();
          nextLon = pos.longitude.toString();
        }
      }
    } catch (e) {
      print("Error obteniendo ubicación inicial UI: $e");
    }

    if (mounted) {
      setState(() {
        _latController.text = nextLat;
        _lonController.text = nextLon;
      });
    }

    if (mounted) {
      // Una vez la ubicación fue resuelta (o falló), hacemos una única llamada a las API
      await _updateSkyData(initial: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewerController.dispose();
    _animationControllerReset.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Solo actualizamos si la app vuelve al primer plano y NO está el diálogo de fecha/hora abierto
    if (state == AppLifecycleState.resumed) {
      // Pequeño delay para asegurar que el sistema está listo
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
           _updateSkyData();
        }
      });
    }
  }

  // Variable para evitar peticiones redundantes
  bool _isUpdating = false;

  Future<bool> _updateSkyData({bool initial = false, VoidCallback? onRefreshed}) async {
    if (_isUpdating) return false;
    
    // Si no es un año válido, no hacemos nada para evitar crashes
    if (_selectedDate.year < 0) return false;

    // Validación de coordenadas para evitar peticiones nulas o inválidas
    final double? lat = double.tryParse(_latController.text);
    final double? lng = double.tryParse(_lonController.text);
    if (lat == null || lng == null) {
      _isUpdating = false;
      return false;
    }

    // Asegurar que el Workmanager siempre tenga las últimas coordenadas
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('wallpaper_lat', lat);
      await prefs.setDouble('wallpaper_lon', lng);
    } catch (_) {}

    _isUpdating = true;
    final dt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // SVG para el mapa HOME (en paralelo, independiente del JSON)
    final svgCall = _skyService
        .getMapSvgMobile(lat: lat, lng: lng, date: dt)
        .catchError((e) {
          print("Error en svgCall de SkyData: $e");
          return null;
        });

    // JSON para datos astrales, botón wallpaper y pestaña planetas
    final apiCall = _skyService.getMapApiData(
      lat: lat,
      lng: lng,
      date: dt,
    ).then((data) async {
       if (data != null) {
         // Persistir la data para que el Wallpaper pueda leerla de inmediato al arrancar
         try {
           final prefs = await SharedPreferences.getInstance();
           await prefs.setString('last_sky_data', jsonEncode(data));
           
           // Sincronizar con el Live Wallpaper si está activo
           try {
             const platform = MethodChannel('windowsdemeter.com/wallpaper');
             await platform.invokeMethod('updateData', data);
           } catch (e) {
             // Ignorar si el fondo de pantalla no está escuchando
           }
         } catch (e) {
           print("Error persistiendo o sincronizando sky data: $e");
         }
       }
       return data;
    }).catchError((e) {
      print("Error en apiCall de SkyData: $e");
      return null;
    });

    setState(() {
      if (!initial) {
        _canvasMapFuture = Future.value(null);
        _svgFuture = Future.value(null);
      }
      _canvasMapFuture = apiCall;
      _svgFuture = svgCall;
      _astralProfileFuture = apiCall.then((data) => data ?? {});
    });

    try {
      await Future.wait([svgCall, apiCall]);
      return true;
    } finally {
      _isUpdating = false;
      if (mounted) {
        setState(() {});
      }
      onRefreshed?.call();
    }
  }

  void _onAppResumeUpdate() {
    if (mounted) {
      _updateSkyData();
    }
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    if (_viewerController.value == Matrix4.identity()) return;
    
    _animationReset = Matrix4Tween(
      begin: _viewerController.value,
      end: Matrix4.identity(),
    ).animate(
      CurvedAnimation(
        parent: _animationControllerReset,
        curve: Curves.easeOut,
      ),
    );
    _animationControllerReset.forward(from: 0);
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
  // Helper para construir una fila de dato label/valor
  Widget _buildDataRow(String label, String value, {Color valueColor = accentCyan}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: secondaryTextColor, fontSize: 12)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Helper para sub-título dentro de una sección colapsable
  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _mostrarMenuDetalles() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.92,
              minChildSize: 0.5,
              maxChildSize: 0.97,
              builder: (_, controller) {
                return Container(
                  decoration: const BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(canvasColor: backgroundColor),
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.only(top: 10, bottom: 50),
                      children: [
                        // Handle
                        Center(
                          child: Container(
                            width: 50, height: 5,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        FutureBuilder<Map<String, dynamic>>(
                          future: _astralProfileFuture,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(child: CircularProgressIndicator(color: accentPurple)),
                              );
                            }
                            if (snapshot.data!.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(child: Text("Sin datos disponibles", style: TextStyle(color: secondaryTextColor))),
                              );
                            }

                            final data = snapshot.data!;

                            // ---- Extraer secciones principales ----
                            final solar = data['solar'] as Map<String, dynamic>?;
                            final lunar = data['lunar'] as Map<String, dynamic>?;
                            final planetas = data['planetas'] as Map<String, dynamic>?;
                            final zodiaco = data['zodiaco'] as Map<String, dynamic>?;
                            final casas = data['casas'] as Map<String, dynamic>?;
                            final config = data['config'] as Map<String, dynamic>?;
                            final arcos = data['arcos'] as Map<String, dynamic>?;
                            final hemisferio = data['hemisferio']?.toString() ?? 'N/D';
                            final season = arcos?['season']?.toString() ?? 'N/D';

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  // ══════════════════════════════════════
                                  // 1. SOL
                                  // ══════════════════════════════════════
                                  if (solar != null) ...[
                                    _buildSectionTitle("☀️  SOL"),
                                    _buildCelestialCard(
                                      gradient: LinearGradient(
                                        colors: [Colors.orange.withOpacity(0.2), Colors.redAccent.withOpacity(0.08)],
                                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                                      ),
                                      borderColor: Colors.orangeAccent.withOpacity(0.35),
                                      child: Column(
                                        children: [
                                          // Header: título + badge visible
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(children: [
                                                const Icon(Icons.wb_sunny, color: Colors.orangeAccent, size: 28),
                                                const SizedBox(width: 10),
                                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                  const Text("Sol", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                                  Text(
                                                    solar['times']?['daylight_duration']?.toString() ?? "",
                                                    style: const TextStyle(color: secondaryTextColor, fontSize: 11),
                                                  ),
                                                ]),
                                              ]),
                                              _buildVisibleBadge(solar['position']?['visible'] == true || solar['visible'] == true),
                                            ],
                                          ),
                                          const Divider(color: Colors.white12, height: 18),
                                          _buildDataRow("🎯 Posición Alt.", "${(solar['position']?['altitude'] as num?)?.toStringAsFixed(1) ?? 'N/D'}°"),
                                          _buildDataRow("🧭 Azimut", "${(solar['position']?['azimuth'] as num?)?.toStringAsFixed(1) ?? 'N/D'}°"),
                                          _buildDataRow("⭐ Constelación", solar['position']?['constellation']?.toString() ?? 'N/D'),
                                          _buildDataRow("🌅 Amanecer", solar['times']?['sunrise']?.toString() ?? 'N/D'),
                                          _buildDataRow("🌇 Atardecer", solar['times']?['sunset']?.toString() ?? 'N/D'),
                                          _buildDataRow("⏳ Tiempo restante", solar['times']?['sun_time_left']?.toString() ?? 'N/D'),
                                          _buildDataRow("🔆 Duración día", solar['times']?['daylight_duration']?.toString() ?? 'N/D'),
                                          _buildDataRow("🗺️ Hemisferio", hemisferio),
                                          _buildDataRow("🌿 Estación", _capitalize(season)),
                                          // Barra progreso curso solar
                                          const SizedBox(height: 10),
                                          Builder(builder: (context) {
                                            final sunriseStr = solar['times']?['sunrise']?.toString();
                                            final sunsetStr = solar['times']?['sunset']?.toString();
                                            double progress = 0.0;
                                            if (sunriseStr != null && sunsetStr != null) {
                                              try {
                                                final today = DateTime.now();
                                                final parts1 = sunriseStr.split(':');
                                                final parts2 = sunsetStr.split(':');
                                                final rise = DateTime(today.year, today.month, today.day,
                                                    int.parse(parts1[0]), int.parse(parts1[1]));
                                                final set_ = DateTime(today.year, today.month, today.day,
                                                    int.parse(parts2[0]), int.parse(parts2[1]));
                                                final total = set_.difference(rise).inMinutes;
                                                final current = today.difference(rise).inMinutes;
                                                if (total > 0) progress = (current / total).clamp(0.0, 1.0);
                                              } catch (_) {}
                                            }
                                            return Column(children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: LinearProgressIndicator(
                                                  value: progress, minHeight: 5,
                                                  backgroundColor: Colors.black26,
                                                  color: Colors.orangeAccent,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                progress >= 1.0 ? "El sol se ha puesto"
                                                    : (progress <= 0.0 ? "Esperando el amanecer"
                                                        : "Curso Solar: ${(progress * 100).toInt()}%"),
                                                style: const TextStyle(color: secondaryTextColor, fontSize: 10),
                                              ),
                                            ]);
                                          }),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],

                                  // ══════════════════════════════════════
                                  // 2. LUNA
                                  // ══════════════════════════════════════
                                  if (lunar != null) ...[
                                    _buildSectionTitle("🌙  LUNA"),
                                    _buildCelestialCard(
                                      gradient: LinearGradient(
                                        colors: [const Color(0xFF1A237E).withOpacity(0.4), const Color(0xFF4A148C).withOpacity(0.15)],
                                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                                      ),
                                      borderColor: accentPurple.withOpacity(0.35),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(children: [
                                                Text(
                                                  lunar['phase_symbol']?.toString() ?? '🌙',
                                                  style: const TextStyle(fontSize: 28),
                                                ),
                                                const SizedBox(width: 10),
                                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                  const Text("Luna", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                                  Text(
                                                    lunar['phase_name']?.toString() ?? 'Fase Lunar',
                                                    style: const TextStyle(color: secondaryTextColor, fontSize: 11),
                                                  ),
                                                ]),
                                              ]),
                                              _buildVisibleBadge(lunar['visible'] == true || (lunar['times']?['currently_visible'] == true)),
                                            ],
                                          ),
                                          // Barra iluminación
                                          const SizedBox(height: 12),
                                          Builder(builder: (context) {
                                            final illum = (lunar['illumination_percent'] as num?)?.toDouble() ?? 0.0;
                                            return Column(children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: LinearProgressIndicator(
                                                  value: illum / 100.0, minHeight: 5,
                                                  backgroundColor: Colors.black26,
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text("Iluminación: ${illum.toStringAsFixed(1)}%",
                                                style: const TextStyle(color: secondaryTextColor, fontSize: 10)),
                                            ]);
                                          }),
                                          const Divider(color: Colors.white12, height: 18),
                                          _buildDataRow("🎯 Altitud", "${(lunar['altitude'] as num?)?.toStringAsFixed(1) ?? lunar['times']?['current_altitude']?.toString() ?? 'N/D'}°"),
                                          _buildDataRow("🧭 Dirección", lunar['cardinal_direction']?.toString() ?? 'N/D'),
                                          _buildDataRow("📐 Azimut", "${(lunar['azimuth'] as num?)?.toStringAsFixed(1) ?? lunar['times']?['current_azimuth']?.toString() ?? 'N/D'}°"),
                                          _buildDataRow("📈 Tendencia", (lunar['waxing'] == true) ? "Creciente ↗️" : "Menguante ↘️"),
                                          _buildDataRow("🌅 Sale", lunar['times']?['moonrise']?.toString() ?? 'N/D'),
                                          _buildDataRow("🌇 Se pone", lunar['times']?['moonset']?.toString() ?? 'N/D'),
                                          _buildDataRow("⏱️ Meridiano", lunar['times']?['lunar_meridian']?.toString() ?? 'N/D'),
                                          _buildDataRow("⭐ Constelación", lunar['constellation']?.toString() ?? 'N/D'),
                                          _buildDataRow("📡 Elongación", "${(lunar['elongation'] as num?)?.toStringAsFixed(1) ?? 'N/D'}°"),
                                          if ((lunar['times']?['status'] as String?) != null)
                                            _buildDataRow("📌 Estado", lunar['times']!['status'].toString(), valueColor: Colors.amberAccent),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],

                                  // ══════════════════════════════════════
                                  // 3. PLANETAS VISIBLES
                                  // ══════════════════════════════════════
                                  if (planetas != null) ...[
                                    _buildSectionTitle("🪐  PLANETAS"),
                                    _buildCelestialCard(
                                      gradient: LinearGradient(
                                        colors: [cardBackground.withOpacity(0.6), cardBackground.withOpacity(0.3)],
                                      ),
                                      borderColor: Colors.white12,
                                      child: Builder(builder: (context) {
                                        final visibles = planetas['visibles'] as Map<String, dynamic>?;
                                        final horarios = planetas['horarios'] as Map<String, dynamic>?;
                                        if (visibles == null || visibles.isEmpty) {
                                          return const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Text("🌌 No hay planetas con datos", style: TextStyle(color: secondaryTextColor)),
                                            ),
                                          );
                                        }
                                        return Column(
                                          children: visibles.entries.map((entry) {
                                            final nombre = entry.key;
                                            final p = entry.value as Map<String, dynamic>;
                                            final horario = horarios?[nombre] as Map<String, dynamic>?;
                                            final isVisible = p['visible'] == true;
                                            final alt = (p['altitude'] as num?)?.toStringAsFixed(1) ?? 'N/D';
                                            final az = (p['azimuth'] as num?)?.toStringAsFixed(1) ?? 'N/D';
                                            final symbol = p['symbol']?.toString() ?? '🪐';
                                            final color = p['color']?.toString() ?? '#4FD0E7';

                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Cabecera planeta
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(children: [
                                                      Text(symbol, style: const TextStyle(fontSize: 18)),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        _capitalize(nombre),
                                                        style: const TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                                      ),
                                                    ]),
                                                    _buildVisibleBadge(isVisible),
                                                  ],
                                                ),
                                                // Detalles con borde izquierdo
                                                Container(
                                                  margin: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                                                  padding: const EdgeInsets.only(left: 10),
                                                  decoration: BoxDecoration(
                                                    border: Border(left: BorderSide(color: accentCyan.withOpacity(0.4), width: 2)),
                                                  ),
                                                  child: Column(children: [
                                                    _buildDataRow("📐 Altitud", "$alt°"),
                                                    _buildDataRow("🧭 Azimut", "$az°"),
                                                    if (p['constellation'] != null)
                                                      _buildDataRow("⭐ Constelación", p['constellation'].toString()),
                                                    if (p['magnitude'] != null)
                                                      _buildDataRow("✨ Magnitud", "${(p['magnitude'] as num).toStringAsFixed(1)}"),
                                                    if (p['distance'] != null)
                                                      _buildDataRow("📏 Distancia", "${(p['distance'] as num).toStringAsFixed(0)} km"),
                                                    if (p['phase'] != null)
                                                      _buildDataRow("🌙 Fase", "${(p['phase'] as num).toStringAsFixed(1)}%"),
                                                    if (horario != null) ...[
                                                      _buildDataRow("🌅 Sale", horario['rise']?.toString() ?? 'N/D'),
                                                      _buildDataRow("🌇 Se pone", horario['set']?.toString() ?? 'N/D'),
                                                      _buildDataRow("🏔️ Alt. Max.", "${horario['max_altitude']?.toString() ?? 'N/D'}°"),
                                                      if (horario['tiempo_restante'] != null)
                                                        _buildDataRow("⏳ Visible", horario['tiempo_restante'].toString(), valueColor: Colors.greenAccent.shade200),
                                                    ],
                                                    // Barra progreso visibilidad
                                                    if (horario?['progress'] != null)
                                                      Builder(builder: (context) {
                                                        final prog = (horario!['progress'] as num).toDouble().clamp(0.0, 1.0);
                                                        return Padding(
                                                          padding: const EdgeInsets.only(top: 6),
                                                          child: ClipRRect(
                                                            borderRadius: BorderRadius.circular(6),
                                                            child: LinearProgressIndicator(
                                                              value: prog, minHeight: 4,
                                                              backgroundColor: Colors.black26,
                                                              color: isVisible ? Colors.greenAccent : Colors.grey,
                                                            ),
                                                          ),
                                                        );
                                                      }),
                                                  ]),
                                                ),
                                                const Divider(color: Colors.white10, height: 12),
                                              ],
                                            );
                                          }).toList(),
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 20),
                                  ],

                                  // ══════════════════════════════════════
                                  // 4. ZODÍACO ASTRONÓMICO
                                  // ══════════════════════════════════════
                                  if (zodiaco != null) ...[
                                    _buildSectionTitle("🌟  ZODÍACO ASTRONÓMICO"),
                                    _buildCelestialCard(
                                      gradient: LinearGradient(
                                        colors: [accentCyan.withOpacity(0.06), accentPurple.withOpacity(0.06)],
                                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                                      ),
                                      borderColor: accentCyan.withOpacity(0.2),
                                      child: Builder(builder: (context) {
                                        final horarios = zodiaco['horarios'] as Map<String, dynamic>?;
                                        final potencias = zodiaco['potencias'] as Map<String, dynamic>?;
                                        final filtrados = zodiaco['filtrados'] as Map<String, dynamic>?;

                                        if (horarios == null) {
                                          return const Center(
                                            child: Padding(padding: EdgeInsets.all(12),
                                              child: Text("🌌 Zodíaco no disponible", style: TextStyle(color: secondaryTextColor)),
                                            ),
                                          );
                                        }

                                        // Signo dominante
                                        String? signoDominante;
                                        int maxPot = 0;
                                        potencias?.forEach((k, v) {
                                          final pot = (v as num).toInt();
                                          if (pot > maxPot) { maxPot = pot; signoDominante = k; }
                                        });

                                        final signosVisibles = horarios.entries.where((e) {
                                          return (e.value as Map<String, dynamic>)['visible_now'] == true;
                                        }).toList();

                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Info ubicación/momento
                                            if (config != null) ...[
                                              _buildDataRow("📍 Ciudad", config['ciudad']?.toString() ?? 'N/D'),
                                              _buildDataRow("🗺️ Hemisferio", hemisferio),
                                            ],
                                            // Signo dominante
                                            if (signoDominante != null) ...[
                                              _buildSubSectionTitle("👑 SIGNO DOMINANTE"),
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: accentCyan.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: accentCyan.withOpacity(0.25)),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(children: [
                                                      Text(
                                                        horarios[signoDominante]?['simbolo']?.toString() ?? '♈',
                                                        style: const TextStyle(fontSize: 22),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        _capitalize(signoDominante!),
                                                        style: const TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                                      ),
                                                    ]),
                                                    Text(
                                                      "⚡ $maxPot pts",
                                                      style: const TextStyle(color: accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Detalle del dominante si está en filtrados
                                              if (filtrados?[signoDominante] != null) ...[
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets.only(left: 10),
                                                  decoration: BoxDecoration(
                                                    border: Border(left: BorderSide(color: accentCyan.withOpacity(0.4), width: 2)),
                                                  ),
                                                  child: Builder(builder: (context) {
                                                    final fd = filtrados![signoDominante!] as Map<String, dynamic>;
                                                    return Column(children: [
                                                      _buildDataRow("📐 Alt. actual", "${(fd['current_altitude'] as num?)?.toStringAsFixed(1) ?? 'N/D'}°"),
                                                      _buildDataRow("🧭 Azimut", "${(fd['current_azimuth'] as num?)?.toStringAsFixed(1) ?? 'N/D'}°"),
                                                      _buildDataRow("🏔️ Alt. Max.", "${(fd['max_altitude'] as num?)?.toStringAsFixed(1) ?? 'N/D'}°"),
                                                      _buildDataRow("🌟 Estrella", fd['estrella_principal']?.toString() ?? 'N/D'),
                                                      _buildDataRow("🌅 Sale", fd['rise']?.toString() ?? 'N/D'),
                                                      _buildDataRow("🌇 Se pone", fd['set']?.toString() ?? 'N/D'),
                                                      _buildDataRow("⏱️ Tránsito", fd['transit']?.toString() ?? 'N/D'),
                                                      _buildDataRow("👁️ Duración vis.", fd['visible_duration']?.toString() ?? 'N/D'),
                                                    ]);
                                                  }),
                                                ),
                                              ],
                                            ],
                                            // Signos visibles
                                            if (signosVisibles.isNotEmpty) ...[
                                              _buildSubSectionTitle("👁️ SIGNOS VISIBLES (${signosVisibles.length})"),
                                              ...signosVisibles.map((entry) {
                                                final signo = entry.value as Map<String, dynamic>;
                                                final pot = potencias?[entry.key] ?? 0;
                                                final fd = filtrados?[entry.key] as Map<String, dynamic>?;
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 6),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Row(children: [
                                                        Text(signo['simbolo']?.toString() ?? '♈', style: const TextStyle(fontSize: 16)),
                                                        const SizedBox(width: 6),
                                                        Text(_capitalize(entry.key), style: const TextStyle(color: textColor, fontSize: 13)),
                                                      ]),
                                                      Row(children: [
                                                        if (fd != null)
                                                          Text(
                                                            "${(fd['current_altitude'] as num?)?.toStringAsFixed(0) ?? '?'}°",
                                                            style: const TextStyle(color: secondaryTextColor, fontSize: 11),
                                                          ),
                                                        const SizedBox(width: 8),
                                                        Text("⚡$pot", style: const TextStyle(color: accentCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                                                      ]),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ],
                                            // Elemento dominante
                                            if (horarios.isNotEmpty) ...[
                                              _buildSubSectionTitle("🌍 ELEMENTOS"),
                                              Builder(builder: (context) {
                                                final elementoMap = <String, int>{};
                                                horarios.forEach((k, v) {
                                                  final elem = (v as Map<String, dynamic>)['elemento']?.toString() ?? '';
                                                  final pot = (potencias?[k] as num?)?.toInt() ?? 0;
                                                  if (elem.isNotEmpty) {
                                                    elementoMap[elem] = (elementoMap[elem] ?? 0) + pot;
                                                  }
                                                });
                                                return Column(
                                                  children: elementoMap.entries.map((e) =>
                                                    _buildDataRow(e.key, e.value.toString())
                                                  ).toList(),
                                                );
                                              }),
                                            ],
                                          ],
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 20),
                                  ],

                                  // ══════════════════════════════════════
                                  // 5. CASAS ASTROLÓGICAS
                                  // ══════════════════════════════════════
                                  if (casas != null) ...[
                                    _buildSectionTitle("🏠  CASAS ASTROLÓGICAS"),
                                    _buildCelestialCard(
                                      gradient: LinearGradient(
                                        colors: [accentPurple.withOpacity(0.1), cardBackground.withOpacity(0.4)],
                                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                                      ),
                                      borderColor: accentPurple.withOpacity(0.25),
                                      child: Builder(builder: (context) {
                                        final dominante = casas['dominant_house'];
                                        final todas = casas['todas'] as Map<String, dynamic>?;
                                        final angulares = casas['angulares'] as Map<String, dynamic>?;
                                        final planetasEnCasas = casas['planetas_en_casas'] as Map<String, dynamic>?;
                                        final angles = casas['angles'] as Map<String, dynamic>?;
                                        final apiHouses = casas['api_houses_data'] as Map<String, dynamic>?;

                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Casa dominante
                                            if (dominante != null) ...[
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                margin: const EdgeInsets.only(bottom: 10),
                                                decoration: BoxDecoration(
                                                  color: accentPurple.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: accentPurple.withOpacity(0.4)),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                                      const Text("🏆 Casa Dominante", style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                                                      Text("Casa $dominante", style: const TextStyle(color: accentPurple, fontWeight: FontWeight.bold, fontSize: 13)),
                                                    ]),
                                                    if (todas?[dominante.toString()] != null) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        todas![dominante.toString()]!['significado']?.toString() ?? '',
                                                        style: const TextStyle(color: secondaryTextColor, fontSize: 11),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                            // Ángulos astrológicos
                                            if (angles != null) ...[
                                              _buildSubSectionTitle("📐 ÁNGULOS"),
                                              _buildDataRow("Asc", "${(angles['ascendant'] as num?)?.toStringAsFixed(1) ?? 'N/D'}°"),
                                              _buildDataRow("MC", "${(angles['mc'] as num?)?.toStringAsFixed(1) ?? 'N/D'}°"),
                                              _buildDataRow("Desc", "${(angles['descendant'] as num?)?.toStringAsFixed(1) ?? 'N/D'}°"),
                                              _buildDataRow("IC", "${(angles['ic'] as num?)?.toStringAsFixed(1) ?? 'N/D'}°"),
                                            ],
                                            // API Houses: ascendente y MC
                                            if (apiHouses != null) ...[
                                              const SizedBox(height: 4),
                                              _buildDataRow("♈ Ascendente", _capitalize(apiHouses['ascendente']?.toString() ?? 'N/D')),
                                              _buildDataRow("♑ Medio Cielo", _capitalize(apiHouses['medio_cielo']?.toString() ?? 'N/D')),
                                            ],
                                            // Casas angulares activas
                                            if (angulares != null && angulares.isNotEmpty) ...[
                                              _buildSubSectionTitle("🔺 CASAS ANGULARES ACTIVAS"),
                                              ...angulares.entries.map((entry) {
                                                final info = entry.value as Map<String, dynamic>;
                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                                  decoration: BoxDecoration(
                                                    border: Border(left: BorderSide(color: Colors.orangeAccent.withOpacity(0.6), width: 2)),
                                                    color: Colors.orange.withOpacity(0.05),
                                                    borderRadius: const BorderRadius.only(
                                                      topRight: Radius.circular(8), bottomRight: Radius.circular(8),
                                                    ),
                                                  ),
                                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                                      Text("Casa ${entry.key} — ${info['titulo'] ?? ''}", style: const TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                                      Text("${(info['cusp'] as num?)?.toStringAsFixed(1) ?? '?'}°", style: const TextStyle(color: accentCyan, fontSize: 12)),
                                                    ]),
                                                    if (info['significado'] != null)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 2),
                                                        child: Text(info['significado'].toString(), style: const TextStyle(color: secondaryTextColor, fontSize: 10)),
                                                      ),
                                                    if (info['power'] != null)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 4),
                                                        child: Row(children: [
                                                          const Text("⚡", style: TextStyle(fontSize: 11)),
                                                          const SizedBox(width: 4),
                                                          Text("Poder: ${info['power']}", style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                                                        ]),
                                                      ),
                                                  ]),
                                                );
                                              }),
                                            ],
                                            // Planetas en casas
                                            if (planetasEnCasas != null && planetasEnCasas.isNotEmpty) ...[
                                              _buildSubSectionTitle("🪐 PLANETAS EN CASAS"),
                                              Wrap(
                                                spacing: 6, runSpacing: 6,
                                                children: planetasEnCasas.entries.map((entry) {
                                                  final info = entry.value as Map<String, dynamic>;
                                                  final simbolo = info['simbolo']?.toString() ?? '🪐';
                                                  final casaNom = info['house_name']?.toString() ?? 'Casa ${info['house']}';
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.shade900.withOpacity(0.3),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.green.shade700.withOpacity(0.5)),
                                                    ),
                                                    child: Text(
                                                      "$simbolo ${_capitalize(entry.key)} · $casaNom",
                                                      style: TextStyle(color: Colors.green.shade300, fontSize: 11),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ],
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 20),
                                  ],

                                  // ══════════════════════════════════════
                                  // 6. IDENTIDAD ASTRAL (Big 3)
                                  // ══════════════════════════════════════
                                  Builder(builder: (context) {
                                    final sunSign = _capitalize(
                                      solar?['position']?['constellation']?.toString() ??
                                      (planetas?['api_data']?['sol'] as Map<String, dynamic>?)?['constellation']?.toString() ??
                                      'N/D',
                                    );
                                    final moonSign = _capitalize(
                                      lunar?['constellation']?.toString() ?? 'N/D',
                                    );
                                    final ascSign = _capitalize(
                                      casas?['api_houses_data']?['ascendente']?.toString() ?? 'N/D',
                                    );
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionTitle("IDENTIDAD ASTRAL (Big 3)"),
                                        Row(children: [
                                          _buildAstroChip("Sol", sunSign, Icons.wb_sunny, Colors.orange),
                                          const SizedBox(width: 8),
                                          _buildAstroChip("Luna", moonSign, Icons.dark_mode, Colors.blueGrey),
                                          const SizedBox(width: 8),
                                          _buildAstroChip("Asc", ascSign, Icons.arrow_upward, accentCyan),
                                        ]),
                                        const SizedBox(height: 20),
                                      ],
                                    );
                                  }),

                                  // ══════════════════════════════════════
                                  // 7. CONFIGURACIÓN CELESTIAL
                                  // ══════════════════════════════════════
                                  _buildSectionTitle("⚙️  CONFIGURACIÓN CELESTIAL"),
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    margin: const EdgeInsets.only(bottom: 30),
                                    decoration: BoxDecoration(
                                      color: cardBackground.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(color: accentPurple.withOpacity(0.3)),
                                    ),
                                    child: Column(children: [
                                      Row(children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async { await _pickDate(); setModalState(() {}); },
                                            child: InputDecorator(
                                              decoration: InputDecoration(
                                                labelText: "Fecha",
                                                labelStyle: const TextStyle(color: secondaryTextColor),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                prefixIcon: const Icon(Icons.calendar_today, color: accentCyan),
                                              ),
                                              child: Text("${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}", style: const TextStyle(color: textColor)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async { await _pickTime(); setModalState(() {}); },
                                            child: InputDecorator(
                                              decoration: InputDecoration(
                                                labelText: "Hora",
                                                labelStyle: const TextStyle(color: secondaryTextColor),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                prefixIcon: const Icon(Icons.access_time, color: accentCyan),
                                              ),
                                              child: Text("${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}", style: const TextStyle(color: textColor)),
                                            ),
                                          ),
                                        ),
                                      ]),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _locationController,
                                        style: const TextStyle(color: textColor),
                                        onEditingComplete: () async { await _searchLocationAddress(); setModalState(() {}); },
                                        decoration: InputDecoration(
                                          labelText: "Buscar Ubicación",
                                          hintText: "Ej: Madrid, España",
                                          hintStyle: TextStyle(color: secondaryTextColor.withOpacity(0.4)),
                                          labelStyle: const TextStyle(color: secondaryTextColor),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          prefixIcon: const Icon(Icons.location_city, color: accentPurple),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.search, color: accentCyan),
                                            onPressed: () async { await _searchLocationAddress(); setModalState(() {}); },
                                          ),
                                        ),
                                        onSubmitted: (_) async { await _searchLocationAddress(); setModalState(() {}); },
                                      ),
                                      const SizedBox(height: 12),
                                      Row(children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _latController,
                                            style: const TextStyle(color: textColor),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                            decoration: InputDecoration(
                                              labelText: "Latitud",
                                              labelStyle: const TextStyle(color: secondaryTextColor),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onSubmitted: (_) { _updateSkyData(onRefreshed: () { if (mounted) setModalState(() {}); }); setModalState(() {}); },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: TextField(
                                            controller: _lonController,
                                            style: const TextStyle(color: textColor),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                            decoration: InputDecoration(
                                              labelText: "Longitud",
                                              labelStyle: const TextStyle(color: secondaryTextColor),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onSubmitted: (_) { _updateSkyData(onRefreshed: () { if (mounted) setModalState(() {}); }); setModalState(() {}); },
                                          ),
                                        ),
                                      ]),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _isUpdating ? null : () async {
                                            final messenger = ScaffoldMessenger.of(this.context);
                                            Navigator.of(context).pop();

                                            final updated = await _updateSkyData();
                                            if (!mounted || !updated) return;

                                            messenger.showSnackBar(const SnackBar(
                                              content: Text("Cielo actualizado con éxito"),
                                              duration: Duration(seconds: 2),
                                              backgroundColor: Colors.green,
                                            ));
                                          },
                                          icon: const Icon(Icons.refresh, color: backgroundColor),
                                          label: const Text("Refrescar Cielo", style: TextStyle(color: backgroundColor, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: accentCyan,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ]),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCelestialCard({required Widget child, required LinearGradient gradient, required Color borderColor}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _buildVisibleBadge(bool isVisible) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isVisible ? Colors.greenAccent.withOpacity(0.12) : Colors.redAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isVisible ? Colors.greenAccent.withOpacity(0.45) : Colors.redAccent.withOpacity(0.45),
        ),
        boxShadow: isVisible ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.15), blurRadius: 6)] : [],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isVisible ? Icons.visibility : Icons.visibility_off,
          color: isVisible ? Colors.green.shade300 : Colors.red.shade300, size: 12),
        const SizedBox(width: 4),
        Text(isVisible ? "Visible" : "Oculto",
          style: TextStyle(color: isVisible ? Colors.green.shade300 : Colors.red.shade300, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  void _showWallpaperOptions(BuildContext ctx) {
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "Fondo de Pantalla Celestial",
              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "El cielo se obtiene en tiempo real desde el servidor.",
              style: TextStyle(color: secondaryTextColor, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.preview_rounded, color: accentCyan),
              title: const Text("Previsualizar Cielo", style: TextStyle(color: textColor)),
              subtitle: const Text("Ver el mapa celeste a pantalla completa",
                  style: TextStyle(color: secondaryTextColor, fontSize: 11)),
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => CelestialScreenSaver(lat: lat, lon: lon),
                ));
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.home_outlined, color: accentCyan),
              title: const Text("Pantalla Principal", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _applyWallpaper(ctx, WallpaperTarget.home);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: accentCyan),
              title: const Text("Pantalla de Bloqueo", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _applyWallpaper(ctx, WallpaperTarget.lock);
              },
            ),
            ListTile(
              leading: const Icon(Icons.wallpaper_rounded, color: accentPurple),
              title: const Text("Ambas Pantallas",
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _applyWallpaper(ctx, WallpaperTarget.both);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyWallpaper(BuildContext ctx, WallpaperTarget target) async {
    final lat = double.tryParse(_latController.text) ?? -33.5227;
    final lon = double.tryParse(_lonController.text) ?? -70.5983;
    final dt = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute,
    );

    await persistWallpaperSettings(lat: lat, lon: lon, target: target);
    await scheduleWallpaperRefresh(initialDelay: const Duration(minutes: 2));

    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text("Generando fondo celestial..."),
        ]),
        duration: Duration(seconds: 60),
        backgroundColor: accentPurple,
      ),
    );
    try {
      await refreshWallpaperFromServer(date: dt);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text("¡Fondo celestial aplicado! ✨"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
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
          leading: PopupMenuButton<String>(
            icon: const Icon(
              Icons.account_circle_outlined,
              size: 24,
              color: secondaryTextColor,
            ),
            tooltip: "Usuario",
            offset: const Offset(0, 40),
            color: cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: accentCyan.withOpacity(0.2)),
            ),
            onSelected: (value) async {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              } else if (value == 'logout') {
                await _authService.logout();
                if (mounted) Navigator.pushReplacementNamed(context, "/login");
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: accentCyan, size: 20),
                    SizedBox(width: 10),
                    Text("Ver Perfil", style: TextStyle(color: textColor)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text("Cerrar Sesión", style: TextStyle(color: textColor)),
                  ],
                ),
              ),
            ],
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
                fontSize: 9.5,
                letterSpacing: 0.5,
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
              future: _canvasMapFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final apiData = snapshot.data!;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.wallpaper_rounded,
                          size: 20,
                          color: accentCyan,
                        ),
                        tooltip: "Fondo de Pantalla Celestial",
                        onPressed: () => _showWallpaperOptions(context),
                      ),
                    ],
                  );
                }
                return const SizedBox(width: 48); // Espacio simétrico
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            TabBarView(
              physics: const NeverScrollableScrollPhysics(), // Evita conflicto con gestos
              children: [
                // TAB 1: HOME
                Stack(
                  children: [
                    // Fondo gradiente
                    Positioned.fill(
                      child: Container(
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
                    ),
                    // Mapa SVG del cielo (obtenido desde map-svg-mobile)
                    Positioned.fill(
                      child: FutureBuilder<String?>(
                        future: _svgFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: accentCyan),
                            );
                          }
                          if (snapshot.hasError ||
                              !snapshot.hasData ||
                              snapshot.data == null ||
                              snapshot.data!.isEmpty) {
                            return const Center(
                              child: Text(
                                "No se pudo cargar el mapa celestial.",
                                style: TextStyle(color: Colors.white54),
                              ),
                            );
                          }
                          return RefreshIndicator(
                            onRefresh: () async => _initLocationAndData(),
                            color: accentCyan,
                            backgroundColor: cardBackground,
                            displacement: 60,
                            notificationPredicate: (notification) => notification.depth == 0,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height: MediaQuery.of(context).size.height,
                                width: MediaQuery.of(context).size.width,
                                child: InteractiveViewer(
                                  transformationController: _viewerController,
                                  onInteractionEnd: _onInteractionEnd,
                                  minScale: 1.0,
                                  maxScale: 5.0,
                                  panEnabled: true,
                                  child: SvgPicture.string(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                    width: MediaQuery.of(context).size.width,
                                    height: MediaQuery.of(context).size.height,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    /*
                    // =====================================================
                    // [CANVAS COMENTADO - RESERVADO PARA USO FUTURO]
                    // Renderizado con CustomPainter + CelestialPainter
                    // =====================================================
                    Positioned.fill(
                      child: FutureBuilder<Map<String, dynamic>?>(
                        future: _canvasMapFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: accentCyan),
                            );
                          }
                          if (snapshot.hasError || !snapshot.hasData ||
                              snapshot.data == null || snapshot.data!.isEmpty) {
                            return const Center(
                              child: Text('No se pudo cargar el mapa celestial.',
                                  style: TextStyle(color: Colors.white54)),
                            );
                          }
                          final apiData = snapshot.data!;
                          return RefreshIndicator(
                            onRefresh: () async => _initLocationAndData(),
                            color: accentCyan,
                            backgroundColor: cardBackground,
                            displacement: 60,
                            notificationPredicate: (n) => n.depth == 0,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height: MediaQuery.of(context).size.height,
                                width: MediaQuery.of(context).size.width,
                                child: RepaintBoundary(
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: const Duration(seconds: 4),
                                    builder: (context, value, child) {
                                      return CustomPaint(
                                        size: Size.infinite,
                                        painter: CelestialPainter(
                                          data: apiData,
                                          animationValue: value,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    */
                  ],
                ),

                // TAB 2: CONSULTAS
                const OracleConsultationsScreen(),

                // TAB 3: CARTAS
                const AstralChartsScreen(),
              ],
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, child) {
                if (tabController.index != 0) return const SizedBox.shrink();
                return FloatingActionButton.extended(
                  onPressed: _mostrarMenuDetalles,
                  backgroundColor: accentPurple.withOpacity(0.9),
                  icon: const Icon(Icons.explore, color: Colors.white),
                  label: const Text(
                    "Planetas",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                );
              },
            );
          }
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
