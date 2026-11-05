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

/// Busca ciudades y lugares con Nominatim (OpenStreetMap). Su política no
/// deja autocompletar: se busca solo cuando el usuario lo pide.
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
