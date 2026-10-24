import 'dart:convert';

import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/coin_balance.dart';
import 'package:demeter/services/favorites_service.dart';
import 'package:demeter/services/live_wallpaper.dart';
import 'package:demeter/services/wallpaper_links_service.dart';
import 'package:demeter/widgets/wallpaper_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _channel = MethodChannel('windowsdemeter.com/wallpaper');
const _web = 'https://windowsdemeter.com';

/// El servidor de mentira: favoritos y el fondo de cada uno.
class _FakeServer {
  List<Map<String, Object?>> favorites = [
    {'id': 3, 'titulo': 'Casa'},
    {'id': 9, 'titulo': 'Playa'},
  ];
  final Map<int, String> tokens = {}; // favoritos con fondo
  final Set<int> rotating = {}; // con el rotativo desbloqueado
  final List<String> requests = [];

  Map<String, Object?> fondo(int id) {
    final token = tokens[id];
    return {
      'success': true,
      'existe': token != null,
      'urls': token == null
          ? {}
          : {
              for (final m in ['basico', 'profesional', 'astronomico'])
                m: '$_web/lively/m/$token/$m',
              if (rotating.contains(id)) 'rotativo': '$_web/lively/m/$token/rotativo',
            },
      'puede_crear': true,
      'rotativo': {'desbloqueado': rotating.contains(id), 'precio': 200},
    };
  }

  http.Response handle(http.Request req) {
    requests.add('${req.method} ${req.url.path}');
    http.Response ok(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status, headers: _json);

    if (req.url.path == '/api/favoritos') {
      return ok({'success': true, 'favoritos': favorites});
    }
    final match = RegExp(r'^/api/favoritos/(\d+)/fondo(/\w+)?$').firstMatch(req.url.path);
    if (match == null) return ok({'message': 'No existe'}, 404);
    final id = int.parse(match[1]!);
    switch ((req.method, match[2])) {
      case ('POST', null):
        final created = !tokens.containsKey(id);
        tokens[id] ??= 'tok${id}aaaaaaaaaaaaaaaaaaaa';
        return ok(fondo(id), created ? 201 : 200);
      case ('POST', '/regenerar'):
        tokens[id] = 'nuevo${id}bbbbbbbbbbbbbbbbbbbb';
        return ok(fondo(id));
      case ('POST', '/rotativo'):
        rotating.add(id);
        return ok({...fondo(id), 'saldo': 300});
      default:
        return ok(fondo(id));
    }
  }
}

