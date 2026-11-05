import 'dart:convert';

import 'package:demeter/models/aviso.dart';
import 'package:demeter/screens/alerts_screen.dart';
import 'package:demeter/services/alerts_service.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/push_service.dart';
import 'package:demeter/widgets/aviso_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes/aviso_json.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';

/// El servidor de mentira: guarda las suscripciones y lo leído como el de
/// verdad.
class _FakeServer {
  _FakeServer({
    this.hasFavorites = true,
    Set<String>? active,
    List<Map<String, Object?>>? avisos,
    Set<String>? read,
  })  : active = active ?? {},
        avisos = avisos ?? [],
        read = read ?? {};

  final bool hasFavorites;
  final Set<String> active;
  final List<Map<String, Object?>> avisos;
  final Set<String> read;
  bool failNextPut = false;
  final List<http.Request> requests = [];

  http.Response handle(http.Request req) {
    requests.add(req);
    http.Response ok(Object body) => http.Response(jsonEncode(body), 200, headers: _json);
    final path = req.url.path;
    final leido = RegExp(r'^/api/avisos/([0-9a-f-]+)/leido$').firstMatch(path);
    if (leido != null) {
      read.add(leido[1]!);
      return ok({'success': true});
    }
    if (path == '/api/avisos/leidos') {
      read.addAll([for (final a in avisos) a['id'] as String]);
      return ok({'success': true});
    }
    if (path == '/api/avisos') {
      final list = [
        for (final a in avisos) {...a, 'leido': read.contains(a['id'])},
      ];
      return ok({
        'success': true,
        'no_leidos': list.where((a) => a['leido'] != true).length,
        'avisos': list,
      });
    }
    if (req.method == 'PUT') {
      if (failNextPut) {
        failNextPut = false;
        return http.Response(
          jsonEncode({'success': false, 'message': 'No puedes activar esa alerta.'}),
          422,
          headers: _json,
        );
      }
      final body = jsonDecode(req.body) as Map;
      final type = body['tipo'] as String;
      body['activo'] == true ? active.add(type) : active.remove(type);
    }
    return ok(preferenciasJson(tieneFavoritos: hasFavorites, activas: active));
  }

  List<String> get puts => [
        for (final r in requests)
          if (r.method == 'PUT') r.body,
      ];

  List<String> get avisoCalls => [
        for (final r in requests)
          if (r.url.path.startsWith('/api/avisos') && !r.url.path.contains('preferencias'))
            '${r.method} ${r.url.path}',
      ];
}

/// El permiso de notificaciones de mentira: al pedirlo, el usuario acepta.
class _Permission {
  _Permission({this.granted = false});

  bool granted;
  int requests = 0;

  PushService service() => PushService(
        available: true,
        hasPermission: () async => granted,
        requestPermission: () async {
          requests++;
          return granted = true;
        },
      );
}

