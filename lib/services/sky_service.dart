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

  Future<Map<String, dynamic>?> getCelestialMap({double? lat, double? lng, DateTime? date}) async {
    try {
      final token = await _authService.getToken();
      
      double latitude = lat ?? -34.6037;
      double longitude = lng ?? -58.3816;

      if (lat == null || lng == null) {
        Position? position = await _determinePosition();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
        }
      }
      
      final now = date ?? DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      final queryParams = {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'date': dateStr,
        'time': timeStr,
      };

      final uri = Uri.parse('$_baseUrl/astronomy/map-svg').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 45)); // Tiempo extendido para el pesado SVG

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("Error obteniendo SVG (Status ${response.statusCode})");
        return null;
      }
    } catch (e) {
      print("Error cargando el oráculo: $e");
      return null;
    }
  }

  Future<Map<String, double>?> searchLocation(String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '1',
      });
      
      final response = await http.get(uri, headers: {
        'User-Agent': 'DemeterApp/1.0', // Nominatim requiere User-Agent
      });
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
           return {
             'lat': double.parse(data[0]['lat']),
             'lon': double.parse(data[0]['lon']),
           };
        }
      } else {
        print("Error buscando ubicación (Status ${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("Error buscando ubicación: $e");
    }
    return null;
  }

  // Método para obtener datos unificados desde el backend (Laravel)
  Future<Map<String, dynamic>> getAstralProfile({double? lat, double? lng, DateTime? date}) async {
    try {
      final token = await _authService.getToken();
      
      double latitude = lat ?? -34.6037;
      double longitude = lng ?? -58.3816;

      if (lat == null || lng == null) {
        Position? position = await _determinePosition();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
        }
      }
      
      print("Consultando AstralProfile unificado: Lat $latitude, Lon $longitude");

      final targetDate = date ?? DateTime.now();
      final dateStr = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";
      final timeStr = "${targetDate.hour.toString().padLeft(2, '0')}:${targetDate.minute.toString().padLeft(2, '0')}";

      final queryParams = {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'date': dateStr,
        'time': timeStr,
      };

      // Si /astronomy/data dio 404, prueba con /astronomy/profile o verifica tu api.php
      final uri = Uri.parse('$_baseUrl/astronomy/data').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("Error en AstralProfile unificado (Status ${response.statusCode})");
        // Si el servidor falla, devolvemos mock local para no dejar la pantalla vacía
        return {
          'physics': _getMockPhysicsData(targetDate),
          'planetary': _getMockPlanetaryData(targetDate),
          'astrology': _generateMockAstroData(targetDate),
          'is_mock_data': true
        };
      }
    } catch (e) {
      print("Error cargando perfil astral unificado: $e");
      return {};
    }
  }

  Map<String, dynamic> _getMockPhysicsData(DateTime now) {
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    return {
      "daily": {
        "sunrise": ["${dateStr}T06:45"],
        "sunset": ["${dateStr}T19:30"],
        "daylight_duration": [45900.0],
        "uv_index_max": [6.5]
      },
      "extended": _generateExtendedPhysicsData(now)
    };
  }

  // Genera datos astronómicos extendidos basados matemáticamente en la fecha
  Map<String, dynamic> _generateExtendedPhysicsData(DateTime date) {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    // Cálculo aproximado de fase lunar basado en un ciclo de 29.53 días
    // Época conocida: Luna Nueva 11 Enero 2024 11:57 UTC
    final epoch = DateTime.utc(2024, 1, 11, 11, 57);
    final daysSinceEpoch = date.difference(epoch).inDays;
    final phaseVal = (daysSinceEpoch % 29.53) / 29.53;
    
    // Edad de la luna en días
    final moonAge = phaseVal * 29.53;

    // Estación del año (Aproximación Hemisferio Norte, luego se puede ajustar por latitud)
    String season = "Invierno";
    if (date.month >= 3 && date.month <= 5) season = "Primavera";
    if (date.month >= 6 && date.month <= 8) season = "Verano";
    if (date.month >= 9 && date.month <= 11) season = "Otoño";
    if (date.month == 3 && date.day < 21) season = "Invierno";
    if (date.month == 6 && date.day < 21) season = "Primavera";
    if (date.month == 9 && date.day < 22) season = "Verano";
    if (date.month == 12 && date.day < 21) season = "Otoño";

    return {
      "moonrise": "${dateStr}T${(18 + (date.day * 0.8) % 6).toInt().toString().padLeft(2, '0')}:15",
      "moonset": "${dateStr}T${(5 + (date.day * 0.8) % 6).toInt().toString().padLeft(2, '0')}:20",
      "moon_phase": phaseVal,
      "moon_age_days": double.parse(moonAge.toStringAsFixed(1)),
      "season": season,
      "solar_noon": "${dateStr}T13:15",
      "twilight_civil_start": "${dateStr}T06:15",
      "twilight_civil_end": "${dateStr}T20:00",
      "distance_to_earth_km": 384400 + (math.sin(phaseVal * math.pi * 2) * 20000), // Variación sinusal
    };
  }

  // Datos simulados en caso de fallo de API para garantizar UI
  Map<String, dynamic> _getMockPlanetaryData(DateTime now) {
    final dateIso = now.toIso8601String();
    return {
      "data": {
        "table": {
          "rows": [
            {
              "cells": [
                {
                  "name": "Mercurio",
                  "extra": {
                    "is_visible": true,
                    "rise": dateIso,
                    "set": now.add(const Duration(hours: 4)).toIso8601String()
                  }
                }
              ]
            },
            {
              "cells": [
                {
                  "name": "Venus",
                  "extra": {
                    "is_visible": true,
                    "rise": dateIso,
                    "set": now.add(const Duration(hours: 6)).toIso8601String()
                  }
                }
              ]
            },
            {
              "cells": [
                {
                  "name": "Marte",
                  "extra": {
                    "is_visible": false,
                    "rise": now.add(const Duration(hours: 12)).toIso8601String(),
                    "set": now.add(const Duration(hours: 20)).toIso8601String()
                  }
                }
              ]
            },
            {
              "cells": [
                {
                  "name": "Júpiter",
                  "extra": {
                    "is_visible": true,
                    "rise": dateIso,
                    "set": now.add(const Duration(hours: 8)).toIso8601String()
                  }
                }
              ]
            },
            {
              "cells": [
                {
                  "name": "Saturno",
                  "extra": {
                    "is_visible": false,
                    "rise": now.add(const Duration(hours: 14)).toIso8601String(),
                    "set": dateIso
                  }
                }
              ]
            },
            {
              "cells": [
                {
                  "name": "Urano",
                  "extra": {
                    "is_visible": true,
                    "rise": dateIso,
                    "set": now.add(const Duration(hours: 9)).toIso8601String()
                  }
                }
              ]
            },
            {
              "cells": [
                {
                  "name": "Neptuno",
                  "extra": {
                    "is_visible": false,
                    "rise": now.add(const Duration(hours: 16)).toIso8601String(),
                    "set": now.add(const Duration(hours: 22)).toIso8601String()
                  }
                }
              ]
            },
            {
              "cells": [
                {
                  "name": "Plutón",
                  "extra": {
                    "is_visible": false,
                    "rise": now.add(const Duration(hours: 18)).toIso8601String(),
                    "set": now.add(const Duration(hours: 23)).toIso8601String()
                  }
                }
              ]
            }
          ]
        }
      }
    };
  }

  Map<String, dynamic> _generateMockAstroData(DateTime date) {
    // Calculamos un índice basado en la fecha para que los datos cambien
    // Esto es temporal hasta que conectemos con el backend real (AstroAPI)
    final day = date.day;
    final signs = [
      'Aries', 'Tauro', 'Géminis', 'Cáncer', 'Leo', 'Virgo', 
      'Libra', 'Escorpio', 'Sagitario', 'Capricornio', 'Acuario', 'Piscis'
    ];
    
    // Generar combinaciones deterministas basadas en la fecha seleccionada
    final sunSign = signs[day % 12];
    final moonSign = signs[(day + 5) % 12];
    final ascSign = signs[(day + 8) % 12];

    return {
      'big_three': {
        'sun': sunSign, 
        'moon': moonSign,
        'ascendant': ascSign
      },
      'planets': [
        {'name': 'Mercurio', 'sign': signs[(day + 1) % 12], 'deg': '${(day * 7) % 30}°'},
        {'name': 'Venus', 'sign': signs[(day + 2) % 12], 'deg': '${(day * 3) % 30}°'},
        {'name': 'Marte', 'sign': signs[(day + 4) % 12], 'deg': '${(day * 9) % 30}°'},
      ],
      'houses': {
        'C1': 'Signo: $ascSign',
        'C10': 'Signo: ${signs[(day + 3) % 12]}'
      },
      'aspects': [
        {'planet1': 'Sol', 'planet2': 'Luna', 'type': day % 2 == 0 ? 'Trígono' : 'Cuadratura'},
        {'planet1': 'Marte', 'planet2': 'Saturno', 'type': 'Oposición'}
      ]
    };
  }
}

