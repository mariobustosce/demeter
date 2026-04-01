import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen_v2.dart';
import 'services/sky_service.dart';

import 'package:workmanager/workmanager.dart';
import 'screens/celestial_painter.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Background Task (Workmanager) desactivada por unificación a Live Canvas.");
    return Future.value(true);
  });
}

// NUEVO: Punto de entrada para el Live Wallpaper de Android (Cielo Vivo)
@pragma('vm:entry-point')
void wallpaperMain() {
  // 1. Aseguramos la inicialización del motor gráfico para el Wallpaper
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Arrancamos la App de inmediato para que Flutter registre el Surface
  // No esperamos a SharedPreferences aquí, lo cargamos dentro del Widget
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const _CelestialWallpaperView(),
    ),
  );
}

class _CelestialWallpaperView extends StatefulWidget {
  const _CelestialWallpaperView();

  @override
  State<_CelestialWallpaperView> createState() => _CelestialWallpaperViewState();
}

class _CelestialWallpaperViewState extends State<_CelestialWallpaperView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Map<String, dynamic> _currentData = {};
  double _xOffset = 0.5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // 3. Carga asíncrona de datos guardados post-renderizado inicial
    _loadInitialData();

    // Escuchamos eventos del sistema (como cambio de pantalla/deslizamiento)
    const platform = MethodChannel('com.example.demeter/wallpaper');
    platform.setMethodCallHandler((call) async {
      if (call.method == "onOffsetsChanged") {
        if (mounted) {
          setState(() {
            _xOffset = call.arguments['x'] ?? 0.5;
          });
        }
      } else if (call.method == "updateData") {
        if (mounted) {
          setState(() {
            _currentData = call.arguments;
          });
        }
      }
    });
  }

  Future<void> _loadInitialData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastDataRaw = prefs.getString('last_sky_data');
      if (lastDataRaw != null && mounted) {
        setState(() {
          _currentData = jsonDecode(lastDataRaw);
        });
      }
    } catch (e) {
      debugPrint("Error cargando data inicial del wallpaper: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay data aún, pintamos igual pero pasamos un mapa vacío
    // para que el Painter dibuje el fondo degradado genérico en lugar de 'Container()'
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: CelestialPainter(
              data: _currentData,
              animationValue: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

Future<void> updateWallpaperTask() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("Background: Actualizando fondo de manera periodica...");
  
  try {
    // 1. Obtener la data astronómica. 
    // NOTA: Como estamos en background y no tenemos acceso directo al GPS 
    // sin permisos extra, usaremos latitud/longitud por defecto o pre-grabada.
    final SkyService skyService = SkyService();
    final DateTime dt = DateTime.now();
    
    // Santiago, La Florida, Chile por defecto (Hemisferio Sur)
    double lat = -33.5227; 
    double lon = -70.5983;
    
    final svgString = await skyService.getMapSvgMobile(
      lat: lat,
      lng: lon,
      date: dt,
    );

    if (svgString == null || svgString.isEmpty) return;

    // 2. Renderizar SVG
    final pictureInfo = await vg.loadPicture(
      SvgStringLoader(svgString),
      null,
    );

    final image = await pictureInfo.picture.toImage(1080, 2400);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData?.buffer.asUint8List();

    if (pngBytes == null) return;

    // 3. Guardar imagen
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/bg_unlock_wallpaper.png');
    await file.writeAsBytes(pngBytes);

    // 4. Cambiar fondo
    await AsyncWallpaper.setWallpaper(
      WallpaperRequest(
        source: file.path,
        sourceType: WallpaperSourceType.file,
        target: WallpaperTarget.both, // o homeScreen
      ),
    );
    
    print("Background: ¡Fondo actualizado con éxito tras desbloqueo!");
  } catch (e) {
    print("Background Error: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Workmanager con un pequeño delay o después del primer frame
  Future.delayed(const Duration(seconds: 3), () async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false
    );

    await Workmanager().registerPeriodicTask(
      "1", 
      "simplePeriodicTask",
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 5), // Aumentamos el delay inicial
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Quitar etiqueta 'Debug' para más limpieza
      title: 'Demeter App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)), // Verde Demeter
        useMaterial3: true,
      ),
      // Definimos rutas para navegar fácilmente entre pantallas
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(), // Esta verifica si hay token
        '/login': (context) => LoginScreen(),
        '/home': (context) => const HomeScreenV2(),
      },
    );
  }
}

