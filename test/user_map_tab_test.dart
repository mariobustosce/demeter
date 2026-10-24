import 'dart:convert';

import 'package:demeter/screens/user_map_tab.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/landscape_thumbnails.dart';
import 'package:demeter/services/location_service.dart';
import 'package:demeter/services/map_view_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'fakes/fake_webview.dart';
import 'fakes/landscape_json.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

class _GrantedLocation extends LocationService {
  @override
  Future<LocationAccess> access() async => LocationAccess.granted;

  @override
  Future<RoundedLocation?> current() async => RoundedLocation(-33.456789, -70.648123);
}

/// El servidor de mentira: favoritos en memoria y respuestas a medida.
class _FakeServer {
  List<Map<String, Object?>> favorites = [];
  String? landscape; // el del favorito, null: el de siempre
  ({int status, Object body})? saveResponse;
  final List<http.Request> requests = [];

  http.Response handle(http.Request req) {
    requests.add(req);
    final path = req.url.path;
    final method = req.method;
    http.Response ok(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status, headers: _json);

    if (method == 'POST' && path == '/api/app/vista') {
      return ok({
        'token': 'v1',
        'expira_en': 86400,
        'base_url': 'https://windowsdemeter.com/app/mapa/t/v1',
      }, 201);
    }
    if (method == 'GET' && path == '/api/favoritos') {
      return ok({'success': true, 'favoritos': favorites});
    }
    if (method == 'POST' && path == '/api/favoritos') {
      final response = saveResponse!;
      return ok(response.body, response.status);
    }
    final match = RegExp(r'^/api/favoritos/(\d+)(/paisaje)?$').firstMatch(path);
    if (match != null) {
      final id = int.parse(match[1]!);
      if (match[2] != null) {
        if (method == 'PATCH') {
          landscape = (jsonDecode(req.body) as Map)['paisaje'] as String?;
        }
        return ok({'success': true, 'paisaje': landscape, 'favorito': {'id': id}});
      }
      if (method == 'DELETE') {
        favorites.removeWhere((f) => f['id'] == id);
        return ok({'success': true});
      }
      if (method == 'PATCH') {
        final title = (jsonDecode(req.body) as Map)['titulo'];
        return ok({'success': true, 'favorito': {'id': id, 'titulo': title}});
      }
    }
    if (method == 'GET' && path == '/api/paisajes') {
      return ok({
        'success': true,
        'saldo': 1000,
        'paisajes': [
          landscapeJson('cordillera', isDefault: true),
          landscapeJson('volcan'),
          landscapeJson('castillo-wulff', premium: true, canUse: false),
        ],
      });
    }
    if (method == 'POST' && path == '/api/paisajes/castillo-wulff/comprar') {
      return ok({
        'success': true,
        'saldo': 900,
        'paisaje': landscapeJson('castillo-wulff', premium: true, purchased: true),
      });
    }
    return ok({'message': 'No encontrado'}, 404);
  }

  http.Request last(String method, String path) =>
      requests.lastWhere((r) => r.method == method && r.url.path == path);
}

