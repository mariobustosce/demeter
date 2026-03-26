import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);

    bool success = await _authService.login(
      _emailController.text.trim(), 
      _passController.text.trim()
    );

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        // Redirigir al 'Dashboard'
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Bienvenido a Demeter!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/home'); // Usamos la ruta definida
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Credenciales incorrectas"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleGoogleLogin() async {
    setState(() {
      _isGoogleLoading = true;
    });

    bool success = await _authService.loginWithGoogle();

    setState(() {
      _isGoogleLoading = false;
    });

    if (success) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al iniciar sesión con Google'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definición de colores celestiales basados en el estilo CSS enviado
    const backgroundColor = Color(0xFF0A0A0F);
    const deepSpaceColor = Color(0xFF1A1A2E);
    const accentCyan = Color(0xFF4FD0E7);
    const accentPurple = Color(0xFF8B5CF6);
    const cardBackground = Color(0xEF0F172A); // Fondo de tarjeta con opacidad
    const textColor = Color(0xFFF7FAFC);
    const secondaryTextColor = Color(0xFF94A3B8);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // --- FONDO CELESTIAL (Radial Gradients) ---
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  deepSpaceColor,
                  Color(0xFF0F0F1E),
                  backgroundColor,
                ],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(40.0),
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accentCyan.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.8),
                      blurRadius: 50,
                      offset: const Offset(0, 25),
                    ),
                    BoxShadow(
                      color: accentCyan.withOpacity(0.15),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- LOGO / ICONO CELESTIAL ---
                    const Center(
                      child: Text(
                        "✨", // Emoji como placeholder del logo celestial
                        style: TextStyle(
                          fontSize: 60,
                          shadows: [
                            Shadow(
                              color: accentCyan,
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // --- TÍTULO ---
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [accentCyan, accentPurple, accentCyan],
                      ).createShader(bounds),
                      child: const Text(
                        "WindowsDemeter",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Ventana al Cielo y Oráculo",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 50),

                    // --- INPUT EMAIL ---
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: const TextStyle(color: secondaryTextColor),
                        prefixIcon: const Icon(Icons.email_outlined, color: secondaryTextColor),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.4),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: accentCyan.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: accentCyan),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- INPUT PASSWORD ---
                    TextField(
                      controller: _passController,
                      obscureText: true,
                      style: const TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: "Contraseña",
                        labelStyle: const TextStyle(color: secondaryTextColor),
                        prefixIcon: const Icon(Icons.lock_outline, color: secondaryTextColor),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.4),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: accentCyan.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: accentCyan),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- BOTÓN LOGIN ---
                    Container(
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [accentCyan, accentPurple, accentCyan],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentCyan.withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: backgroundColor)
                          : const Text(
                              "INGRESAR AL ORÁCULO",
                              style: TextStyle(
                                color: backgroundColor,
                                fontWeight: FontWeight.bold, 
                                letterSpacing: 1.0,
                              ),
                            ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    // --- BOTÓN GOOGLE (Estilo Celestial) ---
                    OutlinedButton(
                      onPressed: _isLoading || _isGoogleLoading ? null : _handleGoogleLogin,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: accentCyan.withOpacity(0.4)),
                        backgroundColor: Colors.white.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isGoogleLoading
                        ? const CircularProgressIndicator(color: accentCyan)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.network(
                                'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                height: 20,
                                width: 20,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Iniciar sesión con Google",
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                    ),
                    
                    const SizedBox(height: 20),
                    // --- FOOTER TEXT ---
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        "¿Olvidaste tu contraseña?",
                        style: TextStyle(color: Color(0xFF60A5FA)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
