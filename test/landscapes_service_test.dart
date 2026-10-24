import 'dart:convert';

import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/coin_balance.dart';
import 'package:demeter/services/landscapes_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes/landscape_json.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

void main() {
  late List<http.Request> requests;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    requests = [];
    coinBalance.value = null;
  });

  LandscapesService serviceWith(int status, Object body) => LandscapesService(
        api: ApiClient(
          baseUrl: 'https://windowsdemeter.com/api',
          httpClient: MockClient((req) async {
            requests.add(req);
            return http.Response(jsonEncode(body), status, headers: _json);
          }),
        ),
      );

  test('el catálogo llega en el orden del admin, con candado y saldo', () async {
    final service = serviceWith(200, {
      'success': true,
      'saldo': 1000,
      'momentos': ['amanecer', 'mediodia', 'tarde', 'noche'],
      'paisajes': [
        landscapeJson('cordillera', isDefault: true),
        landscapeJson('castillo-wulff', premium: true, canUse: false),
        landscapeJson('volcan', premium: true, purchased: true),
        {'titulo': 'sin clave'},
      ],
    });

    final catalog = await service.catalog();

    expect([for (final l in catalog) l.key], ['cordillera', 'castillo-wulff', 'volcan']);
    final locked = catalog[1];
    expect(locked.locked, isTrue);
    expect(locked.isPremium, isTrue);
    expect(locked.price, 100);
    expect(locked.thumbnailUrl, 'https://windowsdemeter.com/paisajes/castillo-wulff/miniatura');
    expect(catalog[0].isDefault, isTrue);
    expect(catalog[2].purchased, isTrue);
    expect(catalog[2].locked, isFalse);
    expect(coinBalance.value, 1000);
  });

  test('comprar devuelve el paisaje desbloqueado y deja el saldo nuevo', () async {
    final service = serviceWith(200, {
      'success': true,
      'saldo': 900,
      'paisaje': landscapeJson('castillo-wulff', premium: true, purchased: true),
    });

    final bought = await service.buy('castillo-wulff');

    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/paisajes/castillo-wulff/comprar');
    expect(bought.purchased, isTrue);
    expect(bought.locked, isFalse);
    expect(coinBalance.value, 900);
  });

  test('si falta polvo, el 422 trae el mensaje del servidor', () async {
    const message = 'Te falta Polvo Estelar: este paisaje cuesta 100 ✨ y tienes 40.';
    final service = serviceWith(422, {'success': false, 'message': message});

    expect(
      () => service.buy('castillo-wulff'),
      throwsA(isA<ValidationException>().having((e) => e.message, 'message', message)),
    );
  });

  test('una clave rara no llega a armar la ruta', () async {
    final service = serviceWith(200, {'success': true});

    for (final key in ['../favoritos', 'a/b', 'Mayúscula', '']) {
      await expectLater(service.buy(key), throwsA(isA<ApiException>()));
    }
    expect(requests, isEmpty);
  });
}
