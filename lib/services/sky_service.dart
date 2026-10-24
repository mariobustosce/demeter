import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_client.dart';
import 'location_service.dart';

class SkyService {
  ApiClient get _api => ApiClient.instance;

  Future<Map<String, dynamic>?> getMapApiData({
    double? lat,
    double? lng,
    DateTime? date,
  }) async {
    try {
      final data = await _api.get(
        '/astronomy/map-api-mobile',
        query: await _mapQuery(lat, lng, date),
        timeout: kApiTimeout,
      );
      return data is Map<String, dynamic> ? data : null;
    } catch (e) {
      debugPrint("Error cargando los datos API: $e");
      return null;
    }
  }

  /// Query común de los endpoints del mapa. Sin coordenadas, usa el GPS (solo
  /// si ya hay permiso: el que lo pide, con su explicación, es el mapa) o las
  /// coordenadas por defecto. Van en una URL pública: redondeadas a 2
  /// decimales.
  Future<Map<String, String>> _mapQuery(
    double? lat,
    double? lng,
    DateTime? date,
  ) async {
    var location = lat != null && lng != null ? RoundedLocation(lat, lng) : null;
    location ??= await LocationService.instance.current();
    location ??= RoundedLocation(kDefaultLatitude, kDefaultLongitude);

    final now = date ?? DateTime.now();
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    return {
      'lat': location.latParam,
      'lon': location.lonParam,
      'date': dateStr,
      'time': timeStr,
      '_t': '${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  // --- MÉTODOS DE COMPATIBILIDAD (No borrar, se usan en Consultas) ---

  Future<Map<String, dynamic>?> getCelestialMap({
    double? lat,
    double? lng,
    DateTime? date,
  }) async {
    return getMapApiData(lat: lat, lng: lng, date: date);
  }

  Future<Map<String, dynamic>> getAstralProfile({
    double? lat,
    double? lng,
    DateTime? date,
  }) async {
    final data = await getMapApiData(lat: lat, lng: lng, date: date);
    return data ?? {};
  }

  // --- FIN MÉTODOS DE COMPATIBILIDAD ---

  /// El cielo de ahora como `contexto_completo` del oráculo. Vacío si
  /// `map-api-mobile` no respondió.
  Future<Map<String, dynamic>> getOracleContext() async =>
      oracleContextFrom(await getMapApiData() ?? const {});

  Future<Map<String, double>?> searchLocation(String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '1',
      });

      final response = await http.get(
        uri,
        // La política de Nominatim exige identificar la app con un contacto.
        headers: {'User-Agent': kNominatimUserAgent},
      ).timeout(kRequestTimeout);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return {
            'lat': double.parse(data[0]['lat']),
            'lon': double.parse(data[0]['lon']),
          };
        }
      } else {
        debugPrint("Error buscando ubicación (Status ${response.statusCode})");
      }
    } catch (e) {
      debugPrint("Error buscando ubicación: $e");
    }
    return null;
  }

}

/// Lo que el oráculo recibe del cielo: las mismas claves que arma la web
/// (`contextoAstronomico()` en consultas), que son las de la lista blanca del
/// servidor. Sin coordenadas, clima ni nombre del lugar, que sí vienen en
/// `map-api-mobile`.
Map<String, dynamic> oracleContextFrom(Map<String, dynamic> data) {
  Map<dynamic, dynamic>? map(Object? value) => value is Map ? value : null;
  num? number(Object? value) => value is num ? value : num.tryParse('$value');

  final sunPosition = map(map(data['solar'])?['position']);
  final lunar = map(data['lunar']);

  final visible = <String>[];
  map(map(data['planetas'])?['visibles'])?.forEach((name, planet) {
    final p = map(planet);
    final altitude = number(p?['altitude']) ?? 0;
    final label = '$name';
    if (p != null && label.isNotEmpty && (p['visible'] == true || altitude > 0)) {
      visible.add(label[0].toUpperCase() + label.substring(1));
    }
  });

  // El signo con más potencia, con su nombre si lo trae.
  String? dominantSign;
  final zodiac = map(data['zodiaco']);
  MapEntry<dynamic, dynamic>? strongest;
  map(zodiac?['potencias'])?.forEach((sign, power) {
    final value = number(power);
    if (value != null && (strongest == null || value > number(strongest!.value)!)) {
      strongest = MapEntry(sign, value);
    }
  });
  if (strongest != null) {
    final sign = '${strongest!.key}';
    dominantSign = map(map(zodiac?['horarios'])?[sign])?['nombre']?.toString() ?? sign;
  }

  final illumination =
      number(lunar?['illumination_percent']) ?? number(lunar?['phase']) ?? 0;

  return {
    'momento': data['timestamp'],
    'hemisferio': data['hemisferio'],
    'estacion': map(data['arcos'])?['season'],
    'sol': {
      'visible': (number(sunPosition?['altitude']) ?? 0) > 0,
      'constelacion': sunPosition?['constellation'],
    },
    'luna': {
      'fase': lunar?['phase_name'],
      'iluminacion': illumination.round(),
    },
    'planetas_visibles': visible,
    'zodiaco_dominante': dominantSign,
    'casa_dominante': map(data['casas'])?['dominant_house'],
  }..removeWhere((_, value) => value == null);
}
