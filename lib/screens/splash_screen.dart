import 'package:flutter/material.dart';
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
    await Future.delayed(const Duration(seconds: 2));

    final token = await _authService.getToken();
    final user = token == null || token.isEmpty
        ? null
        : await _authService.getMe();

    if (mounted) {
      if (user != null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
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
