import 'dart:convert';

import 'package:demeter/screens/create_astral_chart_screen.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/astral_chart_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

void main() {
  late List<http.Request> requests;
  late bool zonaFalla;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    requests = [];
    zonaFalla = false;
  });

  AstralChartService service() => AstralChartService(
        api: ApiClient(
          baseUrl: 'https://windowsdemeter.com/api',
          httpClient: MockClient((req) async {
            requests.add(req);
            if (req.url.path.endsWith('/user/zona')) {
              if (zonaFalla) return http.Response('{"message":"x"}', 500, headers: _json);
              return http.Response(
                jsonEncode({
                  'success': true,
                  'timezone': 'America/Santiago',
                  'desfase': -14400,
                  'rotulo': 'UTC−04:00',
                  'horario_verano': false,
                }),
                200,
                headers: _json,
              );
            }
            return http.Response(
              jsonEncode({'success': true, 'message': 'Firmamento creado.', 'data': {}}),
              201,
              headers: _json,
            );
          }),
        ),
      );

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // Monta el alta sobre otra ruta para que el `pop` tras guardar tenga adónde volver.
  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreateAstralChartScreen(service: service())),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  TextEditingController campo(WidgetTester tester, String hint) =>
      tester.widget<TextField>(find.widgetWithText(TextField, hint)).controller!;

  // Fecha y hora son de solo lectura (abren selectores): se rellenan directo.
  Future<void> rellenar(WidgetTester tester) async {
    await tester.enterText(
        find.widgetWithText(TextField, 'Ej: Mi Carta Natal, Carta del Alma Gemela, etc.'), 'Mía');
    campo(tester, 'yyyy-mm-dd').text = '2021-04-07';
    campo(tester, 'HH:mm').text = '12:33';
    await tester.enterText(find.widgetWithText(TextField, '-33.4489'), '-33.4489');
    await tester.enterText(find.widgetWithText(TextField, '-70.6693'), '-70.6693');
    await frames(tester);
  }

  Future<void> guardar(WidgetTester tester) async {
    final boton = find.text('Crear firmamento');
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await frames(tester);
  }

  Map<String, dynamic> altaEnviada() {
    final alta = requests.lastWhere((r) => r.method == 'POST');
    expect(alta.url.path, '/api/user/charts');
    return jsonDecode(alta.body) as Map<String, dynamic>;
  }

  testWidgets('muestra la zona del lugar y el alta sin tocarla va sin timezone', (tester) async {
    await abrir(tester);
    await rellenar(tester);

    final zona = requests.lastWhere((r) => r.url.path.endsWith('/user/zona'));
    expect(zona.url.queryParameters, {
      'lat': '-33.4489',
      'lon': '-70.6693',
      'fecha': '2021-04-07',
      'hora': '12:33',
    });
    expect(find.text('America/Santiago · ese día regía UTC−04:00'), findsOneWidget);

    await guardar(tester);
    final body = altaEnviada();
    expect(body.containsKey('timezone'), isFalse);
    expect(body['birth_lat'], -33.4489);
    expect(find.text('Firmamento creado.'), findsOneWidget);
  });

  testWidgets('un cambio manual manda el nombre IANA elegido', (tester) async {
    await abrir(tester);
    await rellenar(tester);

    final cambiar = find.text('Cambiar zona');
    await tester.ensureVisible(cambiar);
    await tester.tap(cambiar);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Buscar, p. ej. Madrid'), 'madrid');
    await tester.pump();
    await tester.tap(find.text('Europe/Madrid'));
    await tester.pumpAndSettle();

    expect(find.text('Europe/Madrid · elegida a mano'), findsOneWidget);

    await guardar(tester);
    expect(altaEnviada()['timezone'], 'Europe/Madrid');
  });

  testWidgets('volver a la zona del lugar deja el alta sin timezone', (tester) async {
    await abrir(tester);
    await rellenar(tester);

    await tester.ensureVisible(find.text('Cambiar zona'));
    await tester.tap(find.text('Cambiar zona'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UTC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar la del lugar'));
    await tester.pump();

    await guardar(tester);
    expect(altaEnviada().containsKey('timezone'), isFalse);
  });

  testWidgets('si la zona falla no bloquea: guarda sin timezone', (tester) async {
    zonaFalla = true;
    await abrir(tester);
    await rellenar(tester);

    expect(find.text('No se pudo consultar la zona. Se usará la del lugar al guardar.'),
        findsOneWidget);

    await guardar(tester);
    expect(altaEnviada().containsKey('timezone'), isFalse);
  });
}
