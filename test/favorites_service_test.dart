import 'dart:convert';

import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/favorites_service.dart';
import 'package:demeter/services/location_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

void main() {
  late List<http.Request> requests;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    requests = [];
  });

  FavoritesService serviceWith(int status, Object body) => FavoritesService(
        api: ApiClient(
          baseUrl: 'https://windowsdemeter.com/api',
          httpClient: MockClient((req) async {
            requests.add(req);
            return http.Response(jsonEncode(body), status, headers: _json);
          }),
        ),
      );

  Map<String, dynamic> sent() => jsonDecode(requests.single.body) as Map<String, dynamic>;

  test('lista en el orden del servidor y sin leer las coordenadas', () async {
    final service = serviceWith(200, {
      'success': true,
      'favoritos': [
        {'id': 3, 'titulo': 'Casa', 'lat': -33.45, 'lon': -70.65, 'paisaje_id': null, 'ajustes': []},
        {'id': 9, 'titulo': '  ', 'lat': 1, 'lon': 2, 'ajustes': {}},
        {'titulo': 'Sin id'},
      ],
    });

    final favorites = await service.list();

    expect([for (final f in favorites) (f.id, f.title)], [(3, 'Casa'), (9, 'Mi lugar')]);
    expect(requests.single.headers['Authorization'], 'Bearer tok-1');
  });

  test('guarda «Mi ubicación» con 2 decimales en el body, no en la URL', () async {
    final service = serviceWith(201, {
      'success': true,
      'existente': false,
      'favorito': {'id': 12, 'titulo': 'La Florida', 'lat': -33.46, 'lon': -70.65},
    });

    final saved = await service.save(RoundedLocation(-33.456789, -70.648123));

    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/favoritos');
    expect(request.url.query, isEmpty);
    expect(sent(), {'lat': -33.46, 'lon': -70.65});
    expect(saved.favorite.id, 12);
    expect(saved.favorite.title, 'La Florida');
    expect(saved.existing, isFalse);
  });

  test('si el punto ya estaba, avisa que existía', () async {
    final service = serviceWith(200, {
      'success': true,
      'existente': true,
      'favorito': {'id': 4, 'titulo': 'Casa'},
    });

    final saved = await service.save(RoundedLocation(-33.46, -70.65));

    expect(saved.existing, isTrue);
    expect(saved.favorite.id, 4);
  });

  test('el tope de favoritos llega con el mensaje del servidor', () async {
    const message = 'Ya tienes 20 lugares guardados. Quita alguno para añadir otro.';
    final service = serviceWith(422, {'success': false, 'message': message});

    expect(
      () => service.save(RoundedLocation(-33.46, -70.65)),
      throwsA(isA<ValidationException>().having((e) => e.message, 'message', message)),
    );
  });

  test('renombra, borra y cambia el paisaje con las rutas del contrato', () async {
    final service = serviceWith(200, {
      'success': true,
      'favorito': {'id': 5, 'titulo': 'Cabaña'},
      'paisaje': 'castillo-wulff',
    });

    final renamed = await service.rename(5, 'Cabaña');
    expect(renamed.title, 'Cabaña');
    expect(requests.last.method, 'PATCH');
    expect(requests.last.url.path, '/api/favoritos/5');
    expect(jsonDecode(requests.last.body), {'titulo': 'Cabaña'});

    await service.delete(5);
    expect(requests.last.method, 'DELETE');
    expect(requests.last.url.path, '/api/favoritos/5');

    expect(await service.landscapeOf(5), 'castillo-wulff');
    expect(requests.last.method, 'GET');
    expect(requests.last.url.path, '/api/favoritos/5/paisaje');

    expect(await service.setLandscape(5, 'castillo-wulff'), 'castillo-wulff');
    expect(requests.last.method, 'PATCH');
    expect(requests.last.url.path, '/api/favoritos/5/paisaje');
    expect(jsonDecode(requests.last.body), {'paisaje': 'castillo-wulff'});
  });

  test('volver al de siempre manda paisaje null', () async {
    final service = serviceWith(200, {'success': true, 'favorito': {'id': 5}, 'paisaje': null});

    expect(await service.setLandscape(5, null), isNull);
    expect(sent(), {'paisaje': null});
  });

  test('un 404 o un 403 no muestran el mensaje del servidor', () {
    expect(
      FavoritesService.messageFor(const ApiException('No query results', statusCode: 404)),
      'Ese lugar ya no está en tus favoritos.',
    );
    expect(
      FavoritesService.messageFor(const ApiException('This action is unauthorized.', statusCode: 403)),
      'Ese lugar ya no está en tus favoritos.',
    );
    expect(
      FavoritesService.messageFor(const ValidationException('Ese paisaje no está disponible.', {})),
      'Ese paisaje no está disponible.',
    );
  });
}
