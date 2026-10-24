import 'dart:convert';

import 'package:demeter/models/wallpaper_link.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/coin_balance.dart';
import 'package:demeter/services/wallpaper_links_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _lively = 'https://windowsdemeter.com/lively/m/tok123456789012345678';

void main() {
  late List<http.Request> requests;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    coinBalance.value = null;
    requests = [];
  });

  WallpaperLinksService serviceWith(int status, Object body) => WallpaperLinksService(
        api: ApiClient(
          baseUrl: 'https://windowsdemeter.com/api',
          httpClient: MockClient((req) async {
            requests.add(req);
            return http.Response(jsonEncode(body), status, headers: _json);
          }),
        ),
      );

  test('lee las URL de cada modo y el rotativo', () async {
    final service = serviceWith(200, {
      'success': true,
      'existe': true,
      'urls': {
        'basico': '$_lively/basico',
        'profesional': '$_lively/profesional',
        'astronomico': '$_lively/astronomico',
        'rotativo': '$_lively/rotativo',
        'tele': '$_lively/tele',
      },
      'puede_crear': true,
      'rotativo': {'desbloqueado': true, 'precio': 200},
      'ultimo_uso_at': null,
    });

    final link = await service.get(7);

    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/api/favoritos/7/fondo');
    expect(requests.single.headers['Authorization'], 'Bearer tok-1');
    expect(link.exists, isTrue);
    expect(link.urls.keys, WallpaperMode.values);
    expect(link.urls[WallpaperMode.astronomico], '$_lively/astronomico');
    expect(link.rotatingUnlocked, isTrue);
    expect(link.rotatingPrice, 200);
  });

  test('sin fondo, las URL llegan vacías (objeto o lista)', () async {
    for (final urls in [<String, Object>{}, <Object>[]]) {
      final service = serviceWith(200, {
        'success': true,
        'existe': false,
        'urls': urls,
        'puede_crear': true,
        'rotativo': {'desbloqueado': false, 'precio': 200},
      });

      final link = await service.get(7);

      expect(link.exists, isFalse);
      expect(link.urls, isEmpty);
      expect(link.rotatingUnlocked, isFalse);
    }
  });

  test('crea y regenera con POST', () async {
    final body = {
      'success': true,
      'existe': true,
      'urls': {'basico': '$_lively/basico'},
    };

    await serviceWith(201, body).create(7);
    await serviceWith(200, body).regenerate(7);

    expect([for (final r in requests) '${r.method} ${r.url.path}'], [
      'POST /api/favoritos/7/fondo',
      'POST /api/favoritos/7/fondo/regenerar',
    ]);
  });

  test('desbloquear el rotativo deja el saldo nuevo', () async {
    final service = serviceWith(200, {
      'success': true,
      'existe': false,
      'urls': {},
      'rotativo': {'desbloqueado': true, 'precio': 200},
      'saldo': 300,
    });

    final link = await service.unlockRotating(7);

    expect(requests.single.url.path, '/api/favoritos/7/fondo/rotativo');
    expect(link.rotatingUnlocked, isTrue);
    expect(coinBalance.value, 300);
  });

  test('si falta polvo, el mensaje del servidor llega tal cual', () async {
    final service = serviceWith(422, {
      'success': false,
      'message': 'Te faltan 50 ✨ de polvo estelar.',
    });

    expect(
      service.unlockRotating(7),
      throwsA(isA<ValidationException>()
          .having((e) => e.message, 'message', 'Te faltan 50 ✨ de polvo estelar.')),
    );
  });
}