List<Map<String, Object?>> _twoAvisos() => [
      avisoJson(_a, titulo: 'Lluvia fuerte mañana'),
      avisoJson(
        _b,
        tipo: 'sismo',
        titulo: 'Sismo cerca de Casa',
        url: 'https://www.gdacs.org/report.aspx?eventid=1',
        fuente: 'GDACS',
      ),
    ];

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    unreadAlerts.value = null;
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    _FakeServer server, {
    _Permission? permission,
    VoidCallback? onCreateFavorite,
    Aviso? opened,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: AlertsScreen(
        opened: opened,
        onCreateFavorite: onCreateFavorite ?? () {},
        alerts: AlertsService(
          api: ApiClient(
            baseUrl: 'https://windowsdemeter.com/api',
            httpClient: MockClient((req) async => server.handle(req)),
          ),
        ),
        push: (permission ?? _Permission(granted: true)).service(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder switchFor(String label) => find.widgetWithText(SwitchListTile, label);

  Future<void> tapSwitch(WidgetTester tester, String label) async {
    await tester.ensureVisible(switchFor(label));
    await tester.pumpAndSettle();
    await tester.tap(switchFor(label));
    await tester.pumpAndSettle();
  }

  group('mis alertas', () {
    testWidgets('las tres secciones de la web, sin contadores', (tester) async {
      await pumpScreen(tester, _FakeServer(active: {'lluvia', 'helada'}));

      for (final title in ['Alertas climáticas', 'Catástrofes en curso', 'Avisos astrológicos']) {
        expect(find.text(title), findsWidgets);
      }
      expect(find.text('Lluvia fuerte'), findsOneWidget);
      // Ya no se cuenta cuántas hay activas en cada sección.
      expect(find.text('2'), findsNothing);
    });

    testWidgets('catástrofes muestra siempre el aviso legal de GDACS', (tester) async {
      await pumpScreen(tester, _FakeServer());

      await tester.tap(find.text('Catástrofes en curso').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('no reemplaza las alertas de las autoridades locales'), findsWidgets);
      expect(find.text('Sismo'), findsOneWidget);
    });

    testWidgets('sin favoritos, un aviso lleva a crear uno', (tester) async {
      var asked = 0;
      await pumpScreen(tester, _FakeServer(hasFavorites: false), onCreateFavorite: () => asked++);

      expect(find.textContaining('necesitas al menos uno'), findsOneWidget);
      await tester.tap(find.text('Guardar un favorito'));
      expect(asked, 1);
    });

    testWidgets('con favoritos no sale ese aviso', (tester) async {
      await pumpScreen(tester, _FakeServer());

      expect(find.textContaining('necesitas al menos uno'), findsNothing);
    });

    testWidgets('al activar la primera alerta se pide el permiso, no antes', (tester) async {
      final server = _FakeServer();
      final permission = _Permission();
      await pumpScreen(tester, server, permission: permission);
      expect(permission.requests, 0);

      await tapSwitch(tester, 'Lluvia fuerte');

      expect(server.puts, [jsonEncode({'tipo': 'lluvia', 'activo': true})]);
      expect(permission.requests, 1);
      expect(tester.widget<SwitchListTile>(switchFor('Lluvia fuerte')).value, isTrue);

      // Con el permiso ya concedido, la siguiente no pregunta.
      await tapSwitch(tester, 'Helada');
      expect(permission.requests, 1);
    });

    testWidgets('apagar una alerta no pide permiso', (tester) async {
      final permission = _Permission();
      await pumpScreen(tester, _FakeServer(active: {'lluvia'}), permission: permission);

      await tapSwitch(tester, 'Lluvia fuerte');

      expect(permission.requests, 0);
    });

    testWidgets('si el servidor no la acepta, vuelve atrás y dice por qué', (tester) async {
      final server = _FakeServer()..failNextPut = true;
      final permission = _Permission();
      await pumpScreen(tester, server, permission: permission);

      await tapSwitch(tester, 'Lluvia fuerte');

      expect(tester.widget<SwitchListTile>(switchFor('Lluvia fuerte')).value, isFalse);
      expect(find.text('No puedes activar esa alerta.'), findsOneWidget);
      expect(permission.requests, 0);
    });

    testWidgets('con alertas activas y sin permiso, avisa y deja activarlo', (tester) async {
      final permission = _Permission();
      await pumpScreen(tester, _FakeServer(active: {'luna'}), permission: permission);

      expect(find.textContaining('los avisos solo se verán aquí'), findsOneWidget);
      await tester.tap(find.text('Activarlas'));
      await tester.pumpAndSettle();

      expect(permission.requests, 1);
      expect(find.textContaining('los avisos solo se verán aquí'), findsNothing);
    });
  });

  group('avisos recibidos', () {
    testWidgets('con no leídos se abre sola y muestra solo esos', (tester) async {
      final server = _FakeServer(avisos: _twoAvisos(), read: {_b});
      await pumpScreen(tester, server);

      expect(find.text('1 sin leer'), findsOneWidget);
      expect(find.text('Lluvia fuerte mañana'), findsOneWidget);
      expect(find.text('Sismo cerca de Casa'), findsNothing);
      expect(unreadAlerts.value, 1);

      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      expect(find.text('Sismo cerca de Casa'), findsOneWidget);
    });

    testWidgets('sin no leídos queda cerrada hasta tocarla', (tester) async {
      final server = _FakeServer(avisos: _twoAvisos(), read: {_a, _b});
      await pumpScreen(tester, server);

      expect(find.text('Lluvia fuerte mañana'), findsNothing);
      await tester.tap(find.text('Avisos recibidos'));
      await tester.pumpAndSettle();
      expect(find.text('No tienes avisos sin leer.'), findsOneWidget);

      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      expect(find.text('Lluvia fuerte mañana'), findsOneWidget);
    });

    testWidgets('lista los avisos con lugar, texto y si son nuevos', (tester) async {
      final server = _FakeServer(avisos: _twoAvisos());
      await pumpScreen(tester, server);

      expect(find.text('★ Casa'), findsNWidgets(2));
      expect(find.text('NUEVO'), findsNWidgets(2));
      expect(find.text('Para el 25-10-2026'), findsNWidgets(2));
      expect(unreadAlerts.value, 2);
    });

    testWidgets('una catástrofe lleva el aviso legal y el enlace a GDACS', (tester) async {
      await pumpScreen(tester, _FakeServer(avisos: _twoAvisos()));

      expect(find.text(kGdacsDisclaimer), findsOneWidget);
      expect(find.text('Más información en GDACS ↗'), findsOneWidget);
    });

    testWidgets('tocar uno nuevo lo marca leído y sigue a la vista', (tester) async {
      final server = _FakeServer(avisos: _twoAvisos());
      await pumpScreen(tester, server);

      await tester.tap(find.text('Lluvia fuerte mañana'));
      await tester.pumpAndSettle();

      expect(server.avisoCalls.last, 'POST /api/avisos/$_a/leido');
      expect(find.text('Lluvia fuerte mañana'), findsOneWidget);
      expect(find.text('NUEVO'), findsOneWidget);
      expect(unreadAlerts.value, 1);
    });

    testWidgets('el de una notificación se marca leído y va primero', (tester) async {
      final server = _FakeServer(avisos: _twoAvisos());
      await pumpScreen(
        tester,
        server,
        opened: const Aviso(id: _b, type: 'sismo', title: 'Sismo cerca de Casa'),
      );

      // Primero se marca, para que la lista llegue con la cuenta al día.
      expect(server.avisoCalls, ['POST /api/avisos/$_b/leido', 'GET /api/avisos']);
      final first = tester.getTopLeft(find.text('Sismo cerca de Casa'));
      final second = tester.getTopLeft(find.text('Lluvia fuerte mañana'));
      expect(first.dy, lessThan(second.dy));
      expect(find.text('NUEVO'), findsOneWidget);
      expect(unreadAlerts.value, 1);
    });

    testWidgets('si ya venció, se ve con lo que trajo el push', (tester) async {
      await pumpScreen(
        tester,
        _FakeServer(avisos: _twoAvisos()),
        opened: const Aviso(
          id: '33333333-3333-4333-8333-333333333333',
          type: 'helada',
          title: 'Helada esta noche',
          text: 'Mínima de -3 °C.',
        ),
      );

      expect(find.text('Helada esta noche'), findsOneWidget);
      expect(find.text('Mínima de -3 °C.'), findsOneWidget);
      expect(find.text('Lluvia fuerte mañana'), findsOneWidget);
    });

    testWidgets('marcar todos como leídos', (tester) async {
      final server = _FakeServer(avisos: _twoAvisos());
      await pumpScreen(tester, server);

      await tester.tap(find.byTooltip('Marcar todos como leídos'));
      await tester.pumpAndSettle();

      expect(server.avisoCalls.last, 'POST /api/avisos/leidos');
      expect(find.text('NUEVO'), findsNothing);
      expect(unreadAlerts.value, 0);
    });
  });

  test('cuándo llegó: hoy, ayer o la fecha', () {
    final now = DateTime(2026, 10, 24, 20);
    expect(arrivedLabel(DateTime(2026, 10, 24, 9, 5), now), 'Llegó hoy a las 09:05');
    expect(arrivedLabel(DateTime(2026, 10, 23, 23, 59), now), 'Llegó ayer a las 23:59');
    expect(arrivedLabel(DateTime(2026, 10, 2, 7, 30), now), 'Llegó el 02-10 a las 07:30');
    expect(dayLabel(DateTime(2026, 1, 5)), '05-01-2026');
  });
}
