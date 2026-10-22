import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/celestial_live_wallpaper.dart';
import 'screens/home_screen_v2.dart';
import 'screens/store_screen.dart';
import 'config/app_config.dart';
import 'services/api_client.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _silenceDebugPrintInRelease();

  // Firebase sí debe estar listo antes del primer frame: el login lo usa.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // AdMob no bloquea el arranque: el banner se carga cuando el SDK esté listo,
  // y esperarlo acá retrasaba el primer frame entre 0,5 y 2 segundos.
  unawaited(_initializeAds());

  _handleGlobalApiErrors();
  runApp(const MyApp());
}

/// Errores del API que se resuelven igual desde cualquier pantalla.
void _handleGlobalApiErrors() {
  ApiClient.instance
    ..onSessionExpired = () {
      _navigatorKey.currentState
          ?.pushNamedAndRemoveUntil(kGuestRoute, (_) => false);
    }
    ..onInsufficientCoins = (_) {
      _navigatorKey.currentState?.pushNamed('/store');
    };
}

Future<void> _initializeAds() async {
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint('MobileAds init falló: $e');
  }
}

/// En release `debugPrint` no imprime nada. Se aplica en cada entry point
/// porque cada isolate tiene su propia copia de la variable.
void _silenceDebugPrintInRelease() {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
}

@pragma('vm:entry-point')
void wallpaperMain() {
  WidgetsFlutterBinding.ensureInitialized();
  _silenceDebugPrintInRelease();
  runApp(const CelestialLiveWallpaperApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
        kGuestRoute: (context) => LoginScreen(), // Fase 2: GuestMapScreen
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreenV2(),
        '/store': (context) => const StoreScreen(),
      },
    );
  }
}
