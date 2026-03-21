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
    // Simulamos un pequeño retraso para ver el logo
    await Future.delayed(const Duration(seconds: 2));

    String? token = await _authService.getToken();

    if (mounted) {
      if (token != null && token.isNotEmpty) {
        // Token existe -> Ir al Dashboard
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // No hay token -> Ir al Login
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 80, color: Color(0xFF2E7D32)),
            SizedBox(height: 20),
            CircularProgressIndicator(
              color: Color(0xFF2E7D32),
            ),
          ],
        ),
      ),
    );
  }
}