void main() {
  late _FakeServer server;
  late List<MethodCall> calls;
  late bool supported;
  late bool active;
  late bool pickerOpens;
  late Map<String, Object?>? saved;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    coinBalance.value = null;
    server = _FakeServer();
    calls = [];
    supported = true;
    active = false;
    pickerOpens = true;
    saved = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isSupported':
          return supported;
        case 'isActive':
          return active;
        case 'current':
          return saved;
        case 'configure':
          final args = call.arguments as Map;
          saved = {'favorito': args['favorito'], 'modo': args['modo']};
          return true;
        case 'openPicker':
          return pickerOpens;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> openSheet(WidgetTester tester, {VoidCallback? onCreateFavorite}) async {
    final api = ApiClient(
      baseUrl: '$_web/api',
      httpClient: MockClient((req) async => server.handle(req)),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showWallpaperSheet(
              context,
              onCreateFavorite: onCreateFavorite ?? () {},
              favorites: FavoritesService(api: api),
              links: WallpaperLinksService(api: api),
              wallpaper: LiveWallpaper(channel: _channel, android: true, webBase: _web),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  List<MethodCall> nativeCalls(String method) =>
      [for (final call in calls) if (call.method == method) call];

  testWidgets('crea el enlace, lo pasa al servicio y abre el selector', (tester) async {
    await openSheet(tester);

    expect(find.text('Casa'), findsOneWidget);
    await tester.tap(find.text('Profesional'));
    await tester.pump();
    await tester.tap(find.text('Poner de fondo'));
    await tester.pumpAndSettle();

    expect(server.requests, contains('POST /api/favoritos/3/fondo'));
    expect(nativeCalls('configure').single.arguments, {
      'url': '$_web/lively/m/tok3aaaaaaaaaaaaaaaaaaaa/profesional',
      'favorito': 3,
      'modo': 'profesional',
    });
    expect(nativeCalls('openPicker'), hasLength(1));
    expect(find.text('🌌 Fondo animado'), findsNothing);
  });

  testWidgets('si ya es el fondo, solo cambia lo que muestra', (tester) async {
    server.tokens[3] = 'tok3aaaaaaaaaaaaaaaaaaaa';
    active = true;
    await openSheet(tester);

    await tester.tap(find.text('Actualizar el fondo'));
    await tester.pumpAndSettle();

    expect(server.requests, isNot(contains('POST /api/favoritos/3/fondo')));
    expect(nativeCalls('configure'), hasLength(1));
    expect(nativeCalls('openPicker'), isEmpty);
    expect(find.text('Fondo animado: Casa · Básico'), findsOneWidget);
  });

  testWidgets('abre en el lugar y el modo que ya están puestos', (tester) async {
    server.tokens[9] = 'tok9aaaaaaaaaaaaaaaaaaaa';
    saved = {'favorito': 9, 'modo': 'astronomico'};
    await openSheet(tester);

    expect(find.text('Playa'), findsOneWidget);
    expect(find.text('Casa'), findsNothing);
    await tester.tap(find.text('Poner de fondo'));
    await tester.pumpAndSettle();

    expect(
      (nativeCalls('configure').single.arguments as Map)['url'],
      '$_web/lively/m/tok9aaaaaaaaaaaaaaaaaaaa/astronomico',
    );
  });

  testWidgets('el rotativo con 🔒 se desbloquea y queda elegido', (tester) async {
    server.tokens[3] = 'tok3aaaaaaaaaaaaaaaaaaaa';
    await openSheet(tester);

    await tester.tap(find.text('Rotativo · 🔒 200 ✨'));
    await tester.pumpAndSettle();
    expect(find.text('¿Desbloquear el modo rotativo por 200 ✨?'), findsOneWidget);
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();

    expect(server.requests, contains('POST /api/favoritos/3/fondo/rotativo'));
    expect(coinBalance.value, 300);
    expect(find.text('Rotativo'), findsOneWidget);

    await tester.tap(find.text('Poner de fondo'));
    await tester.pumpAndSettle();
    expect(
      (nativeCalls('configure').single.arguments as Map)['url'],
      '$_web/lively/m/tok3aaaaaaaaaaaaaaaaaaaa/rotativo',
    );
  });

  testWidgets('al regenerar, el fondo de ese lugar sigue con el enlace nuevo', (tester) async {
    server.tokens[3] = 'tok3aaaaaaaaaaaaaaaaaaaa';
    saved = {'favorito': 3, 'modo': 'profesional'};
    active = true;
    await openSheet(tester);

    await tester.tap(find.text('Regenerar el enlace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regenerar'));
    await tester.pumpAndSettle();

    expect(server.requests, contains('POST /api/favoritos/3/fondo/regenerar'));
    expect(nativeCalls('configure').single.arguments, {
      'url': '$_web/lively/m/nuevo3bbbbbbbbbbbbbbbbbbbb/profesional',
      'favorito': 3,
      'modo': 'profesional',
    });
    expect(find.text('Enlace nuevo listo. El anterior ya no funciona.'), findsOneWidget);
  });

  testWidgets('si el teléfono no abre el selector, lo explica', (tester) async {
    pickerOpens = false;
    await openSheet(tester);

    await tester.tap(find.text('Poner de fondo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Búscalo en Ajustes'), findsOneWidget);
    expect(find.text('🌌 Fondo animado'), findsOneWidget);
  });

  testWidgets('sin favoritos lleva a guardar uno', (tester) async {
    server.favorites = [];
    var created = 0;
    await openSheet(tester, onCreateFavorite: () => created++);

    await tester.tap(find.text('Guardar un favorito'));
    await tester.pumpAndSettle();

    expect(created, 1);
    expect(find.text('🌌 Fondo animado'), findsNothing);
  });

  testWidgets('sin soporte de fondos animados no llama al servidor', (tester) async {
    supported = false;
    await openSheet(tester);

    expect(find.text('Tu teléfono no admite fondos animados.'), findsOneWidget);
    expect(server.requests, isEmpty);
  });
}
