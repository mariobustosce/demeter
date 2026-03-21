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
    _initLocation();
    
    // Inicia con la fecha/hora actual
    _updateSkyData(initial: true);
  }

  Future<void> _initLocation() async {
    try {
      // Intentamos obtener la ubicación inicial para rellenar los campos
      // Usamos el servicio de geolocator directamente o asumimos valores por defecto
      // Nota: SkyService ya maneja permisos internamente, aquí es solo para UI
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            final pos = await Geolocator.getCurrentPosition();
            if (mounted) {
              setState(() {
                _latController.text = pos.latitude.toString();
                _lonController.text = pos.longitude.toString();
                _updateSkyData(); // Actualizar con ubicación real
              });
            }
          }
      }
    } catch (e) {
      print("Error obteniendo ubicación inicial UI: $e");
    }
  }

  void _updateSkyData({bool initial = false}) {
    // Si no es un año válido, no hacemos nada para evitar crashes
    if (_selectedDate.year < 0) return;

    final dt = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute
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
    final astralFuture = _skyService.getAstralProfile(lat: lat, lng: lon, date: dt);

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
            ), dialogTheme: DialogThemeData(backgroundColor: backgroundColor),
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
            ), dialogTheme: DialogThemeData(backgroundColor: backgroundColor),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ubicación no encontrada")));
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
        const SnackBar(content: Text("Preparando fondo de pantalla..."), duration: Duration(seconds: 2)),
      );

      // 1. Convertir SVG a una imagen de alta resolución (tipo fondo de pantalla)
      final pictureInfo = await vg.loadPicture(SvgStringLoader(svgString), null);
      
      // Renderizamos a una resolución apropiada (1080x2400 por ejemplo)
      final image = await pictureInfo.picture.toImage(1080, 2400); 
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null) throw Exception("Error al procesar la imagen celeste.");

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
            const SnackBar(content: Text("¡Fondo de pantalla actualizado con éxito!"), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No se pudo establecer el fondo. Error: ${result.error?.message ?? 'Desconocido'}"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error interno: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("WindowsDemeter"),
        elevation: 0,
        backgroundColor: backgroundColor,
        foregroundColor: accentCyan,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          // 1. ZONA ESTÁTICA: HORIZONTE DEL ORÁCULO (SVG)
          Container(
            height: 300, 
            decoration: BoxDecoration(
              color: cardBackground,
              border: Border(bottom: BorderSide(color: accentCyan.withOpacity(0.3), width: 1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))
              ]
            ),
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _skyMapFuture,
              builder: (context, skySnapshot) {
                Widget svgContent;
                String locationText = "Conectando con los astros...";

                if (skySnapshot.connectionState == ConnectionState.waiting) {
                  svgContent = const Expanded(
                    child: Center(child: CircularProgressIndicator(color: accentCyan)),
                  );
                } else if (skySnapshot.hasData && skySnapshot.data?['svg'] != null) {
                  final data = skySnapshot.data!;
                  locationText = data['location'] ?? "Ubicación desconocida";
                  
                  svgContent = Expanded(
                    child: ClipRect(
                      child: FractionallySizedBox(
                        widthFactor: 1.0, // Mantiene el ancho del contenedor
                        heightFactor: 1.0, // Mantiene el alto del contenedor
                        child: Transform.scale(
                          scale: 0.2, // Zoom de 2.0x
                          alignment: Alignment.center,
                          child: SvgPicture.string(
                            data['svg'].toString().trim(),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover, // Cubre el espacio para evitar que se vea como cuadrado
                            placeholderBuilder: (context) => const Center(
                              child: CircularProgressIndicator(color: accentCyan),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  svgContent = const Expanded(
                    child: Center(
                      child: Text("No se pudo revelar el horizonte.", style: TextStyle(color: Colors.redAccent))
                    ),
                  );
                }

                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Horizonte del Oráculo",
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        if (skySnapshot.hasData && skySnapshot.data?['svg'] != null)
                          IconButton(
                            icon: const Icon(Icons.wallpaper, color: accentCyan, size: 20),
                            tooltip: "Establecer como fondo de pantalla",
                            onPressed: () => _setWallpaper(skySnapshot.data!['svg']),
                          ),
                      ],
                    ),
                    Text(
                      locationText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: secondaryTextColor, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    svgContent,
                  ],
                );
              }
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
                          } 
                        ),
                        
                        FutureBuilder<Map<String, dynamic>>(
                  future: _astralProfileFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator(color: accentPurple)),
                    );
                    }
                    
                    final physics = snapshot.data!['physics'] as Map<String, dynamic>?;
                    final astro = snapshot.data!['astrology'] as Map<String, dynamic>?;
                    final planetary = snapshot.data!['planetary'] as Map<String, dynamic>?;
                    
                    // Si falta astro, no mostramos nada.
                    if (astro == null || astro.isEmpty) return const SizedBox.shrink();

                    final daily = physics?['daily'];
                    final extended = physics?['extended'];
                    final hasPhysics = daily != null && extended != null;

                    // Datos seguros para la sección física de Sol
                    final sunrise = hasPhysics && daily['sunrise'] != null && (daily['sunrise'] as List).isNotEmpty ? daily['sunrise'][0] : null;
                    final sunset = hasPhysics && daily['sunset'] != null && (daily['sunset'] as List).isNotEmpty ? daily['sunset'][0] : null;
                    final daylightSeconds = hasPhysics && daily['daylight_duration'] != null && (daily['daylight_duration'] as List).isNotEmpty ? daily['daylight_duration'][0] : 0.0;
                    final maxUv = hasPhysics && daily['uv_index_max'] != null && (daily['uv_index_max'] as List).isNotEmpty ? daily['uv_index_max'][0] : 0.0;

                    // Datos extendidos (Luna y Eventos Solares)
                    final moonrise = hasPhysics ? extended['moonrise'] : null;
                    final moonset = hasPhysics ? extended['moonset'] : null;
                    final moonPhaseVal = hasPhysics ? (extended['moon_phase'] as double) : 0.0;
                    final moonAgeDays = hasPhysics ? extended['moon_age_days'] : 0.0;
                    final season = hasPhysics ? extended['season'] : 'Desconocida';
                    final solarNoon = hasPhysics ? extended['solar_noon'] : null;
                    final distanceMoon = hasPhysics ? extended['distance_to_earth_km'] : 0.0;

                    // Procesamiento de Planetas de AstronomyAPI
                    final planetaryDataFound = planetary?['data']?['table']?['rows'];
                    final realPlanets = (planetaryDataFound is List) ? planetaryDataFound : [];

                    // Filtrar Sol y Luna de la lista de planetas para no duplicarlos en la sección de abajo
                    final visiblePlanetsList = realPlanets.where((r) {
                      final name = r['cells'][0]['name'];
                      return name != 'Sun' && name != 'Moon' && name != 'Earth';
                    }).toList();

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                      child: Column(
                        children: [
                          // 1. CICLOS CELESTIALES (SOL Y LUNA DETALLADOS)
                          if (sunrise != null && sunset != null) ...[
                            _buildSectionTitle("LUMINARIAS Y CICLOS"),
                            
                            // --- TARJETA DEL SOL ---
                            Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.orange.withOpacity(0.2), Colors.redAccent.withOpacity(0.1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.wb_sunny, color: Colors.orangeAccent, size: 32),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text("SOL", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                              Text(
                                                "${(daylightSeconds / 3600).toStringAsFixed(1)}h de Luz  |  Índice UV: $maxUv", 
                                                style: const TextStyle(color: secondaryTextColor, fontSize: 12)
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Row(children: [
                                            const Icon(Icons.arrow_upward, size: 14, color: Colors.orange),
                                            const SizedBox(width: 4),
                                            Text(_formatTime(sunrise), style: const TextStyle(color: textColor)),
                                          ]),
                                          const SizedBox(height: 4),
                                          Row(children: [
                                            const Icon(Icons.arrow_downward, size: 14, color: Colors.deepOrange),
                                            const SizedBox(width: 4),
                                            Text(_formatTime(sunset), style: const TextStyle(color: textColor)),
                                          ]),
                                        ],
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Fila extra de datos solares
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Estación: $season", style: const TextStyle(color: accentCyan, fontSize: 11, fontWeight: FontWeight.w600)),
                                      if (solarNoon != null)
                                        Text("Cénit: ${_formatTime(solarNoon)}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Barra de progreso del día
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final now = DateTime.now();
                                      DateTime? start, end;
                                      
                                      try {
                                        start = DateTime.parse(sunrise);
                                        end = DateTime.parse(sunset);
                                      } catch(_) {}
                                      
                                      double progress = 0.0;
                                      if (start != null && end != null) {
                                        final total = end.difference(start).inMinutes;
                                        final current = now.difference(start).inMinutes;
                                        progress = (total > 0) ? (current / total).clamp(0.0, 1.0) : 0.0;
                                        if (now.isAfter(end)) progress = 1.0;
                                        if (now.isBefore(start)) progress = 0.0;
                                      }

                                      return Column(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: LinearProgressIndicator(
                                              value: progress,
                                              backgroundColor: Colors.black26,
                                              color: Colors.orangeAccent,
                                              minHeight: 6,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            progress >= 1.0 ? "El sol se ha puesto" : (progress <= 0.0 ? "Esperando el amanecer" : "Curso Solar: ${(progress * 100).toInt()}%"),
                                            style: const TextStyle(color: secondaryTextColor, fontSize: 10)
                                          )
                                        ],
                                      );
                                    }
                                  )
                                ],
                              ),
                            ),

                            // --- TARJETA DE LA LUNA ---
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [const Color(0xFF1A237E).withOpacity(0.4), const Color(0xFF4A148C).withOpacity(0.2)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: accentPurple.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            moonPhaseVal > 0.4 && moonPhaseVal < 0.6 ? Icons.circle : Icons.nightlight_round, 
                                            color: Colors.grey.shade300, 
                                            size: 32
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text("LUNA", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                              Text(
                                                _getMoonPhaseName(moonPhaseVal), 
                                                style: const TextStyle(color: secondaryTextColor, fontSize: 12)
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                           Row(children: [
                                            const Icon(Icons.arrow_upward, size: 14, color: accentPurple),
                                            const SizedBox(width: 4),
                                            Text(moonrise != null ? _formatTime(moonrise) : "--:--", style: const TextStyle(color: textColor)),
                                          ]),
                                          const SizedBox(height: 4),
                                          Row(children: [
                                            const Icon(Icons.arrow_downward, size: 14, color: Colors.blueGrey),
                                            const SizedBox(width: 4),
                                            Text(moonset != null ? _formatTime(moonset) : "--:--", style: const TextStyle(color: textColor)),
                                          ]),
                                        ],
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Detalles extendidos de la Luna
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Edad: $moonAgeDays días", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                      Text("Distancia: ${distanceMoon.toInt()} km", style: const TextStyle(color: accentPurple, fontSize: 11)),
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
                                      final illumination = 0.5 * (1 - math.cos(moonPhaseVal * 2 * math.pi));
                                      
                                      return Column(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: LinearProgressIndicator(
                                              value: illumination,
                                              backgroundColor: Colors.black26,
                                              color: Colors.grey.shade300,
                                              minHeight: 6,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            "Iluminación: $illumination %",
                                            style: const TextStyle(color: secondaryTextColor, fontSize: 10)
                                          )
                                        ],
                                      );
                                    }
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],

                          // 2. VISIBILIDAD DE PLANETAS REALES
                          if (visiblePlanetsList.isNotEmpty) ...[
                            _buildSectionTitle("VISIBILIDAD PLANETARIA"),
                            ...visiblePlanetsList.take(12).map((planetRow) {
                              final cells = planetRow['cells'] as List;
                              // Estructura segura
                              if (cells.isEmpty) return const SizedBox.shrink();

                              final rawName = cells[0]['name'] ?? 'Cuerpo Celeste';
                              // Traductor simple al español
                              final nameMap = {
                                'Mercury': 'Mercurio', 'Venus': 'Venus', 'Mars': 'Marte',
                                'Jupiter': 'Júpiter', 'Saturn': 'Saturno', 'Uranus': 'Urano',
                                'Neptune': 'Neptuno', 'Pluto': 'Plutón'
                              };
                              final name = nameMap[rawName] ?? rawName;

                              final extra = cells[0]['extra'];
                              
                              final isVisible = extra != null && extra['is_visible'] == true;
                              
                              String riseTime = "--:--";
                              String setTime = "--:--";
                              String timeLeftStr = "";

                              if (extra != null) {
                                if (extra['rise'] != null) {
                                  // Puede venir completo ISO o solo la hora, nos protegemos
                                  try {
                                    riseTime = extra['rise'].toString().split('T').last.substring(0, 5);
                                  } catch (_) { riseTime = extra['rise'].toString(); }
                                }
                                if (extra['set'] != null) {
                                  try {
                                    setTime = extra['set'].toString().split('T').last.substring(0, 5);
                                    
                                    // Calcular tiempo restante si es visible
                                    if (isVisible) {
                                        final setDt = DateTime.tryParse(extra['set'].toString());
                                        if (setDt != null) {
                                          final now = DateTime.now();
                                          // Comparación simple, si la fecha es hoy
                                          final diff = setDt.difference(now);
                                          if (diff.inMinutes > 0) {
                                            timeLeftStr = "${diff.inHours}h ${diff.inMinutes % 60}m vigentes";
                                          }
                                        }
                                    }
                                  } catch(_) { setTime = extra['set'].toString(); }
                                }
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cardBackground.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: isVisible ? accentCyan.withOpacity(0.5) : Colors.white10,
                                    width: isVisible ? 1.5 : 1
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isVisible ? Icons.visibility : Icons.visibility_off,
                                      color: isVisible ? accentCyan : secondaryTextColor.withOpacity(0.4),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text(
                                            isVisible ? "Visible en el cielo" : "Bajo el horizonte",
                                            style: TextStyle(color: isVisible ? accentCyan : secondaryTextColor, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (isVisible && timeLeftStr.isNotEmpty)
                                          Text(timeLeftStr, style: const TextStyle(color: accentPurple, fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text("S: $riseTime | P: $setTime", style: const TextStyle(color: secondaryTextColor, fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 30),
                          ],

                           // 3. LOS TRES GRANDES (Siempre visible)
                          _buildSectionTitle("IDENTIDAD ASTRAL (Big 3)"),
                          Row(
                            children: [
                              _buildAstroChip("Sol", astro['big_three']['sun'], Icons.wb_sunny, Colors.orange),
                              const SizedBox(width: 8),
                              _buildAstroChip("Luna", astro['big_three']['moon'], Icons.dark_mode, Colors.blueGrey),
                              const SizedBox(width: 8),
                              _buildAstroChip("Asc", astro['big_three']['ascendant'], Icons.arrow_upward, accentCyan),
                            ],
                          ),
                          const SizedBox(height: 30),


                          // 3. POSICIONES PLANETARIAS
                          _buildSectionTitle("TRÁNSITOS PLANETARIOS"),
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: cardBackground.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: accentCyan.withOpacity(0.1)),
                            ),
                            child: Column(
                              children: (astro['planets'] as List).map<Widget>((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.circle, size: 8, color: accentPurple),
                                      const SizedBox(width: 10),
                                      Text(p['name'], style: const TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                    ]),
                                    Text("${p['sign']} ${p['deg']}", style: const TextStyle(color: accentCyan)),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ),
                          const SizedBox(height: 30),

                          // 4. CASAS Y ASPECTOS
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle("CASAS ACTIVAS"),
                                    ... (astro['houses'] as Map).entries.map((e) => 
                                      Text("Casa ${e.key.replaceAll('C', '')}: ${e.value}", 
                                      style: const TextStyle(color: secondaryTextColor, height: 1.5))
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle("ASPECTOS"),
                                    ... (astro['aspects'] as List).map((a) => 
                                      Text("• ${a['planet1']} ${a['type']} ${a['planet2']}", 
                                      style: const TextStyle(color: secondaryTextColor, height: 1.5))
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 40),
                         
                          // --- CONTROLES DEL CIELO (REQ. USUARIO) ---
                          _buildSectionTitle("CONFIGURACIÓN CELESTIAL"),
                          Container(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.only(bottom: 30),
                            decoration: BoxDecoration(
                              color: cardBackground.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: accentPurple.withOpacity(0.3)),
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
                                            labelStyle: const TextStyle(color: secondaryTextColor),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                            prefixIcon: const Icon(Icons.calendar_today, color: accentCyan),
                                          ),
                                          child: Text(
                                            "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                                            style: const TextStyle(color: textColor),
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
                                            labelStyle: const TextStyle(color: secondaryTextColor),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                            prefixIcon: const Icon(Icons.access_time, color: accentCyan),
                                          ),
                                          child: Text(
                                            "${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}",
                                            style: const TextStyle(color: textColor),
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
                                  style: const TextStyle(color: textColor),
                                  onEditingComplete: _searchLocationAddress, // Buscar al presionar Enter en teclado soft
                                  decoration: InputDecoration(
                                    labelText: "Buscar Ubicación (Ej: Madrid, España)",
                                    helperText: "Presiona Enter o la lupa para buscar",
                                    helperStyle: TextStyle(color: secondaryTextColor.withOpacity(0.5)),
                                    hintText: "Ej: Paris, France",
                                    hintStyle: TextStyle(color: secondaryTextColor.withOpacity(0.5)),
                                    labelStyle: const TextStyle(color: secondaryTextColor),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    prefixIcon: const Icon(Icons.location_city, color: accentPurple),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.search, color: accentCyan),
                                      onPressed: _searchLocationAddress,
                                      tooltip: "Buscar coordenadas",
                                    ),
                                  ),
                                  onSubmitted: (_) => _searchLocationAddress(),
                                ),
                                const SizedBox(height: 15),
                                // Latitud y Longitud
                                Row(
                                  children: [
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
                                        onSubmitted: (_) => _updateSkyData(),
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
                                        onSubmitted: (_) => _updateSkyData(),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton.icon(
                                    onPressed: () => _updateSkyData(),
                                    icon: const Icon(Icons.refresh, color: accentCyan),
                                    label: const Text("Refrescar Cielo", style: TextStyle(color: accentCyan)),
                                  ),
                                )
                              ],
                            ),
                          ),

                          // --- BOTÓN PREGUNTA AL ORÁCULO ---
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text("CONSULTAR CARTA NATAL COMPLETA"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentCyan,
                              foregroundColor: backgroundColor,
                              minimumSize: const Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  }
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ],
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

  Widget _buildCycleCard({required String title, required String time, required String remaining, required IconData icon, required Color color}) {
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
            Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
            Text(time, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(remaining, textAlign: TextAlign.center, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildAstroChip(String title, String value, IconData icon, Color color) {
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
            Text(title, style: const TextStyle(color: secondaryTextColor, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
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
