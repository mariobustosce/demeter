import 'dart:convert';

import 'package:demeter/models/aviso.dart';
import 'package:demeter/screens/avisos_screen.dart';
import 'package:demeter/services/alerts_service.dart';
import 'package:demeter/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes/aviso_json.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';

void main() {
  late List<http.Request> requests;
  late Set<String> read;
  late List<Map<String, Object?>> avisos;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    unreadAlerts.value = null;
    requests = [];
    read = {};
    avisos = [
      avisoJson(_a, titulo: 'Lluvia fuerte mañana'),
      avisoJson(
        _b,
        tipo: 'sismo',
        titulo: 'Sismo cerca de Casa',
        url: 'https://www.gdacs.org/report.aspx?eventid=1',
        fuente: 'GDACS',
      ),
    ];
  });

  AlertsService service() => AlertsService(
        api: ApiClient(
          baseUrl: 'https://windowsdemeter.com/api',
          httpClient: MockClient((req) async {
            requests.add(req);
            final leido = RegExp(r'^/api/avisos/([0-9a-f-]+)/leido$').firstMatch(req.url.path);
            if (leido != null) read.add(leido[1]!);
            final list = [
              for (final a in avisos) {...a, 'leido': read.contains(a['id'])},
            ];
            return http.Response(
              jsonEncode({
                'success': true,
                'no_leidos': list.where((a) => a['leido'] != true).length,
                'avisos': list,
              }),
              200,
              headers: _json,
            );
          }),
        ),
      );

  Future<void> pumpScreen(WidgetTester tester, {Aviso? opened}) async {
    await tester.pumpWidget(MaterialApp(
      home: AvisosScreen(alerts: service(), opened: opened),
    ));
    await tester.pumpAndSettle();
  }

  List<String> calls() => [for (final r in requests) '${r.method} ${r.url.path}'];

  testWidgets('lista los avisos con lugar, texto y si son nuevos', (tester) async {
    await pumpScreen(tester);

    expect(calls(), ['GET /api/avisos']);
    expect(find.text('Lluvia fuerte mañana'), findsOneWidget);
    expect(find.text('★ Casa'), findsNWidgets(2));
    expect(find.text('NUEVO'), findsNWidgets(2));
    expect(find.text('Para el 25-10-2026'), findsNWidgets(2));
    expect(unreadAlerts.value, 2);
  });

  testWidgets('una catástrofe lleva el aviso legal y el enlace a GDACS', (tester) async {
    await pumpScreen(tester);

    expect(find.text(kGdacsDisclaimer), findsOneWidget);
    expect(find.text('Más información en GDACS ↗'), findsOneWidget);
  });

  testWidgets('tocar uno nuevo lo marca leído', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Lluvia fuerte mañana'));
    await tester.pumpAndSettle();

    expect(calls().last, 'POST /api/avisos/$_a/leido');
    expect(find.text('NUEVO'), findsOneWidget);
    expect(unreadAlerts.value, 1);
  });

  testWidgets('el de una notificación se marca leído y va primero', (tester) async {
    await pumpScreen(
      tester,
      opened: const Aviso(id: _b, type: 'sismo', title: 'Sismo cerca de Casa'),
    );

    // Primero se marca, para que la lista llegue con la cuenta al día.
    expect(calls(), ['POST /api/avisos/$_b/leido', 'GET /api/avisos']);
    final first = tester.getTopLeft(find.text('Sismo cerca de Casa'));
    final second = tester.getTopLeft(find.text('Lluvia fuerte mañana'));
    expect(first.dy, lessThan(second.dy));
    expect(find.text('NUEVO'), findsOneWidget);
    expect(unreadAlerts.value, 1);
  });

  testWidgets('si ya venció, se ve con lo que trajo el push', (tester) async {
    await pumpScreen(
      tester,
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
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Marcar todos como leídos'));
    await tester.pumpAndSettle();

    expect(calls().last, 'POST /api/avisos/leidos');
    expect(find.text('NUEVO'), findsNothing);
    expect(unreadAlerts.value, 0);
  });

  test('cuándo llegó: hoy, ayer o la fecha', () {
    final now = DateTime(2026, 10, 24, 20);
    expect(arrivedLabel(DateTime(2026, 10, 24, 9, 5), now), 'Llegó hoy a las 09:05');
    expect(arrivedLabel(DateTime(2026, 10, 23, 23, 59), now), 'Llegó ayer a las 23:59');
    expect(arrivedLabel(DateTime(2026, 10, 2, 7, 30), now), 'Llegó el 02-10 a las 07:30');
    expect(dayLabel(DateTime(2026, 1, 5)), '05-01-2026');
  });
}
