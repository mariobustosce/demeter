import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/referral_payload.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import 'store_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  User? _user;
  ReferralPayload? _referralPayload;

  // Controllers para Datos Personales
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Controllers para Contraseña
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Controller para Eliminar Cuenta
  final TextEditingController _deletePasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final user = await _profileService.getProfile();
    final referralPayload = await _profileService.getReferralPayload();
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
    }
    setState(() {
      _user = user;
      _referralPayload = referralPayload;
      _isLoading = false;
    });
  }

  Future<void> _updateProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nombre y Email son obligatorios.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await _profileService.updateProfile(name, email);
    setState(() => _isLoading = false);

    if (success) {
      await _loadProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Perfil actualizado con éxito.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al actualizar perfil.")),
      );
    }
  }

  Future<void> _openStore() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StoreScreen()),
    );

    if (mounted) {
      await _loadProfile();
    }
  }

  Future<void> _copyText(String text, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  }

  Future<void> _updatePassword() async {
    final current = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La contraseña nueva no coincide con la confirmación."),
        ),
      );
      return;
    }

    if (newPass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La contraseña debe tener al menos 8 caracteres."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await _profileService.updatePassword(
      current,
      newPass,
      confirm,
    );
    setState(() => _isLoading = false);

    if (result['success']) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            "Contraseña Actualizada",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "Tu contraseña ha sido cambiada y todos tus otros dispositivos han sido desconectados. Por favor, inicia sesión nuevamente.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _authService.logout();
                if (mounted) Navigator.pushReplacementNamed(context, "/login");
              },
              child: const Text(
                "Entendido",
                style: TextStyle(color: Color(0xFF4FD0E7)),
              ),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'])));
    }
  }

  Future<void> _confirmDeleteAccount() async {
    _deletePasswordController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Eliminar Cuenta",
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Esta acción es irreversible y eliminará todos tus datos. Ingresa tu contraseña para confirmar.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deletePasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Contraseña",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Cierra diálogo
              setState(() => _isLoading = true);
              final success = await _profileService.deleteAccount(
                _deletePasswordController.text,
              );
              setState(() => _isLoading = false);

              if (success) {
                await _authService.logout();
                if (mounted) Navigator.pushReplacementNamed(context, "/login");
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Error al eliminar la cuenta. Verifica tu contraseña.",
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text(
              "Eliminar definitivamente",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // Helper para crear TextFields oscuros
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF4FD0E7)),
          filled: true,
          fillColor: const Color(0xFF0F172A).withOpacity(0.5),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: const Color(0xFF4FD0E7).withOpacity(0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4FD0E7)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF020617);
    const cardColor = Color(0xFF1E293B);
    const accentCyan = Color(0xFF4FD0E7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Mi Perfil",
          style: TextStyle(
            color: accentCyan,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: accentCyan),
        actions: [
          IconButton(
            tooltip: 'Comprar Polvo Estelar',
            onPressed: _openStore,
            icon: const Icon(Icons.storefront_rounded, color: accentCyan),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentCyan))
          : _user == null
          ? const Center(
              child: Text(
                "Error al cargar perfil.",
                style: TextStyle(color: Colors.white54),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentCyan.withOpacity(0.18),
                          const Color(0xFF7C3AED).withOpacity(0.22),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_user?.celestialCoins ?? 0} Polvo Estelar',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _referralPayload == null
                              ? 'Tu saldo se actualiza aquí después de cada compra aprobada.'
                              : 'Código ${_referralPayload!.referralCode} • Bono amigo ${_referralPayload!.welcomeBonusForFriend} ✨',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _openStore,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                ),
                                icon: const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: bgColor,
                                ),
                                label: const Text(
                                  'Comprar',
                                  style: TextStyle(
                                    color: bgColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _referralPayload == null
                                    ? null
                                    : () => _copyText(
                                        _referralPayload!.shareMessage,
                                        'Mensaje de referido copiado.',
                                      ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.copy_all_rounded,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Copiar referido',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Sección: Datos Personales ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accentCyan.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person, color: accentCyan, size: 20),
                            SizedBox(width: 10),
                            Text(
                              "Datos Personales",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildTextField("Nombre", _nameController),
                        _buildTextField("Email", _emailController),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentCyan,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _updateProfile,
                            child: const Text(
                              "Actualizar Perfil",
                              style: TextStyle(
                                color: bgColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_referralPayload != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: accentCyan.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.card_giftcard,
                                color: accentCyan,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Referidos',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _referralPayload!.referralCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _referralPayload!.shareMessage,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Ganas ${_referralPayload!.rewardPerReferral} ✨ por referido. Tu amigo recibe ${_referralPayload!.welcomeBonusForFriend} ✨.',
                            style: const TextStyle(
                              color: accentCyan,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // --- Sección: Cambiar Contraseña ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accentCyan.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock, color: accentCyan, size: 20),
                            SizedBox(width: 10),
                            Text(
                              "Seguridad",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _user?.hasPassword == false
                              ? 'Tu cuenta viene desde Google. Puedes crear una contraseña aquí si lo deseas.'
                              : 'Si te registraste con Google, podrías no necesitar contraseña actual.',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          "Contraseña Actual",
                          _currentPasswordController,
                          isPassword: true,
                        ),
                        _buildTextField(
                          "Nueva Contraseña",
                          _newPasswordController,
                          isPassword: true,
                        ),
                        _buildTextField(
                          "Confirmar Nueva Contraseña",
                          _confirmPasswordController,
                          isPassword: true,
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              side: const BorderSide(color: accentCyan),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _updatePassword,
                            child: const Text(
                              "Cambiar Contraseña",
                              style: TextStyle(
                                color: accentCyan,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Sección: Eliminar Cuenta ---
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        "Eliminar cuenta permanentemente",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      onPressed: _confirmDeleteAccount,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
