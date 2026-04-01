import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'auth_service.dart';

class SkyService {
  final String _baseUrl = "https://windowsdemeter.com/api";
  final AuthService _authService = AuthService();

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  Future<Map<String, dynamic>?> getMapApiData({
    double? lat,
    double? lng,
    DateTime? date,
  }) async {
    try {
      final token = await _authService.getToken();

      // Santiago, La Florida, Chile por defecto (Hemisferio Sur)
      double latitude = lat ?? -33.5227;
      double longitude = lng ?? -70.5983;

      if (lat == null || lng == null) {
        Position? position = await _determinePosition();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
        }
      }

      final now = date ?? DateTime.now();
      final dateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final timeStr =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      final queryParams = {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'date': dateStr,
        'time': timeStr,
      };

      final uri = Uri.parse(
        '$_baseUrl/astronomy/map-api-mobile',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("Error obteniendo datos API (Status ${response.statusCode})");
        return null;
      }
    } catch (e) {
      print("Error cargando los datos API: $e");
      return null;
    }
  }

  // --- MÉTODOS DE COMPATIBILIDAD (No borrar, se usan en Background y Consultas) ---

  Future<String?> getMapSvgMobile({
    double? lat,
    double? lng,
    DateTime? date,
  }) async {
    try {
      final token = await _authService.getToken();

      // Santiago, La Florida, Chile por defecto (Hemisferio Sur)
      double latitude = lat ?? -33.5227;
      double longitude = lng ?? -70.5983;

      if (lat == null || lng == null) {
        Position? position = await _determinePosition();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
        }
      }

      final now = date ?? DateTime.now();
      final dateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final timeStr =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      final queryParams = {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'date': dateStr,
        'time': timeStr,
      };

      final uri = Uri.parse(
        '$_baseUrl/astronomy/map-svg-mobile',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic> && decoded.containsKey('svg')) {
            return decoded['svg'];
          }
        } catch (_) {
          return response.body;
        }
        return response.body;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

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

  Future<Map<String, double>?> searchLocation(String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '1',
      });

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'DemeterApp/1.0', // Nominatim requiere User-Agent
        },
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return {
            'lat': double.parse(data[0]['lat']),
            'lon': double.parse(data[0]['lon']),
          };
        }
      } else {
        print(
          "Error buscando ubicación (Status ${response.statusCode}): ${response.body}",
        );
      }
    } catch (e) {
      print("Error buscando ubicación: $e");
    }
    return null;
  }



  Map<String, dynamic> _getMockPhysicsData(DateTime now) {
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    return {
      "daily": {
        "sunrise": ["${dateStr}T06:45"],
        "sunset": ["${dateStr}T19:30"],
        "daylight_duration": [45900.0],
        "uv_index_max": [6.5],
      },
      "extended": _generateExtendedPhysicsData(now),
    };
  }

  // Genera datos astronómicos extendidos basados matemáticamente en la fecha
  Map<String, dynamic> _generateExtendedPhysicsData(DateTime date) {
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // Cálculo aproximado de fase lunar basado en un ciclo de 29.53 días
    // Época conocida: Luna Nueva 11 Enero 2024 11:57 UTC
    final epoch = DateTime.utc(2024, 1, 11, 11, 57);
    final daysSinceEpoch = date.difference(epoch).inDays;
    final phaseVal = (daysSinceEpoch % 29.53) / 29.53;

    // Edad de la luna en días
    final moonAge = phaseVal * 29.53;

    // Estación del año (Ajustado para Hemisferio Sur)
    String season = "Verano";
    if (date.month >= 3 && date.month <= 5) season = "Otoño";
    if (date.month >= 6 && date.month <= 8) season = "Invierno";
    if (date.month >= 9 && date.month <= 11) season = "Primavera";
    
    // Ajustes por días de equinoccio/solsticio aproximados
    if (date.month == 3 && date.day < 21) season = "Verano";
    if (date.month == 6 && date.day < 21) season = "Otoño";
    if (date.month == 9 && date.day < 22) season = "Invierno";
    if (date.month == 12 && date.day < 21) season = "Primavera";

    return {
      "moonrise":
          "${dateStr}T${(18 + (date.day * 0.8) % 6).toInt().toString().padLeft(2, '0')}:15",
      "moonset":
          "${dateStr}T${(5 + (date.day * 0.8) % 6).toInt().toString().padLeft(2, '0')}:20",
      "moon_phase": phaseVal,
      "moon_age_days": double.parse(moonAge.toStringAsFixed(1)),
      "season": season,
      "solar_noon": "${dateStr}T13:15",
      "twilight_civil_start": "${dateStr}T06:15",
      "twilight_civil_end": "${dateStr}T20:00",
      "distance_to_earth_km":
          384400 +
          (math.sin(phaseVal * math.pi * 2) * 20000), // Variación sinusal
    };
  }

  // Datos simulados en caso de fallo de API para garantizar UI
  Map<String, dynamic> _getMockPlanetaryData(DateTime now) {
    final dateIso = now.toIso8601String();

    // Función auxiliar para generar posiciones relativas a la hora y mockear datos
    Map<String, dynamic> _mockPos(double baseAlt, double baseAz) {
      // Variar levemente usando el tiempo para que se vea que "actualiza"
      double alt = baseAlt + (now.hour * 2.5) % 15 - 5;
      double az = (baseAz + (now.hour * 15)) % 360;
      return {
        'horizontal': {
          'altitude': {'degrees': double.parse(alt.toStringAsFixed(1))},
          'azimuth': {'degrees': double.parse(az.toStringAsFixed(1))},
        },
      };
    }

    return {
      "data": {
        "table": {
          "rows": [
            {
              "cells": [
                {
                  "name": "Mercurio",
                  "position": _mockPos(15.2, 85.0),
                  "extra": {
                    "is_visible": true,
                    "rise": dateIso,
                    "set": now.add(const Duration(hours: 4)).toIso8601String(),
                  },
                },
              ],
            },
            {
              "cells": [
                {
                  "name": "Venus",
                  "position": _mockPos(42.5, 120.3),
                  "extra": {
                    "is_visible": true,
                    "rise": dateIso,
                    "set": now.add(const Duration(hours: 6)).toIso8601String(),
                  },
                },
              ],
            },
            {
              "cells": [
                {
                  "name": "Marte",
                  "position": _mockPos(-12.0, 210.0),
                  "extra": {
                    "is_visible": false,
                    "rise": now
                        .add(const Duration(hours: 12))
                        .toIso8601String(),
                    "set": now.add(const Duration(hours: 20)).toIso8601String(),
                  },
                },
              ],
            },
            {
              "cells": [
                {
                  "name": "Júpiter",
                  "position": _mockPos(68.1, 275.5),
                  "extra": {
                    "is_visible": true,
                    "rise": dateIso,
                    "set": now.add(const Duration(hours: 8)).toIso8601String(),
                  },
                },
              ],
            },
            {
              "cells": [
                {
                  "name": "Saturno",
                  "position": _mockPos(-5.5, 45.0),
                  "extra": {
                    "is_visible": false,
                    "rise": now
                        .add(const Duration(hours: 14))
                        .toIso8601String(),
                    "set": dateIso,
                  },
                },
              ],
            },
            {
              "cells": [
                {
                  "name": "Urano",
                  "position": _mockPos(18.3, 195.2),
                  "extra": {
                    "is_visible": true,
                    "rise": dateIso,
                    "set": now.add(const Duration(hours: 9)).toIso8601String(),
                  },
                },
              ],
            },
            {
              "cells": [
                {
                  "name": "Neptuno",
                  "position": _mockPos(-25.0, 310.8),
                  "extra": {
                    "is_visible": false,
                    "rise": now
                        .add(const Duration(hours: 16))
                        .toIso8601String(),
                    "set": now.add(const Duration(hours: 22)).toIso8601String(),
                  },
                },
              ],
            },
            {
              "cells": [
                {
                  "name": "Plutón",
                  "position": _mockPos(-40.0, 15.0),
                  "extra": {
                    "is_visible": false,
                    "rise": now
                        .add(const Duration(hours: 18))
                        .toIso8601String(),
                    "set": now.add(const Duration(hours: 23)).toIso8601String(),
                  },
                },
              ],
            },
          ],
        },
      },
    };
  }

  Map<String, dynamic> _generateMockAstroData(DateTime date) {
    // Calculamos un índice basado en la fecha para que los datos cambien
    // Esto es temporal hasta que conectemos con el backend real (AstroAPI)
    final day = date.day;
    final signs = [
      'Aries',
      'Tauro',
      'Géminis',
      'Cáncer',
      'Leo',
      'Virgo',
      'Libra',
      'Escorpio',
      'Sagitario',
      'Capricornio',
      'Acuario',
      'Piscis',
    ];

    // Generar combinaciones deterministas basadas en la fecha seleccionada
    final sunSign = signs[day % 12];
    final moonSign = signs[(day + 5) % 12];
    final ascSign = signs[(day + 8) % 12];

    return {
      'big_three': {'sun': sunSign, 'moon': moonSign, 'ascendant': ascSign},
      'planets': [
        {
          'name': 'Mercurio',
          'sign': signs[(day + 1) % 12],
          'deg': '${(day * 7) % 30}°',
        },
        {
          'name': 'Venus',
          'sign': signs[(day + 2) % 12],
          'deg': '${(day * 3) % 30}°',
        },
        {
          'name': 'Marte',
          'sign': signs[(day + 4) % 12],
          'deg': '${(day * 9) % 30}°',
        },
      ],
      'houses': {
        'C1': 'Signo: $ascSign',
        'C10': 'Signo: ${signs[(day + 3) % 12]}',
      },
      'aspects': [
        {
          'planet1': 'Sol',
          'planet2': 'Luna',
          'type': day % 2 == 0 ? 'Trígono' : 'Cuadratura',
        },
        {'planet1': 'Marte', 'planet2': 'Saturno', 'type': 'Oposición'},
      ],
    };
  }
}
