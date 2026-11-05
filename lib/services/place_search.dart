import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'location_service.dart';

/// Un lugar encontrado: el nombre corto para el mapa y el favorito, y el
/// largo para distinguirlo de otros iguales.
@immutable
class PlaceResult {
  const PlaceResult({required this.name, required this.detail, required this.location});

  final String name;
  final String detail;
  final RoundedLocation location;
}

/// Busca ciudades y lugares en OpenStreetMap. Mientras se escribe, con Photon
/// ([suggest]), que está hecho para autocompletar; al pedirlo, con Nominatim
/// ([search]), cuya política no deja autocompletar. A los dos solo les llega
/// el texto escrito.
class PlaceSearchService {
  PlaceSearchService({http.Client? httpClient}) : _http = httpClient;

  final http.Client? _http;

  /// Hasta 5 lugares, en español. Lista vacía si no hay ninguno; lanza si no
  /// hay red o Nominatim falla.
  Future<List<PlaceResult>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'jsonv2',
      'limit': '5',
      'addressdetails': '0',
      'accept-language': 'es',
    });
    // La política de Nominatim exige identificar la app con un contacto.
    final headers = {'User-Agent': kNominatimUserAgent};
    final client = _http;
    final response = await (client == null
            ? http.get(uri, headers: headers)
            : client.get(uri, headers: headers))
        .timeout(kRequestTimeout);
    if (response.statusCode != 200) {
      throw http.ClientException('Nominatim respondió ${response.statusCode}', uri);
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) return const [];
    final results = <PlaceResult>[];
    for (final item in data) {
      final result = _parse(item);
      // Dos resultados en el mismo km son el mismo lugar para el mapa.
      if (result != null && !results.any((r) => r.location == result.location)) {
        results.add(result);
      }
    }
    return results;
  }

  /// Sugerencias de Photon (komoot) para lo que se va escribiendo: hasta 5,
  /// desde 3 letras. Lanza si no hay red o Photon falla.
  Future<List<PlaceResult>> suggest(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final uri = Uri.https('photon.komoot.io', '/api/', {'q': q, 'limit': '5'});
    final headers = {'User-Agent': kNominatimUserAgent};
    final client = _http;
    final response = await (client == null
            ? http.get(uri, headers: headers)
            : client.get(uri, headers: headers))
        .timeout(kRequestTimeout);
    if (response.statusCode != 200) {
      throw http.ClientException('Photon respondió ${response.statusCode}', uri);
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final features = data is Map ? data['features'] : null;
    if (features is! List) return const [];
    final results = <PlaceResult>[];
    for (final feature in features) {
      final result = _parsePhoton(feature);
      if (result != null && !results.any((r) => r.location == result.location)) {
        results.add(result);
      }
    }
    return results;
  }

  /// Un `Feature` de GeoJSON: `coordinates` va como [lon, lat].
  static PlaceResult? _parsePhoton(Object? feature) {
    if (feature is! Map) return null;
    final geometry = feature['geometry'];
    final props = feature['properties'];
    if (geometry is! Map || props is! Map) return null;
    final coords = geometry['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final lon = coords[0], lat = coords[1];
    if (lat is! num || lon is! num || lat.abs() > 90 || lon.abs() > 180) return null;
    String campo(String k) => props[k] is String ? (props[k] as String).trim() : '';
    final name = campo('name').isNotEmpty ? campo('name') : campo('city');
    if (name.isEmpty) return null;
    final partes = <String>[];
    for (final p in [name, campo('city'), campo('state'), campo('country')]) {
      if (p.isNotEmpty && !partes.contains(p)) partes.add(p);
    }
    return PlaceResult(
      name: name,
      detail: partes.join(', '),
      location: RoundedLocation(lat.toDouble(), lon.toDouble()),
    );
  }

  static PlaceResult? _parse(Object? item) {
    if (item is! Map) return null;
    final lat = double.tryParse('${item['lat']}');
    final lon = double.tryParse('${item['lon']}');
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) return null;
    final detail = '${item['display_name'] ?? ''}'.trim();
    var name = '${item['name'] ?? ''}'.trim();
    if (name.isEmpty) name = detail.split(',').first.trim();
    if (name.isEmpty) return null;
    return PlaceResult(name: name, detail: detail, location: RoundedLocation(lat, lon));
  }
}
