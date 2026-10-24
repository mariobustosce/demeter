import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/map_mode.dart';
import '../services/location_service.dart';
import '../services/map_urls.dart';
import '../widgets/location_prompt.dart';
import '../widgets/map_mode_menu.dart';
import '../widgets/map_web_view.dart';

const _accentCyan = Color(0xFF4FD0E7);
const _accentPurple = Color(0xFF8B5CF6);
const _cardBackground = Color(0xFF0F172A);
const _textColor = Color(0xFFF7FAFC);
const _secondaryTextColor = Color(0xFF94A3B8);

/// Quien abre la app sin sesión: el mapa animado, como en la portada web, y
/// la invitación a entrar al portal.
class GuestMapScreen extends StatefulWidget {
  const GuestMapScreen({super.key});

  @visibleForTesting
  static void resetInvite() => _GuestMapScreenState._invited = false;

  @override
  State<GuestMapScreen> createState() => _GuestMapScreenState();
}

class _GuestMapScreenState extends State<GuestMapScreen> {
  // La hoja de invitación sube una vez por apertura de la app: volver aquí
  // tras cerrar sesión no la repite.
  static bool _invited = false;

  MapMode _mode = MapMode.basico;
  RoundedLocation? _location;
  bool _ready = false;
  Timer? _inviteTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _inviteTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final mode = await loadMapMode();
    if (!mounted) return;
    final location = await mapLocation(context);
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _location = location;
      _ready = true;
    });
    if (!_invited) _inviteTimer = Timer(kGuestInviteDelay, _invite);
  }

  Future<void> _useMyLocation() async {
    final location = await mapLocation(context, userAsked: true);
    if (mounted && location != null) setState(() => _location = location);
  }

  void _setMode(MapMode mode) {
    setState(() => _mode = mode);
    saveMapMode(mode);
  }

  Future<Uri> _buildUrl(double ratio, {bool renew = false}) async =>
      MapUrls.guest(_mode, location: _location, ratio: ratio);

  void _invite() {
    // No tapa el login ni un diálogo que esté encima.
    if (!mounted || _invited || ModalRoute.of(context)?.isCurrent != true) return;
    _invited = true;
    showModalBottomSheet<void>(
      context: context,
      // Crece con su contenido (letra grande, pantalla apaisada) y si no cabe,
      // se desplaza.
      isScrollControlled: true,
      backgroundColor: _cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _InviteSheet(
        onLogin: () {
          Navigator.pop(sheetContext);
          _openLogin();
        },
        onRegister: () {
          Navigator.pop(sheetContext);
          Navigator.pushNamed(context, '/register');
        },
      ),
    );
  }

  void _openLogin() => Navigator.pushNamed(context, '/login');

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kSkyColor,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'WindowsDemeter',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (_ready && _location == null)
                      IconButton(
                        onPressed: _useMyLocation,
                        tooltip: 'Usar mi ubicación',
                        icon: const Icon(Icons.my_location_rounded, color: _accentCyan),
                      ),
                    MapModeMenu(mode: _mode, onChanged: _setMode),
                  ],
                ),
              ),
              Expanded(
                child: MapWebView(
                  target: _ready ? (_mode, _location) : null,
                  buildUrl: _buildUrl,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _openLogin,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text(
                      'Entrar al portal',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accentCyan,
                      foregroundColor: kSkyColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteSheet extends StatelessWidget {
  const _InviteSheet({required this.onLogin, required this.onRegister});

  final VoidCallback onLogin;
  final VoidCallback onRegister;

  static const _benefits = [
    (Icons.star_rounded, 'Guarda tus lugares favoritos'),
    (Icons.landscape_rounded, 'Elige un paisaje para cada lugar'),
    (Icons.notifications_active_rounded, 'Recibe alertas del clima y del cielo'),
    (Icons.auto_awesome_rounded, 'Consulta al oráculo con tu carta astral'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tu ventana al cielo, a tu manera',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            for (final (icon, text) in _benefits)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(icon, color: _accentPurple, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(text, style: const TextStyle(color: _secondaryTextColor, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onLogin,
              style: FilledButton.styleFrom(
                backgroundColor: _accentCyan,
                foregroundColor: kSkyColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Entrar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onRegister,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accentCyan,
                side: BorderSide(color: _accentCyan.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Crear cuenta'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no', style: TextStyle(color: _secondaryTextColor)),
            ),
          ],
        ),
      ),
    );
  }
}
