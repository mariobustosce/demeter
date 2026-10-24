import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../config/app_config.dart';

/// Coordenadas redondeadas a 2 decimales (unos 1 km). Son las únicas que salen
/// de este servicio, porque viajan en URLs públicas.
@immutable
class RoundedLocation {
  RoundedLocation(double lat, double lon)
      : lat = _round(lat),
        lon = _round(lon);

  final double lat;
  final double lon;

  static double _round(double value) => (value * 100).roundToDouble() / 100;

  String get latParam => lat.toStringAsFixed(2);
  String get lonParam => lon.toStringAsFixed(2);

  @override
  bool operator ==(Object other) =>
      other is RoundedLocation && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);
}

enum LocationAccess {
  granted,

  /// Todavía se puede pedir el permiso.
  askable,

  /// Denegado para siempre: solo se cambia desde los ajustes.
  blocked,

  /// El GPS del teléfono está apagado.
  serviceOff,
}

/// Ubicación del teléfono para el mapa.
class LocationService {
  /// Instancia que usa la app. Los tests pueden reemplazarla.
  static LocationService instance = LocationService();

  /// Una posición de hace menos que esto sirve igual con 2 decimales.
  static const Duration _maxAge = Duration(minutes: 10);

  /// El estado del permiso, sin pedir nada.
  Future<LocationAccess> access() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationAccess.serviceOff;
      }
      return switch (await Geolocator.checkPermission()) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          LocationAccess.granted,
        LocationPermission.denied => LocationAccess.askable,
        _ => LocationAccess.blocked,
      };
    } catch (e) {
      debugPrint('Ubicación no disponible (${e.runtimeType}).');
      return LocationAccess.blocked;
    }
  }

  /// Pide el permiso al sistema. `true` si lo concedió.
  Future<bool> request() async {
    try {
      final permission = await Geolocator.requestPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('No se pudo pedir la ubicación (${e.runtimeType}).');
      return false;
    }
  }

  /// La posición actual, o `null` sin permiso o si el GPS no responde a
  /// tiempo. No pide el permiso.
  Future<RoundedLocation?> current() async {
    if (await access() != LocationAccess.granted) return null;
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && DateTime.now().difference(last.timestamp) < _maxAge) {
        return RoundedLocation(last.latitude, last.longitude);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: kLocationTimeout,
        ),
      );
      return RoundedLocation(position.latitude, position.longitude);
    } catch (e) {
      // Sin coordenadas el servidor usa la IP o la ubicación por defecto.
      debugPrint('GPS no disponible a tiempo (${e.runtimeType}).');
      return null;
    }
  }

  Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }

  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {}
  }
}
