import 'dart:async';
import 'dart:convert';

import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<Duration> waits;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    waits = [];
  });

  ApiClient clientWith(MockClientHandler handler) => ApiClient(
        httpClient: MockClient(handler),
        baseUrl: 'https://api.test/api/',
        sleep: (d) async => waits.add(d),
      );

  http.Response jsonResponse(
    Object body,
    int status, {
    Map<String, String> headers = const {},
  }) =>
      http.Response(jsonEncode(body), status, headers: headers);

  test('arma la URL, manda el token y decodifica el JSON', () async {
    late http.Request seen;
    final api = clientWith((req) async {
      seen = req;
      return jsonResponse({'ok': true}, 200);
    });

    final data = await api.post('/charts', body: {'a': 1});

    expect(data, {'ok': true});
    expect(seen.url.toString(), 'https://api.test/api/charts');
    expect(seen.headers['Authorization'], 'Bearer tok-1');
    expect(seen.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(seen.body), {'a': 1});
  });

  test('auth: false no manda el token', () async {
    late http.Request seen;
    final api = clientWith((req) async {
      seen = req;
      return jsonResponse({}, 200);
    });

    await api.post('/login', auth: false, body: {});

    expect(seen.headers.containsKey('Authorization'), isFalse);
  });

  test('401 con token: borra la sesión y avisa una sola vez', () async {
    var expired = 0;
    final api = clientWith((_) async => jsonResponse({}, 401))
      ..onSessionExpired = () => expired++;

    await Future.wait([
      expectLater(api.get('/me'), throwsA(isA<UnauthorizedException>())),
      expectLater(api.get('/charts'), throwsA(isA<UnauthorizedException>())),
    ]);

    expect(await TokenStore().read(), isNull);
    expect(expired, 1);
  });

  test('401 sin token (login fallido): no toca la sesión', () async {
    var expired = 0;
    final api = clientWith(
      (_) async => jsonResponse({'message': 'Credenciales inválidas'}, 401),
    )..onSessionExpired = () => expired++;

    await expectLater(
      api.post('/login', auth: false, body: {}),
      throwsA(predicate((e) => e.toString() == 'Credenciales inválidas')),
    );
    expect(await TokenStore().read(), 'tok-1');
    expect(expired, 0);
  });

  test('403 insufficient_coins: lanza el error y avisa para abrir la tienda',
      () async {
    InsufficientCoinsException? notified;
    final api = clientWith(
      (_) async => jsonResponse(
        {'insufficient_coins': true, 'required_coins': 10, 'current_balance': 3},
        403,
      ),
    )..onInsufficientCoins = (e) => notified = e;

    await expectLater(
      api.post('/oraculo/consultar', body: {}),
      throwsA(isA<InsufficientCoinsException>()),
    );
    expect(notified?.required, 10);
    expect(notified?.balance, 3);
  });

  test('403 sin insufficient_coins es un error común', () async {
    var notified = false;
    final api = clientWith((_) async => jsonResponse({'message': 'No'}, 403))
      ..onInsufficientCoins = (_) => notified = true;

    await expectLater(
      api.get('/x'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e is InsufficientCoinsException, 'monedas', isFalse),
      ),
    );
    expect(notified, isFalse);
  });

  test('422: trae los errores de cada campo', () async {
    final api = clientWith(
      (_) async => jsonResponse({
        'message': 'The given data was invalid.',
        'errors': {
          'email': ['El email ya está en uso.'],
          'password': ['Muy corta.', 'Sin números.'],
        },
      }, 422),
    );

    try {
      await api.post('/register', auth: false, body: {});
      fail('Debió lanzar ValidationException');
    } on ValidationException catch (e) {
      expect(e.message, 'El email ya está en uso.');
      expect(e.errorFor('password'), 'Muy corta.');
      expect(e.fieldErrors['password'], hasLength(2));
    }
  });

  test('429: espera lo que pide Retry-After y reintenta', () async {
    var calls = 0;
    final api = clientWith((_) async {
      calls++;
      if (calls == 1) {
        return jsonResponse({}, 429, headers: {'retry-after': '3'});
      }
      if (calls == 2) return jsonResponse({}, 429);
      return jsonResponse({'ok': true}, 200);
    });

    expect(await api.get('/x'), {'ok': true});
    expect(calls, 3);
    expect(waits, [const Duration(seconds: 3), const Duration(seconds: 2)]);
  });

  test('429 persistente: se rinde tras los reintentos', () async {
    var calls = 0;
    final api = clientWith((_) async {
      calls++;
      return jsonResponse({}, 429);
    });

    await expectLater(api.get('/x'), throwsA(isA<RateLimitedException>()));
    expect(calls, 3);
  });

  test('429 con una espera demasiado larga no reintenta', () async {
    var calls = 0;
    final api = clientWith((_) async {
      calls++;
      return jsonResponse({}, 429, headers: {'retry-after': '120'});
    });

    await expectLater(api.get('/x'), throwsA(isA<RateLimitedException>()));
    expect(calls, 1);
    expect(waits, isEmpty);
  });

  test('timeout: NetworkException', () async {
    final api = clientWith((_) => Completer<http.Response>().future);

    await expectLater(
      api.get('/x', timeout: const Duration(milliseconds: 20)),
      throwsA(isA<NetworkException>()),
    );
  });

  test('sin red: el error no expone la URL ni la query', () async {
    final api = clientWith(
      (req) async => throw http.ClientException('Connection refused', req.url),
    );

    try {
      await api.get('/astronomy/map', query: {'lat': '-33.52271'});
      fail('Debió lanzar NetworkException');
    } on NetworkException catch (e) {
      expect(e.toString(), isNot(contains('lat')));
      expect(e.toString(), isNot(contains('-33')));
    }
  });

  test('error del servidor: el mensaje no incluye el body', () async {
    final api = clientWith(
      (_) async => http.Response('<html>SQLSTATE secreto</html>', 500),
    );

    await expectLater(
      api.get('/x'),
      throwsA(
        predicate((e) => e is ApiException && !e.toString().contains('SQLSTATE')),
      ),
    );
  });

  test('cuerpo vacío o no JSON', () async {
    final empty = clientWith((_) async => http.Response('', 204));
    final text = clientWith((_) async => http.Response('<svg/>', 200));

    expect(await empty.delete('/x'), isNull);
    expect(await text.get('/x'), '<svg/>');
  });

  group('descargas', () {
    test('devuelve los bytes y el nombre saneado de Content-Disposition', () async {
      late http.Request seen;
      final api = clientWith((req) async {
        seen = req;
        return http.Response.bytes(utf8.encode('a,b\n1,2\n'), 200, headers: {
          'content-type': 'text/csv; charset=UTF-8',
          'content-disposition': 'attachment; filename=windowsdemeter-estudio-7-2026-11-04.csv',
        });
      });

      final d = await api.download('/estudios/7/exportar/csv');

      expect(seen.method, 'POST');
      expect(seen.headers['Authorization'], 'Bearer tok-1');
      expect(utf8.decode(d.bytes), 'a,b\n1,2\n');
      expect(d.nombre, 'windowsdemeter-estudio-7-2026-11-04.csv');
      expect(d.tipo, startsWith('text/csv'));
    });

    test('un 422 lanza el mensaje del servidor', () async {
      final api = clientWith((_) async =>
          jsonResponse({'success': false, 'message': 'Te falta Polvo Estelar.'}, 422));

      expect(
        () => api.download('/estudios/7/exportar/json'),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'Te falta Polvo Estelar.')),
      );
    });

    test('el nombre no puede salirse de la carpeta', () {
      expect(nombreDeDescarga('attachment; filename="estudio 7.csv"'), 'estudio_7.csv');
      expect(nombreDeDescarga("attachment; filename*=UTF-8''..%2F..%2Fmal.json"), 'mal.json');
      expect(nombreDeDescarga('attachment; filename=../.oculto'), isNull);
      expect(nombreDeDescarga(null), isNull);
      expect(nombreDeDescarga('inline'), isNull);
    });
  });
}
