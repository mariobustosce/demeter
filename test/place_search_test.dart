import 'dart:convert';

import 'package:demeter/services/place_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('busca en Nominatim, en español, y deja 2 decimales', () async {
    late http.Request sent;
    final search = PlaceSearchService(
      httpClient: MockClient((req) async {
        sent = req;
        return http.Response(
          jsonEncode([
            {'name': 'Valparaíso', 'display_name': 'Valparaíso, Chile', 'lat': '-33.0472', 'lon': '-71.6127'},
            // El mismo km: sobra.
            {'name': 'Valparaíso', 'display_name': 'Valparaíso, Región de Valparaíso', 'lat': '-33.0469', 'lon': '-71.6131'},
            {'name': '', 'display_name': 'Valparaíso, Zacatecas, México', 'lat': '22.77', 'lon': '-103.57'},
            {'name': 'Roto', 'lat': 'x', 'lon': '1'},
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final results = await search.search('  Valparaíso ');

    expect(sent.url.host, 'nominatim.openstreetmap.org');
    expect(sent.url.queryParameters['q'], 'Valparaíso');
    expect(sent.url.queryParameters['accept-language'], 'es');
    expect(sent.headers['User-Agent'], contains('windowsdemeter.com'));
    expect([for (final r in results) r.name], ['Valparaíso', 'Valparaíso']);
    expect(results.first.location.latParam, '-33.05');
    expect(results.first.location.lonParam, '-71.61');
    expect(results.last.detail, 'Valparaíso, Zacatecas, México');
  });

  test('una búsqueda de una letra no sale a la red', () async {
    var calls = 0;
    final search = PlaceSearchService(
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('[]', 200);
      }),
    );

    expect(await search.search('a'), isEmpty);
    expect(calls, 0);
  });

  test('si Nominatim falla, lanza', () async {
    final search = PlaceSearchService(
      httpClient: MockClient((_) async => http.Response('', 503)),
    );

    expect(search.search('Lima'), throwsA(isA<http.ClientException>()));
  });
}
