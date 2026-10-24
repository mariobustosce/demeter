import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/map_mode.dart';

const _accentCyan = Color(0xFF4FD0E7);
const _cardBackground = Color(0xEF0F172A);
const _textColor = Color(0xFFF7FAFC);

const String _kModeKey = 'mapa_modo';

/// El último modo elegido, o básico.
Future<MapMode> loadMapMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return MapMode.fromName(prefs.getString(_kModeKey));
  } catch (_) {
    return MapMode.basico;
  }
}

Future<void> saveMapMode(MapMode mode) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModeKey, mode.name);
  } catch (_) {}
}

/// Selector nativo del modo del mapa.
class MapModeMenu extends StatelessWidget {
  const MapModeMenu({super.key, required this.mode, required this.onChanged});

  final MapMode mode;
  final ValueChanged<MapMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MapMode>(
      tooltip: 'Modo del mapa',
      initialValue: mode,
      onSelected: onChanged,
      color: _cardBackground,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final m in MapMode.values)
          CheckedPopupMenuItem(
            value: m,
            checked: m == mode,
            child: Text(m.label, style: const TextStyle(color: _textColor)),
          ),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _accentCyan.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.layers_outlined, color: _accentCyan, size: 16),
            const SizedBox(width: 6),
            Text(
              mode.label,
              style: const TextStyle(
                color: _textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: _textColor, size: 18),
          ],
        ),
      ),
    );
  }
}
