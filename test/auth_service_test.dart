import 'dart:convert';

import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/auth_service.dart';
import 'package:demeter/services/device_name.dart';
import 'package:demeter/services/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Map<String, String> secure;
  late List<http.Request> requests;

  setUp(() {
    secure = {'sanctum_token': 'tok-1', 'device_name': 'android:abc'};
    FlutterSecureStorage.setMockInitialValues(secure);
    SharedPreferences.setMockInitialValues({
      'last_sky_data': '{}',
      'wallpaper_lat': -33.45,
      'wallpaper_lon': -70.66,
    });
    DeviceName.resetForTest();
    requests = [];
  });

  void serverAnswers(int status, Object body) {
    ApiClient.instance = ApiClient(
      httpClient: MockClient((req) async {
        requests.add(req);
        return http.Response(jsonEncode(body), status);
      }),
      baseUrl: 'https://api.test/api',
    );
  }

  Future<Set<String>> prefsKeys() async =>
      (await SharedPreferences.getInstance()).getKeys();

  test('logout: avisa al servidor y borra token y prefs', () async {
    serverAnswers(200, {'message': 'ok'});

    await AuthService().logout();

    expect(requests.single.url.path, '/api/logout');
    expect(requests.single.headers['Authorization'], 'Bearer tok-1');
    expect(await TokenStore().read(), isNull);
    expect(await prefsKeys(), isEmpty);
  });

  test('logout sin red: borra igual lo del equipo', () async {
    ApiClient.instance = ApiClient(
      httpClient: MockClient((_) async => throw http.ClientException('x')),
      baseUrl: 'https://api.test/api',
    );

    await AuthService().logout();

    expect(await TokenStore().read(), isNull);
    expect(await prefsKeys(), isEmpty);
  });

  test('logout conserva el nombre de la instalación', () async {
    serverAnswers(200, {'message': 'ok'});

    await AuthService().logout();

    expect(secure['device_name'], 'android:abc');
  });

  test('clearLocalSession no llama al servidor', () async {
    serverAnswers(200, {});

    await AuthService().clearLocalSession();

    expect(requests, isEmpty);
    expect(await TokenStore().read(), isNull);
  });

  test('login y registro mandan el nombre de la instalación', () async {
    serverAnswers(200, {
      'access_token': 'tok-2',
      'token_type': 'Bearer',
      'user': {'id': 1, 'name': 'A', 'email': 'a@a.test'},
    });

    await AuthService().login('a@a.test', 'x');
    await AuthService().register(
      name: 'A',
      email: 'a@a.test',
      password: 'x',
      passwordConfirmation: 'x',
    );

    for (final req in requests) {
      expect(jsonDecode(req.body)['device_name'], 'android:abc');
    }
    expect(await TokenStore().read(), 'tok-2');
  });

  group('2FA', () {
    const session = {
      'access_token': 'tok-2',
      'token_type': 'Bearer',
      'user': {'id': 1, 'name': 'A', 'email': 'a@a.test'},
    };

    test('login con 2FA: entrega el desafío y no guarda token', () async {
      await TokenStore().clear();
      serverAnswers(200, {'two_factor': true, 'desafio': 'd-1'});

      await expectLater(
        AuthService().login('a@a.test', 'x'),
        throwsA(isA<TwoFactorRequired>()
            .having((e) => e.desafio, 'desafio', 'd-1')),
      );
      expect(await TokenStore().read(), isNull);
    });

    test('con el código: manda desafío, código y dispositivo', () async {
      serverAnswers(200, session);

      await AuthService().loginTwoFactor(desafio: 'd-1', code: '123456');

      expect(requests.single.url.path, '/api/login/2fa');
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(requests.single.body), {
        'desafio': 'd-1',
        'code': '123456',
        'device_name': 'android:abc',
      });
      expect(await TokenStore().read(), 'tok-2');
    });

    test('con un código de recuperación no manda code', () async {
      serverAnswers(200, session);

      await AuthService().loginTwoFactor(desafio: 'd-1', recoveryCode: 'r-1');

      final sent = jsonDecode(requests.single.body) as Map;
      expect(sent['recovery_code'], 'r-1');
      expect(sent.containsKey('code'), isFalse);
    });

    test('código inválido o desafío vencido: el mensaje del servidor',
        () async {
      await TokenStore().clear();
      serverAnswers(422, {'message': 'El código no es válido.'});

      await expectLater(
        AuthService().loginTwoFactor(desafio: 'd-1', code: '000000'),
        throwsA(predicate((e) => e.toString() == 'El código no es válido.')),
      );
      expect(await TokenStore().read(), isNull);
    });
  });
}
