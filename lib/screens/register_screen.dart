import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  String _readableError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos obligatorios.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña debe tener al menos 8 caracteres.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La confirmación de contraseña no coincide.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: confirmPassword,
        referralCode: _referralCodeController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacementNamed(context, '/home');
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

  InputDecoration _buildDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    const accentCyan = Color(0xFF4FD0E7);
    const secondaryTextColor = Color(0xFF94A3B8);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: secondaryTextColor.withOpacity(0.5)),
      labelStyle: const TextStyle(color: secondaryTextColor),
      prefixIcon: Icon(icon, color: secondaryTextColor),
      filled: true,
      fillColor: Colors.black.withOpacity(0.25),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentCyan.withOpacity(0.2)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: accentCyan),
      ),
    );
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
                radius: 1.4,
                colors: [deepSpaceColor, Color(0xFF0F0F1E), backgroundColor],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: cardBackground,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: accentPurple.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.75),
                        blurRadius: 32,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Crear Cuenta',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Regístrate y activa tu saldo astral desde el primer acceso.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: textColor),
                        decoration: _buildDecoration(
                          label: 'Nombre',
                          icon: Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: textColor),
                        decoration: _buildDecoration(
                          label: 'Email',
                          icon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: textColor),
                        decoration: _buildDecoration(
                          label: 'Contraseña',
                          icon: Icons.lock_outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        style: const TextStyle(color: textColor),
                        decoration: _buildDecoration(
                          label: 'Confirmar contraseña',
                          icon: Icons.lock_reset_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _referralCodeController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(color: textColor),
                        decoration: _buildDecoration(
                          label: 'Código de referido',
                          icon: Icons.card_giftcard_outlined,
                          hint: 'Opcional',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [accentCyan, accentPurple],
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
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
                                  'CREAR CUENTA',
                                  style: TextStyle(
                                    color: backgroundColor,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pushReplacementNamed(
                                context,
                                '/login',
                              ),
                        child: const Text(
                          'Ya tengo una cuenta',
                          style: TextStyle(color: accentCyan),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
