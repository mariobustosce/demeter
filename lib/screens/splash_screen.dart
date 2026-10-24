import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  // Verifica si ya existe un token almacenado
  Future<void> _checkAuth() async {
    // La espera mínima del logo corre en paralelo con la verificación de
    // sesión, no antes: así el splash dura lo que tarde lo más lento de los
    // dos, en lugar de sumar ambos tiempos.
    final results = await Future.wait<Object?>([
      Future<void>.delayed(kSplashMinDuration),
      _resolveSession(),
    ]);

    if (!mounted) return;
    final hasSession = results[1] == true;
    Navigator.pushReplacementNamed(context, hasSession ? '/home' : kGuestRoute);
  }

  /// `true` si hay sesión. Si `/me` falla sin red el token sigue guardado y se
  /// entra igual; si el servidor lo rechazó (401), el ApiClient ya lo borró.
  Future<bool> _resolveSession() async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return false;
      if (await _authService.getMe() != null) return true;
      return await _authService.getToken() != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E17), // Nuevo color de fondo
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Carga el icono en PNG
            Image.asset(
              'assets/icon/icon.png',
              width: 160,
              height: 160,
            ),
            const SizedBox(height: 40),
            // Rueda de progreso estilizada acorde al tema astrológico
            const CircularProgressIndicator(color: Color(0xFF4FD0E7)), 
          ],
        ),
      ),
    );
  }
}
