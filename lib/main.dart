import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';

void main() {
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
        '/home': (context) => HomeScreen(),
      },
    );
  }
}

