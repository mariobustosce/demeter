import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/guest_map_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/celestial_live_wallpaper.dart';
import 'screens/home_screen_v2.dart';
import 'screens/store_screen.dart';
import 'config/app_config.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/push_service.dart';
import 'services/token_store.dart';
import 'widgets/map_web_view.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _silenceDebugPrintInRelease();

  // Firebase sí debe estar listo antes del primer frame: el login lo usa. La
  // migración del token también, porque el splash lo lee al abrir. Van en
  // paralelo para no sumar tiempos.
  await Future.wait<void>([
    _initializeFirebase(),
    TokenStore().migrateLegacy(),
  ]);

  // AdMob no bloquea el arranque: el banner se carga cuando el SDK esté listo,
  // y esperarlo acá retrasaba el primer frame entre 0,5 y 2 segundos.
  unawaited(_initializeAds());
  // El push tampoco: el aviso tocado espera en PushService a la pantalla
  // principal. No pide permiso.
  unawaited(PushService.instance.start());

  _handleGlobalApiErrors();
  runApp(const MyApp());
}

/// Errores del API que se resuelven igual desde cualquier pantalla.
void _handleGlobalApiErrors() {
  ApiClient.instance
    ..onSessionExpired = () {
      unawaited(AuthService().clearLocalSession());
      _navigatorKey.currentState
          ?.pushNamedAndRemoveUntil(kGuestRoute, (_) => false);
    }
    ..onInsufficientCoins = (_) {
      _navigatorKey.currentState?.pushNamed('/store');
    };
}

/// Sin Firebase la app arranca igual y solo falla el login con Google. Pasa en
/// iOS mientras no se corra `flutterfire configure`.
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase no se inicializó (${e.runtimeType}).');
  }
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

/// Solo Android: lo arranca `CelestialWallpaperService`. En iOS nadie lo llama.
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
      navigatorObservers: [mapRouteObserver],
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
        kGuestRoute: (context) => const GuestMapScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreenV2(),
        '/store': (context) => const StoreScreen(),
      },
    );
  }
}
