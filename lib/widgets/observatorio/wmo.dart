import 'package:flutter/material.dart';

/// Icono de Material para un código WMO de Open-Meteo, de día o de noche.
/// Sin assets nuevos.
IconData iconoWmo(int? codigo, {bool deDia = true}) {
  switch (codigo) {
    case null:
      return Icons.help_outline;
    case 0:
      return deDia ? Icons.wb_sunny_outlined : Icons.nightlight_outlined;
    case 1:
    case 2:
      return deDia ? Icons.wb_cloudy_outlined : Icons.nights_stay_outlined;
    case 3:
      return Icons.cloud_outlined;
    case 45:
    case 48:
      return Icons.foggy;
    case >= 51 && <= 57:
      return Icons.grain;
    case >= 61 && <= 67:
    case >= 80 && <= 82:
      return Icons.umbrella_outlined;
    case >= 71 && <= 77:
    case 85:
    case 86:
      return Icons.ac_unit;
    case >= 95:
      return Icons.thunderstorm_outlined;
    default:
      return Icons.cloud_outlined;
  }
}
