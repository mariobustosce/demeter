import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

/// Segundo paso del login cuando la cuenta tiene 2FA: el código de la app
/// autenticadora o uno de recuperación.
class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key, required this.desafio});

  final String desafio;

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  static const backgroundColor = Color(0xFF0A0A0F);
  static const accentCyan = Color(0xFF4FD0E7);
  static const accentPurple = Color(0xFF8B5CF6);
  static const cardBackground = Color(0xEF0F172A);
  static const textColor = Color(0xFFF7FAFC);
  static const secondaryTextColor = Color(0xFF94A3B8);

  final _codeController = TextEditingController();
  final _authService = AuthService();

  bool _useRecovery = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final value = _codeController.text.trim();
    if (value.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _authService.loginTwoFactor(
        desafio: widget.desafio,
        code: _useRecovery ? null : value,
        recoveryCode: _useRecovery ? value : null,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _useRecovery = !_useRecovery;
      _codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accentCyan.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Verificación en dos pasos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _useRecovery
                      ? 'Escribe uno de tus códigos de recuperación.'
                      : 'Escribe el código de 6 dígitos de tu app '
                          'autenticadora.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: secondaryTextColor),
                ),
                const SizedBox(height: 30),
                TextField(
                  key: ValueKey(_useRecovery),
                  controller: _codeController,
                  autofocus: true,
                  enabled: !_isLoading,
                  keyboardType: _useRecovery
                      ? TextInputType.visiblePassword
                      : TextInputType.number,
                  inputFormatters: _useRecovery
                      ? null
                      : [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                  autofillHints: _useRecovery
                      ? null
                      : const [AutofillHints.oneTimeCode],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 20,
                    letterSpacing: 4,
                  ),
                  onSubmitted: (_) => _verify(),
                  decoration: InputDecoration(
                    hintText: _useRecovery ? 'xxxxx-xxxxx' : '000000',
                    hintStyle: TextStyle(
                      color: secondaryTextColor.withValues(alpha: 0.4),
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
                const SizedBox(height: 30),
                Container(
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [accentCyan, accentPurple, accentCyan],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verify,
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
                            'VERIFICAR',
                            style: TextStyle(
                              color: backgroundColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading ? null : _toggleMode,
                  child: Text(
                    _useRecovery
                        ? 'Usar el código de la app'
                        : 'Usar un código de recuperación',
                    style: const TextStyle(color: accentCyan),
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text(
                    'Volver al login',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
