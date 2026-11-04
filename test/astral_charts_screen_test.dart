import 'dart:convert';

import 'package:demeter/models/carta.dart';
import 'package:demeter/screens/astral_charts_screen.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/astral_chart_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

// Con los tipos que manda el servidor: coordenadas y grados como textos.
Map<String, dynamic> cartaJson(int id, String titulo, {bool revisar = false}) => {
      'id': id,
      'user_id': 7,
      'titulo': titulo,
      'birth_date': '2021-04-07T00:00:00.000000Z',
      'birth_time': '12:33',
      'birth_lat': '-33.4489000',
      'birth_lon': '-70.6693000',
      'timezone': revisar ? 'UTC' : 'America/Santiago',
      'tz_offset': revisar ? 0 : -14400,
      'tz_revisar': revisar,
      'sun_degree': '17.92',
    };

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
  });

  AstralChartService service(List<Map<String, dynamic>> cartas) => AstralChartService(
        api: ApiClient(
          baseUrl: 'https://windowsdemeter.com/api',
          httpClient: MockClient((req) async => http.Response(
                jsonEncode({'status': 'success', 'data': cartas}),
                200,
                headers: _json,
              )),
        ),
      );

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('el distintivo «revisar zona» sale solo con tz_revisar', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AstralChartsScreen(
        service: service([cartaJson(1, 'Original', revisar: true), cartaJson(2, 'Corregida')]),
      ),
    ));
    await frames(tester);

    expect(find.text('Firmamentos'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Corregida'), findsOneWidget);
    expect(find.text('🕐 revisar zona'), findsOneWidget);
    expect(find.text('Sol en Aries'), findsNWidgets(2));
    expect(find.text('Nuevo firmamento'), findsOneWidget);
    // Ya no hay datos inventados ni el botón muerto.
    expect(find.text('Ver en Dashboard'), findsNothing);
    expect(find.text('Planetas Principales'), findsNothing);
  });

  testWidgets('sin firmamentos muestra el estado vacío', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AstralChartsScreen(service: service([]))));
    await frames(tester);

    expect(find.text('Aún no tienes firmamentos'), findsOneWidget);
  });

  test('Carta.fromJson convierte los textos decimales', () {
    final c = Carta.fromJson(cartaJson(1, 'x', revisar: true))!;
    expect(c.lat, -33.4489);
    expect(c.birthDate, '2021-04-07');
    expect(c.tzRevisar, isTrue);
    expect(c.sunSign, 0);
    expect(Carta.fromJson({'titulo': 'sin id'}), isNull);
  });
}
