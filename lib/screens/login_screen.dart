import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/auth_service.dart';
import 'two_factor_screen.dart';

/// La «G» oficial de Google, embebida: antes se descargaba de gstatic en cada
/// arranque y sin red el botón quedaba roto.
const String _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18">
  <path fill="#4285F4" d="M17.64 9.2045c0-.6381-.0573-1.2518-.1636-1.8409H9v3.4814h4.8436c-.2086 1.125-.8427 2.0782-1.7959 2.7164v2.2581h2.9087c1.7018-1.5668 2.6836-3.874 2.6836-6.615z"/>
  <path fill="#34A853" d="M9 18c2.43 0 4.4673-.806 5.9564-2.1805l-2.9087-2.2581c-.8059.54-1.8368.859-3.0477.859-2.344 0-4.3282-1.5831-5.036-3.7104H.9574v2.3318C2.4382 15.9832 5.4818 18 9 18z"/>
  <path fill="#FBBC05" d="M3.964 10.71c-.18-.54-.2822-1.1168-.2822-1.71s.1023-1.17.2823-1.71V4.9582H.9573A8.9965 8.9965 0 0 0 0 9c0 1.4523.3477 2.8268.9573 4.0418L3.964 10.71z"/>
  <path fill="#EA4335" d="M9 3.5795c1.3214 0 2.5077.4541 3.4405 1.346l2.5813-2.5814C13.4632.8918 11.4259 0 9 0 5.4818 0 2.4382 2.0168.9573 4.9582L3.964 7.29C4.6718 5.1627 6.6559 3.5795 9 3.5795z"/>
</svg>
''';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  String _readableError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      await _authService.login(
        _emailController.text.trim(),
        _passController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Bienvenido a Demeter!'),
          backgroundColor: Colors.green,
        ),
      );
      // Sin volver atrás al mapa de invitado ni al login.
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } on TwoFactorRequired catch (challenge) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TwoFactorScreen(desafio: challenge.desafio),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_readableError(error)),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);

    try {
      await _authService.loginWithGoogle();

      if (!mounted) return;

      // Sin volver atrás al mapa de invitado ni al login.
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_readableError(error)),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF0A0A0F);
    const deepSpaceColor = Color(0xFF1A1A2E);
    const accentCyan = Color(0xFF4FD0E7);
    const accentPurple = Color(0xFF8B5CF6);
    const cardBackground = Color(0xEF0F172A);
    const textColor = Color(0xFFF7FAFC);
    const secondaryTextColor = Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [deepSpaceColor, Color(0xFF0F0F1E), backgroundColor],
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
                    color: accentCyan.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 50,
                      offset: const Offset(0, 25),
                    ),
                    BoxShadow(
                      color: accentCyan.withValues(alpha: 0.15),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text(
                        '✨',
                        style: TextStyle(
                          fontSize: 60,
                          shadows: [Shadow(color: accentCyan, blurRadius: 20)],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [accentCyan, accentPurple, accentCyan],
                      ).createShader(bounds),
                      child: const Text(
                        'WindowsDemeter',
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
                      'Ventana al Cielo y Oráculo',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: secondaryTextColor),
                    ),
                    const SizedBox(height: 50),
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: secondaryTextColor),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: secondaryTextColor,
                        ),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.4),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: accentCyan.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: accentCyan),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passController,
                      obscureText: true,
                      style: const TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        labelStyle: const TextStyle(color: secondaryTextColor),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: secondaryTextColor,
                        ),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.4),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: accentCyan.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: accentCyan),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [accentCyan, accentPurple, accentCyan],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentCyan.withValues(alpha: 0.35),
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
                            ? const CircularProgressIndicator(
                                color: backgroundColor,
                              )
                            : const Text(
                                'INGRESAR AL ORÁCULO',
                                style: TextStyle(
                                  color: backgroundColor,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: _isLoading || _isGoogleLoading
                          ? null
                          : _handleGoogleLogin,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: accentCyan.withValues(alpha: 0.4)),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isGoogleLoading
                          ? const CircularProgressIndicator(color: accentCyan)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.string(
                                  _googleLogoSvg,
                                  height: 20,
                                  width: 20,
                                ),
                                const SizedBox(width: 12),
                                // Flexible: con letra grande o pantalla
                                // angosta el texto se corta, no desborda.
                                const Flexible(
                                  child: Text(
                                    'Iniciar sesión con Google',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading || _isGoogleLoading
                          ? null
                          : () => Navigator.pushNamed(context, '/register'),
                      child: const Text(
                        'Crear cuenta nueva',
                        style: TextStyle(
                          color: accentCyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(color: Color(0xFF60A5FA)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Desde el mapa de invitado: volver a él.
          if (Navigator.canPop(context))
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  tooltip: 'Volver al mapa',
                  icon: const Icon(Icons.arrow_back_rounded, color: secondaryTextColor),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
