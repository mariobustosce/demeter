import 'dart:async';
import 'dart:convert';

import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/map_view_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const base = 'https://windowsdemeter.com/app/mapa/t/';
  late DateTime now;
  late int calls;
  late List<Completer<void>> gates;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    now = DateTime(2026, 10, 23, 12);
    calls = 0;
    gates = [];
  });

  /// Cada llamada da un token nuevo (`v1`, `v2`…) que vale [seconds].
  MapViewService serviceWith({int seconds = 86400, bool hold = false}) {
    final api = ApiClient(
      baseUrl: 'https://windowsdemeter.com/api',
      httpClient: MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, '/api/app/vista');
        expect(req.headers['Authorization'], 'Bearer tok-1');
        calls++;
        if (hold) {
          final gate = Completer<void>();
          gates.add(gate);
          await gate.future;
        }
        return http.Response(
          jsonEncode({
            'token': 'v$calls',
            'expira_en': seconds,
            'expira_at': '2000-01-01T00:00:00+00:00',
            'base_url': '${base}v$calls',
          }),
          201,
        );
      }),
    );
    return MapViewService(api: api, clock: () => now);
  }

  test('pide la vista una vez y la reutiliza mientras le quede más de 1 h', () async {
    final service = serviceWith();

    final first = await service.get();
    now = now.add(const Duration(hours: 22, minutes: 59));
    final again = await service.get();

    expect(first.baseUrl, '${base}v1');
    expect(identical(first, again), isTrue);
    expect(calls, 1);
  });

  test('con menos de 1 h por delante pide otra', () async {
    final service = serviceWith();

    await service.get();
    now = now.add(const Duration(hours: 23, minutes: 1));
    final renewed = await service.get();

    expect(renewed.baseUrl, '${base}v2');
    expect(calls, 2);
  });

  test('la vigencia sale de expira_en y del reloj del teléfono', () async {
    // expira_at dice 2000: si se usara, la vista nacería vencida.
    final view = await serviceWith(seconds: 7200).get();
    expect(view.expiresAt, now.add(const Duration(hours: 2)));
  });

  test('renew (tras un 404) pide otra aunque la actual siga vigente', () async {
    final service = serviceWith();

    await service.get();
    final renewed = await service.get(renew: true);

    expect(renewed.baseUrl, '${base}v2');
  });

  test('pedidos simultáneos comparten una sola llamada', () async {
    final service = serviceWith(hold: true);

    final a = service.get();
    final b = service.get();
    await pumpEventQueue();
    gates.single.complete();

    expect((await a).baseUrl, (await b).baseUrl);
    expect(calls, 1);
  });

  test('tras clear() no reutiliza la vista anterior', () async {
    final service = serviceWith();

    await service.get();
    service.clear();
    final next = await service.get();

    expect(next.baseUrl, '${base}v2');
  });

  test('una respuesta que llega después del logout no se guarda', () async {
    final service = serviceWith(hold: true);

    final old = service.get();
    await pumpEventQueue();
    service.clear();
    gates.single.complete();
    await old;

    final next = service.get();
    await pumpEventQueue();
    gates.last.complete();
    expect((await next).baseUrl, '${base}v2');
  });

  test('un base_url de otro sitio se rechaza', () {
    expect(
      () => MapView.fromJson(
        {'base_url': 'https://evil.test/app/mapa/t/x', 'expira_en': 60},
        now: now,
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('sin red, el error llega a quien pidió y el siguiente reintenta', () async {
    var fail = true;
    final service = MapViewService(
      clock: () => now,
      api: ApiClient(
        baseUrl: 'https://windowsdemeter.com/api',
        httpClient: MockClient((_) async {
          if (fail) throw http.ClientException('sin red');
          return http.Response(
            jsonEncode({'expira_en': 86400, 'base_url': '${base}ok'}),
            201,
          );
        }),
      ),
    );

    await expectLater(service.get(), throwsA(isA<NetworkException>()));
    fail = false;
    expect((await service.get()).baseUrl, '${base}ok');
  });
}
