import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/celestial_live_wallpaper.dart';
import 'screens/home_screen_v2.dart';
import 'screens/store_screen.dart';
import 'services/wallpaper_refresh_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeWallpaperRefreshWorker();

  runApp(const MyApp());
}

@pragma('vm:entry-point')
void wallpaperMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CelestialLiveWallpaperApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner:
          false, // Quitar etiqueta 'Debug' para más limpieza
      title: 'WindowsDemeter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
        ), // Verde Demeter
        useMaterial3: true,
      ),
      // Definimos rutas para navegar fácilmente entre pantallas
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(), // Esta verifica si hay token
        '/login': (context) => LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreenV2(),
        '/store': (context) => const StoreScreen(),
      },
    );
  }
}
