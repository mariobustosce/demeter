import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/location_service.dart';

const _accentCyan = Color(0xFF4FD0E7);
const _cardBackground = Color(0xFF0F172A);
const _textColor = Color(0xFFF7FAFC);
const _secondaryTextColor = Color(0xFF94A3B8);

/// Quien respondió «Ahora no» no vuelve a ver la pregunta al abrir el mapa;
/// solo si toca la ubicación.
const String _kDeclinedKey = 'ubicacion_mapa_omitida';

/// La ubicación del teléfono para el mapa, redondeada a 2 decimales.
///
/// Si el permiso no está decidido, primero explica para qué es y solo
/// entonces deja que el sistema lo pida. Con [userAsked] (un toque en «Mi
/// ubicación») pregunta aunque antes dijera que no, y ofrece los ajustes si
/// el permiso está bloqueado. `null` sin permiso o sin GPS: el mapa se carga
/// sin lat/lon.
Future<RoundedLocation?> mapLocation(
  BuildContext context, {
  bool userAsked = false,
}) async {
  final service = LocationService.instance;

  switch (await service.access()) {
    case LocationAccess.granted:
      break;

    case LocationAccess.askable:
      final prefs = await SharedPreferences.getInstance();
      if (!userAsked && (prefs.getBool(_kDeclinedKey) ?? false)) return null;
      if (!context.mounted) return null;
      if (await _explain(context) != true) {
        await prefs.setBool(_kDeclinedKey, true);
        return null;
      }
      await prefs.remove(_kDeclinedKey);
      if (!await service.request()) return null;

    case LocationAccess.blocked:
      if (userAsked && context.mounted) {
        _offerSettings(
          context,
          'El permiso de ubicación está desactivado para la app.',
          service.openAppSettings,
        );
      }
      return null;

    case LocationAccess.serviceOff:
      if (userAsked && context.mounted) {
        _offerSettings(
          context,
          'La ubicación del teléfono está apagada.',
          service.openLocationSettings,
        );
      }
      return null;
  }

  return service.current();
}

Future<bool?> _explain(BuildContext context) => showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardBackground,
        icon: const Icon(Icons.my_location_rounded, color: _accentCyan),
        title: const Text(
          'Tu cielo, desde donde estás',
          style: TextStyle(color: _textColor, fontSize: 18),
        ),
        content: const Text(
          'Para dibujar el cielo de tu zona usamos tu ubicación aproximada: '
          'se envía redondeada a unos 1 km y solo para el mapa.\n\n'
          'Si prefieres no compartirla, verás el cielo de una ubicación '
          'aproximada según tu conexión.',
          style: TextStyle(color: _secondaryTextColor, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ahora no', style: TextStyle(color: _secondaryTextColor)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: _accentCyan,
              foregroundColor: _cardBackground,
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

void _offerSettings(
  BuildContext context,
  String message,
  Future<void> Function() open,
) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(label: 'Ajustes', onPressed: open),
    ),
  );
}