void main() {
  late FakeWebViewPlatform platform;
  late _FakeServer server;

  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    server = _FakeServer();
    ApiClient.instance = ApiClient(
      baseUrl: 'https://windowsdemeter.com/api',
      httpClient: MockClient((req) async => server.handle(req)),
    );
    MapViewService.instance = MapViewService();
    LocationService.instance = _GrantedLocation();
    // Sin red ni disco: las miniaturas quedan en su hueco.
    LandscapeThumbnails.instance = LandscapeThumbnails(
      httpClient: MockClient((_) async => http.Response('', 404)),
      directory: () async => null,
    );
  });

  Future<void> frames(WidgetTester tester, [int n = 8]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: UserMapTab(active: true)),
    ));
    await frames(tester);
  }

  List<Uri> loaded() => platform.last.loaded;

  testWidgets('★ guarda «Mi ubicación» con 2 decimales y pasa a verla como favorito',
      (tester) async {
    server.saveResponse = (
      status: 201,
      body: {
        'success': true,
        'existente': false,
        'favorito': {'id': 7, 'titulo': 'La Florida', 'lat': -33.46, 'lon': -70.65},
      },
    );
    await open(tester);
    expect(loaded().last.path, '/app/mapa/t/v1/basico');
    expect(loaded().last.queryParameters['lat'], '-33.46');

    await tester.tap(find.byTooltip('Guardar en favoritos'));
    await frames(tester);

    final saved = server.last('POST', '/api/favoritos');
    expect(jsonDecode(saved.body), {'lat': -33.46, 'lon': -70.65});
    expect(find.text('La Florida'), findsOneWidget);
    expect(find.text('★ Guardado: La Florida'), findsOneWidget);
    expect(loaded().last.path, '/app/mapa/t/v1/basico/f/7');
    expect(loaded().last.queryParameters.containsKey('lat'), isFalse);
  });

  testWidgets('el tope lo pone el servidor y se muestra su mensaje', (tester) async {
    const message = 'Ya tienes 20 lugares guardados. Quita alguno para añadir otro.';
    server.saveResponse = (status: 422, body: {'success': false, 'message': message});
    await open(tester);
    final before = loaded().length;

    await tester.tap(find.byTooltip('Guardar en favoritos'));
    await frames(tester);

    expect(find.text(message), findsOneWidget);
    expect(loaded().length, before, reason: 'el mapa sigue donde estaba');
  });

  testWidgets('con favoritos abre en el primero; cambiar su paisaje recarga el mapa',
      (tester) async {
    server.favorites = [
      {'id': 1, 'titulo': 'Casa'},
      {'id': 2, 'titulo': 'Playa'},
    ];
    await open(tester);
    expect(loaded().last.path, '/app/mapa/t/v1/basico/f/1');
    final before = loaded().length;

    await tester.tap(find.byTooltip('Opciones de este lugar'));
    await frames(tester);
    await tester.tap(find.text('Paisaje de este lugar'));
    await frames(tester);

    // Sin paisaje propio, el elegido es el de siempre.
    expect(find.text('El de siempre'), findsOneWidget);
    await tester.tap(find.text('Paisaje volcan'));
    await frames(tester);

    final patch = server.last('PATCH', '/api/favoritos/1/paisaje');
    expect(jsonDecode(patch.body), {'paisaje': 'volcan'});
    expect(find.text('Paisaje cambiado a «Paisaje volcan»'), findsOneWidget);
    expect(loaded().length, before + 1);
    expect(loaded().last.path, '/app/mapa/t/v1/basico/f/1');
  });

  testWidgets('un paisaje con 🔒 se compra con confirmación y queda puesto',
      (tester) async {
    server.favorites = [
      {'id': 1, 'titulo': 'Casa'},
    ];
    await open(tester);

    await tester.tap(find.byTooltip('Opciones de este lugar'));
    await frames(tester);
    await tester.tap(find.text('Paisaje de este lugar'));
    await frames(tester);

    expect(find.text('🔒 100 ✨'), findsOneWidget);
    await tester.ensureVisible(find.text('Paisaje castillo-wulff'));
    await frames(tester, 2);
    await tester.tap(find.text('Paisaje castillo-wulff'));
    await frames(tester);
    expect(find.text('¿Comprar «Paisaje castillo-wulff» por 100 ✨?'), findsOneWidget);
    await tester.tap(find.text('Comprar'));
    await frames(tester);

    server.last('POST', '/api/paisajes/castillo-wulff/comprar');
    final patch = server.last('PATCH', '/api/favoritos/1/paisaje');
    expect(jsonDecode(patch.body), {'paisaje': 'castillo-wulff'});
    expect(find.text('¡Tuyo! «Paisaje castillo-wulff» ya está en Casa.'), findsOneWidget);
  });

  testWidgets('quitar el favorito que se ve avisa del fondo y pasa al siguiente',
      (tester) async {
    server.favorites = [
      {'id': 1, 'titulo': 'Casa'},
      {'id': 2, 'titulo': 'Playa'},
    ];
    await open(tester);

    await tester.tap(find.byTooltip('Opciones de este lugar'));
    await frames(tester);
    await tester.tap(find.text('Quitar de favoritos'));
    await frames(tester);

    expect(find.textContaining('fondo animado'), findsOneWidget);
    await tester.tap(find.text('Quitar'));
    await frames(tester);

    server.last('DELETE', '/api/favoritos/1');
    expect(find.text('Casa'), findsNothing);
    expect(loaded().last.path, '/app/mapa/t/v1/basico/f/2');
  });

  testWidgets('el botón despliega los lugares y cambia de favorito y a «Mi ubicación»',
      (tester) async {
    server.favorites = [
      {'id': 1, 'titulo': 'Casa'},
      {'id': 2, 'titulo': 'Playa'},
    ];
    await open(tester);
    expect(loaded().last.path, '/app/mapa/t/v1/basico/f/1');
    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('Playa'), findsNothing, reason: 'cerrado solo muestra el lugar que se ve');

    await tester.tap(find.byTooltip('Favoritos'));
    await frames(tester);
    expect(find.text('Mi ubicación'), findsOneWidget);
    await tester.tap(find.text('Playa'));
    await frames(tester);
    expect(loaded().last.path, '/app/mapa/t/v1/basico/f/2');
    expect(find.text('Playa'), findsOneWidget);

    await tester.tap(find.byTooltip('Favoritos'));
    await frames(tester);
    await tester.tap(find.text('Mi ubicación'));
    await frames(tester);
    expect(loaded().last.path, '/app/mapa/t/v1/basico');
    expect(loaded().last.queryParameters['lat'], '-33.46');
    expect(find.byTooltip('Guardar en favoritos'), findsOneWidget);
  });

  testWidgets('el ⋮ de un favorito de la lista lo renombra; si no se ve, el mapa no recarga',
      (tester) async {
    server.favorites = [
      {'id': 1, 'titulo': 'Casa'},
      {'id': 2, 'titulo': 'Playa'},
    ];
    await open(tester);
    final before = loaded().length;

    await tester.tap(find.byTooltip('Favoritos'));
    await frames(tester);
    await tester.tap(find.byTooltip('Opciones de «Playa»'));
    await frames(tester);
    await tester.tap(find.text('Cambiar el nombre'));
    await frames(tester);
    await tester.enterText(find.byType(TextField), '  Playa Brava ');
    await tester.tap(find.text('Guardar'));
    await frames(tester);

    final patch = server.last('PATCH', '/api/favoritos/2');
    expect(jsonDecode(patch.body), {'titulo': 'Playa Brava'});
    expect(loaded().length, before);

    await tester.tap(find.byTooltip('Favoritos'));
    await frames(tester);
    expect(find.text('Playa Brava'), findsOneWidget);
  });
}
