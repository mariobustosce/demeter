import 'dart:convert';

import 'package:demeter/screens/cielos_screen.dart';
import 'package:demeter/screens/observatorio_tab.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/astral_chart_service.dart';
import 'package:demeter/services/coin_balance.dart';
import 'package:demeter/services/observatorio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _estudio(int id, String titulo, {bool activo = true, bool renovable = false}) => {
      'id': id,
      'titulo': titulo,
      'activo': activo,
      'desde': '2026-01-15',
      'expira': '2027-01-15T12:00:00+00:00',
      'renovable': renovable,
      'capturas': 40,
    };

Map<String, dynamic> _observatorio({int precio = 100}) => {
      'success': true,
      'saldo': 500,
      'precios': {'estudio_anual': precio, 'descarga': 25},
      'lugares': [
        {
          'favorito_id': 1,
          'titulo': 'Casa',
          'lat': -33.45,
          'lon': -70.67,
          'clima': {
            'temperatura': 18.4,
            'codigo_wmo': 0,
            'es_de_dia': true,
            'viento_kmh': 12,
            'humedad_pct': 60,
            'precipitacion_mm': 0,
            'reserva': true,
          },
          'estudio': null,
        },
        {'favorito_id': 2, 'titulo': 'Cerro', 'clima': null, 'estudio': _estudio(7, 'Cerro', renovable: true)},
        {
          'favorito_id': 3,
          'titulo': 'Valle',
          'clima': null,
          'estudio': _estudio(8, 'Valle', activo: false, renovable: true),
        },
      ],
      'huerfanos': [_estudio(9, 'Viejo', activo: false)],
    };

void main() {
  late List<http.Request> pedidos;
  late int estadoPago;
  late int precio;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    coinBalance.value = null;
    pedidos = [];
    estadoPago = 200;
    precio = 100;
  });

  ApiClient api() => ApiClient(
        baseUrl: 'https://windowsdemeter.com/api',
        httpClient: MockClient((req) async {
          pedidos.add(req);
          if (req.method == 'GET' && req.url.path == '/api/observatorio') {
            return http.Response(jsonEncode(_observatorio(precio: precio)), 200, headers: _json);
          }
          if (req.method == 'GET') {
            return http.Response(jsonEncode({'status': 'success', 'data': []}), 200, headers: _json);
          }
          if (estadoPago != 200) {
            return http.Response(
              jsonEncode({'success': false, 'message': 'Te falta Polvo Estelar: el Estudio del cielo cuesta 100 ✨ y tienes 5.'}),
              estadoPago,
              headers: _json,
            );
          }
          return http.Response(
            jsonEncode({'success': true, 'saldo': 400, 'estudio': _estudio(11, 'Casa')}),
            200,
            headers: _json,
          );
        }),
      );

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: CielosScreen(service: ObservatorioService(api: api()))));
    await frames(tester);
  }

  testWidgets('una tarjeta por favorito con el pie según su estudio', (tester) async {
    await abrir(tester);

    expect(coinBalance.value, 500);
    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('18°'), findsOneWidget);
    expect(find.text('clima de reserva'), findsOneWidget);
    // Sin clima, la tarjeta igual, con guiones.
    expect(find.text('—°'), findsNWidgets(2));

    // Sin estudio, activo y en pausa.
    expect(find.text('Estudiar este cielo · 100 ✨/año'), findsOneWidget);
    expect(find.text('Estudio activo · vence 15/01/2027'), findsOneWidget);
    expect(find.text('Ver estudio'), findsOneWidget);
    expect(find.text('Estudio en pausa · lo capturado queda'), findsNWidgets(2));
    expect(find.text('Renovar · 100 ✨'), findsNWidgets(2));

    // El huérfano: se lee, no se renueva.
    expect(find.text('El lugar ya no está en tus favoritos'), findsOneWidget);
    expect(find.text('Ver lo capturado'), findsNWidgets(2));
  });

  testWidgets('con el precio en 0 los botones van sin precio', (tester) async {
    precio = 0;
    await abrir(tester);

    expect(find.text('Estudiar este cielo'), findsOneWidget);
    expect(find.text('Renovar'), findsNWidgets(2));
    expect(find.textContaining('✨/año'), findsNothing);
  });

  testWidgets('contratar pide confirmación y deja el saldo de la respuesta', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Estudiar este cielo · 100 ✨/año'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cuesta 100 ✨. ¿Contratar?'), findsOneWidget);
    await tester.tap(find.text('Contratar'));
    await frames(tester);

    final pago = pedidos.lastWhere((r) => r.method == 'POST');
    expect(pago.url.path, '/api/favoritos/1/estudio');
    expect(coinBalance.value, 400);
    expect(find.text('Estudiar este cielo · 100 ✨/año'), findsNothing);
    expect(find.text('Ver estudio'), findsNWidgets(2));
  });

  testWidgets('renovar llama a la ruta del estudio', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Renovar · 100 ✨').first);
    await tester.pumpAndSettle();
    expect(find.text('Renovar suma un año más de capturas por 100 ✨. ¿Renovar?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Renovar'));
    await frames(tester);

    expect(pedidos.lastWhere((r) => r.method == 'POST').url.path, '/api/estudios/7/renovar');
    expect(coinBalance.value, 400);
  });

  testWidgets('un 422 muestra el mensaje y no toca el saldo', (tester) async {
    estadoPago = 422;
    await abrir(tester);

    await tester.tap(find.text('Estudiar este cielo · 100 ✨/año'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contratar'));
    await frames(tester);

    expect(find.text('Te falta Polvo Estelar: el Estudio del cielo cuesta 100 ✨ y tienes 5.'), findsOneWidget);
    expect(coinBalance.value, 500);
  });

  testWidgets('el Observatorio va y vuelve entre Cielos y Firmamentos', (tester) async {
    final cliente = api();
    await tester.pumpWidget(MaterialApp(
      home: ObservatorioTab(
        observatorio: ObservatorioService(api: cliente),
        cartas: AstralChartService(api: cliente),
      ),
    ));
    await frames(tester);
    expect(find.text('Cielos'), findsOneWidget);

    await tester.tap(find.text('🌟 Firmamentos'));
    await frames(tester);
    expect(find.text('Firmamentos'), findsOneWidget);
    expect(find.text('Aún no tienes firmamentos'), findsOneWidget);

    await tester.tap(find.text('🔭 Cielos'));
    await frames(tester);
    expect(find.text('Cielos'), findsOneWidget);
  });
}
