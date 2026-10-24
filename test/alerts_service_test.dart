import 'dart:convert';

import 'package:demeter/models/aviso.dart';
import 'package:demeter/services/alerts_service.dart';
import 'package:demeter/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes/aviso_json.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _id = '9b1c4f7e-2d3a-4b5c-8d9e-0f1a2b3c4d5e';

void main() {
  late List<http.Request> requests;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    unreadAlerts.value = null;
    requests = [];
  });

  AlertsService serviceWith(int status, Object body) => AlertsService(
        api: ApiClient(
          baseUrl: 'https://windowsdemeter.com/api',
          httpClient: MockClient((req) async {
            requests.add(req);
            return http.Response(jsonEncode(body), status, headers: _json);
          }),
        ),
      );

  test('lista los vigentes y deja la cuenta de no leídos', () async {
    final service = serviceWith(200, {
      'success': true,
      'no_leidos': 1,
      'avisos': [
        avisoJson(_id, url: 'https://www.gdacs.org/x', fuente: 'GDACS'),
        avisoJson('otro', tipo: 'luna', lugar: '', leido: true, url: 'http://inseguro.test'),
        {'titulo': 'Sin id'},
      ],
    });

    final avisos = await service.list();

    expect(requests.single.url.path, '/api/avisos');
    expect(requests.single.headers['Authorization'], 'Bearer tok-1');
    expect([for (final a in avisos) a.id], [_id, 'otro']);
    expect(unreadAlerts.value, 1);

    final first = avisos.first;
    expect(first.place, 'Casa');
    expect(first.read, isFalse);
    expect(first.source, 'GDACS');
    expect(first.sourceUrl, Uri.parse('https://www.gdacs.org/x'));
    expect(first.targetDate, DateTime(2026, 10, 25));
    expect(first.createdAt, DateTime.parse('2026-10-24T21:30:00Z').toLocal());

    // Un enlace que no es https no se ofrece.
    expect(avisos.last.sourceUrl, isNull);
    expect(avisos.last.place, isEmpty);
  });

  test('marca un aviso leído por su id', () async {
    final service = serviceWith(200, {'success': true, 'pendientes': 0});

    await service.markRead(_id);

    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/avisos/$_id/leido');
  });

  test('un aviso que ya no es suyo (404) no es un error', () async {
    final service = serviceWith(404, {'success': false, 'pendientes': 3});

    await service.markRead(_id);

    expect(requests, hasLength(1));
  });

  test('un id que no es un uuid no sale del teléfono', () async {
    final service = serviceWith(200, {'success': true});

    await service.markRead('../favoritos');

    expect(requests, isEmpty);
  });

  test('marca todos leídos y deja la cuenta en cero', () async {
    unreadAlerts.value = 4;
    final service = serviceWith(200, {'success': true});

    await service.markAllRead();

    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/avisos/leidos');
    expect(unreadAlerts.value, 0);
  });

  test('preferencias: las tres secciones de la web, en orden', () async {
    final service = serviceWith(200, preferenciasJson(tieneFavoritos: false, activas: {'helada'}));

    final prefs = await service.preferences();

    expect(requests.single.url.path, '/api/avisos/preferencias');
    expect(prefs.hasFavorites, isFalse);
    expect(
      [for (final s in prefs.sections) s.title],
      ['Alertas climáticas', 'Catástrofes en curso', 'Avisos astrológicos'],
    );
    expect(prefs.anyActive, isTrue);
    expect(prefs.sections.first.activeCount, 1);
    expect(prefs.catastropheTypes, containsAll(kCatastropheTypes));
  });

  test('activar una alerta manda tipo y activo con PUT', () async {
    final service = serviceWith(200, preferenciasJson(activas: {'lluvia'}));

    final prefs = await service.setActive('lluvia', true);

    final request = requests.single;
    expect(request.method, 'PUT');
    expect(request.url.path, '/api/avisos/preferencias');
    expect(jsonDecode(request.body), {'tipo': 'lluvia', 'activo': true});
    expect(prefs.sections.first.alerts.first.active, isTrue);
  });

  test('el push trae aviso_id, tipo, título y texto, sin lugar', () {
    final aviso = Aviso.fromPush({
      'aviso_id': _id,
      'tipo': 'sismo',
      'titulo': 'Sismo cerca de Casa',
      'texto': 'Magnitud 6,1.',
    });

    expect(aviso?.id, _id);
    expect(aviso?.type, 'sismo');
    expect(aviso?.title, 'Sismo cerca de Casa');
    expect(aviso?.place, isEmpty);
    expect(Aviso.fromPush({'tipo': 'lluvia'}), isNull);
  });
}
