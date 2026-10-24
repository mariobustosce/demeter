import 'dart:convert';

import 'package:demeter/screens/alerts_tab.dart';
import 'package:demeter/services/alerts_service.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes/aviso_json.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

/// El servidor de mentira: guarda las suscripciones como el de verdad.
class _FakeServer {
  _FakeServer({this.hasFavorites = true, Set<String>? active})
      : active = active ?? {};

  final bool hasFavorites;
  final Set<String> active;
  bool failNextPut = false;
  final List<http.Request> requests = [];

  http.Response handle(http.Request req) {
    requests.add(req);
    http.Response ok(Object body) => http.Response(jsonEncode(body), 200, headers: _json);
    if (req.url.path == '/api/avisos') {
      return ok({'success': true, 'no_leidos': 2, 'avisos': []});
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

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    unreadAlerts.value = null;
  });

  Future<void> pumpTab(
    WidgetTester tester,
    _FakeServer server, {
    _Permission? permission,
    VoidCallback? onCreateFavorite,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AlertsTab(
          active: true,
          onCreateFavorite: onCreateFavorite ?? () {},
          alerts: AlertsService(
            api: ApiClient(
              baseUrl: 'https://windowsdemeter.com/api',
              httpClient: MockClient((req) async => server.handle(req)),
            ),
          ),
          push: (permission ?? _Permission(granted: true)).service(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('tres pestañas con los nombres de la web', (tester) async {
    await pumpTab(tester, _FakeServer());

    for (final title in ['Alertas climáticas', 'Catástrofes en curso', 'Avisos astrológicos']) {
      expect(find.descendant(of: find.byType(Tab), matching: find.text(title)), findsOneWidget);
    }
    expect(find.text('Lluvia fuerte'), findsOneWidget);
    // Los no leídos de la lista, en la entrada a los avisos.
    expect(find.text('2 sin leer'), findsOneWidget);
  });

  testWidgets('catástrofes muestra siempre el aviso legal de GDACS', (tester) async {
    await pumpTab(tester, _FakeServer());

    await tester.tap(find.text('Catástrofes en curso').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('no reemplaza las alertas de las autoridades locales'), findsWidgets);
    expect(find.text('Sismo'), findsOneWidget);
  });

  testWidgets('sin favoritos, un aviso lleva a crear uno', (tester) async {
    var asked = 0;
    await pumpTab(tester, _FakeServer(hasFavorites: false), onCreateFavorite: () => asked++);

    expect(find.textContaining('necesitas al menos uno'), findsOneWidget);
    await tester.tap(find.text('Guardar un favorito'));
    expect(asked, 1);
  });

  testWidgets('con favoritos no sale ese aviso', (tester) async {
    await pumpTab(tester, _FakeServer());

    expect(find.textContaining('necesitas al menos uno'), findsNothing);
  });

  testWidgets('al activar la primera alerta se pide el permiso, no antes', (tester) async {
    final server = _FakeServer();
    final permission = _Permission();
    await pumpTab(tester, server, permission: permission);
    expect(permission.requests, 0);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Lluvia fuerte'));
    await tester.pumpAndSettle();

    expect(server.puts, [jsonEncode({'tipo': 'lluvia', 'activo': true})]);
    expect(permission.requests, 1);
    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Lluvia fuerte')).value, isTrue);

    // Con el permiso ya concedido, la siguiente no pregunta.
    await tester.tap(find.widgetWithText(SwitchListTile, 'Helada'));
    await tester.pumpAndSettle();
    expect(permission.requests, 1);
  });

  testWidgets('apagar una alerta no pide permiso', (tester) async {
    final permission = _Permission();
    await pumpTab(tester, _FakeServer(active: {'lluvia'}), permission: permission);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Lluvia fuerte'));
    await tester.pumpAndSettle();

    expect(permission.requests, 0);
  });

  testWidgets('si el servidor no la acepta, vuelve atrás y dice por qué', (tester) async {
    final server = _FakeServer()..failNextPut = true;
    final permission = _Permission();
    await pumpTab(tester, server, permission: permission);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Lluvia fuerte'));
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Lluvia fuerte')).value, isFalse);
    expect(find.text('No puedes activar esa alerta.'), findsOneWidget);
    expect(permission.requests, 0);
  });

  testWidgets('con alertas activas y sin permiso, avisa y deja activarlo', (tester) async {
    final permission = _Permission();
    await pumpTab(tester, _FakeServer(active: {'luna'}), permission: permission);

    expect(find.textContaining('los avisos solo se verán aquí'), findsOneWidget);
    await tester.tap(find.text('Activarlas'));
    await tester.pumpAndSettle();

    expect(permission.requests, 1);
    expect(find.textContaining('los avisos solo se verán aquí'), findsNothing);
  });
}
