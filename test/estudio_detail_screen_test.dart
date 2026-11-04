import 'dart:convert';

import 'package:demeter/models/estudio_detalle.dart';
import 'package:demeter/models/observatorio.dart';
import 'package:demeter/screens/estudio_detail_screen.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/observatorio_service.dart';
import 'package:demeter/widgets/observatorio/rango_diario.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _cabecera({bool activo = true}) => {
      'success': true,
      'estudio': {
        'id': 7,
        'titulo': 'Cerro',
        'activo': activo,
        'desde': '2026-10-01',
        'expira': '2027-10-01T12:00:00+00:00',
        'renovable': false,
        'capturas': 120,
        'lat': -33.45,
        'lon': -70.67,
        'primera_captura': '2026-10-01',
        'ultima_captura': '2026-11-03',
      },
    };

Map<String, dynamic> _dia(String fecha, {double? tmax, double? tmin, List<double>? normal, double? anomalia, double? lluvia}) =>
    {
      'fecha': fecha,
      'n': tmax == null ? 0 : 4,
      'tmax': tmax,
      'tmin': tmin,
      'lluvia': lluvia,
      'lluvia_aprox': false,
      'pr': 1012.0,
      'normal': normal,
      'anomalia': anomalia,
    };

Map<String, dynamic> _resumen({bool conNormal = true}) => {
      'success': true,
      'dias_ventana': 14,
      'hay_clima': true,
      'cobertura': {'n': 50, 'total': 56, 'pct': 89},
      'normal': conNormal ? {'desde': 1991, 'hasta': 2020} : null,
      'kpis': {
        'max': {'v': 24.5, 'fecha': 'lun 2 nov · tarde'},
        'min': {'v': 6.0, 'fecha': 'jue 29 oct · noche'},
        'lluvia': {'mm': 3.2, 'dias': 2, 'aprox': true},
        'presion': {'delta': -2.1, 'dir': 'baja', 'hpa': 1012},
      },
      'resumen': 'Últimos 14 días: más cálido que lo normal para la época (+1,8 °C), sin lluvia.',
      'dias': [
        _dia('2026-11-01', tmax: 22, tmin: 8, normal: conNormal ? [7, 20] : null, anomalia: conNormal ? 1.5 : null),
        _dia('2026-11-02'),
        _dia('2026-11-03', tmax: 24.5, tmin: 9, normal: conNormal ? [7, 20.5] : null, anomalia: conNormal ? 3 : null, lluvia: 1.2),
      ],
    };

Map<String, dynamic> _captura(String fecha, String turno, String hora, {Map<String, dynamic>? clima, bool pluton = false}) => {
      'fecha_local': fecha,
      'turno': turno,
      'capturado_utc': '${fecha}T10:03:00+00:00',
      'hora_local': hora,
      'estacion': 'primavera',
      'punto_rocio': 5.2,
      'clima': clima,
      'astro': {
        'tz': 'America/Santiago',
        'off': -10800,
        'cuerpos': {
          'sun': {'lon': 220.5, 'sg': 7, 'az': 80, 'alt': 25.4, 'sh': 1, 'r': 0, 'v': 1},
          'moon': {'lon': 100, 'sg': 3, 'az': 200, 'alt': -10, 'sh': 0, 'r': 0, 'v': 13},
          'mercury': {'lon': 230, 'sg': 7, 'az': 85, 'alt': 30, 'sh': 1, 'r': 1, 'v': -0.5},
          if (pluton) 'pluto': {'lon': 301, 'sg': 10, 'az': 100, 'alt': 40, 'sh': 1, 'r': 0, 'v': 0.01},
        },
      },
    };

void main() {
  late List<http.Request> pedidos;
  late bool conNormal;
  late bool activo;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    pedidos = [];
    conNormal = true;
    activo = true;
  });

  ObservatorioService service() => ObservatorioService(
        api: ApiClient(
          baseUrl: 'https://windowsdemeter.com/api',
          httpClient: MockClient((req) async {
            pedidos.add(req);
            final p = req.url.path;
            Object body;
            if (p.endsWith('/resumen')) {
              body = _resumen(conNormal: conNormal);
            } else if (p.endsWith('/capturas')) {
              final pagina = req.url.queryParameters['page'] ?? '1';
              body = {
                'success': true,
                'capturas': pagina == '1'
                    ? [
                        _captura('2026-11-03', 'tarde', '19:02',
                            clima: {'t': 18.5, 'h': 55, 'vv': 12, 'pp': 0, 'pr': 1012, 'wmo': 1, 'dia': 1, 'uv': 7, 'st': 17.9, 'vr': 30, 'p6': 0.4},
                            pluton: true),
                        _captura('2026-11-03', 'dia', '13:01',
                            clima: {'t': 24.5, 'h': 40, 'vv': 20, 'pp': 0, 'pr': 1013, 'wmo': 0, 'dia': 1, 'uv': 7}),
                        _captura('2026-11-03', 'manana', '07:03'),
                        _captura('2026-11-03', 'noche', '01:00',
                            clima: {'t': 9, 'h': 80, 'vv': 3, 'pp': 0.2, 'pr': 1014, 'wmo': 3, 'dia': 0, 'uv': 7}),
                      ]
                    : [
                        _captura('2026-11-02', 'tarde', '19:00',
                            clima: {'t': 16, 'h': 50, 'vv': 8, 'pp': 0, 'pr': 1011, 'wmo': 2, 'dia': 1}),
                      ],
                'paginacion': {'pagina': int.parse(pagina), 'por_pagina': 50, 'total': 5, 'ultima_pagina': 2},
              };
            } else {
              body = _cabecera(activo: activo);
            }
            return http.Response(jsonEncode(body), 200, headers: _json);
          }),
        ),
      );

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: EstudioDetailScreen(
        estudio: const Estudio(id: 7, titulo: 'Cerro'),
        service: service(),
      ),
    ));
    await frames(tester);
  }

  testWidgets('cabecera, resumen y KPI', (tester) async {
    await abrir(tester);

    expect(pedidos.map((r) => r.url.path).toSet(),
        {'/api/estudios/7', '/api/estudios/7/resumen', '/api/estudios/7/capturas'});
    expect(find.text('Cerro'), findsOneWidget);
    expect(find.textContaining('01/10/2026 – 03/11/2026'), findsOneWidget);
    expect(find.textContaining('120 capturas'), findsOneWidget);
    expect(find.textContaining('renueva para reanudar'), findsNothing);

    expect(find.text('Últimos 14 días: más cálido que lo normal para la época (+1,8 °C), sin lluvia.'), findsOneWidget);
    expect(find.text('24,5 °C'), findsNWidgets(2)); // KPI y turno de día
    expect(find.text('lun 2 nov · tarde'), findsOneWidget);
    expect(find.text('aprox. 3,2 mm'), findsOneWidget);
    expect(find.text('2 días con lluvia'), findsOneWidget);
    expect(find.text('↓ bajando'), findsOneWidget);
    expect(find.text('-2,1 hPa · ahora 1012 hPa'), findsOneWidget);
    expect(find.text('50 de 56 turnos con clima (89 %)'), findsOneWidget);
    expect(find.text('La normal del lugar aún se está calculando.'), findsNothing);
  });

  testWidgets('en pausa avisa, pero no bloquea nada', (tester) async {
    activo = false;
    await abrir(tester);

    expect(find.textContaining('renueva para reanudar la captura'), findsOneWidget);
    expect(find.text('Mañana (07:03)'), findsOneWidget);
  });

  testWidgets('capturas por día y turno; UV una vez y sin clima con guiones', (tester) async {
    await abrir(tester);

    expect(find.text('03/11/2026'), findsOneWidget);
    expect(find.text('🌸 Primavera'), findsOneWidget);
    // En orden de hora dentro del día.
    final noche = tester.getTopLeft(find.text('Noche (01:00)')).dy;
    final manana = tester.getTopLeft(find.text('Mañana (07:03)')).dy;
    final tarde = tester.getTopLeft(find.text('Tarde (19:02)')).dy;
    expect(noche < manana && manana < tarde, isTrue);

    // El UV va una vez por día, no en las filas (tampoco en la de noche).
    expect(find.text('UV máx. del día 7'), findsOneWidget);
    expect(find.textContaining('UV máx.'), findsOneWidget);

    // Datos nuevos (sensación, ráfagas, lluvia de 6 h) y viejos (lluvia del instante).
    expect(find.text('ST 17,9°'), findsOneWidget);
    expect(find.text('12 km/h · ráf. 30'), findsOneWidget);
    expect(find.text('0,4 mm 6 h'), findsOneWidget);
    expect(find.text('0,2 mm'), findsOneWidget);
    expect(find.text('rocío 5,2°'), findsWidgets);

    expect(find.text('— sin clima'), findsOneWidget);
  });

  testWidgets('cargar más pide la página siguiente', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Cargar más'));
    await frames(tester);

    expect(pedidos.last.url.queryParameters['page'], '2');
    expect(find.text('02/11/2026'), findsOneWidget);
    expect(find.text('Cargar más'), findsNothing);
  });

  testWidgets('astros por captura, con Plutón si viene', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Astros por captura'));
    await tester.pumpAndSettle();

    expect(find.text('♇\u{FE0E}'), findsOneWidget);
    // Quirón no viene en ninguna captura: sin columna.
    expect(find.text('⚷\u{FE0E}'), findsNothing);
    expect(find.textContaining('25°'), findsWidgets);
    expect(find.textContaining('℞'), findsWidgets);
    // Plutón falta en las capturas viejas: «—».
    expect(find.text('—'), findsWidgets);
  });

  group('rango diario', () {
    testWidgets('con normal pinta la banda y marca la anomalía', (tester) async {
      final r = ResumenEstudio.fromJson(_resumen());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: RangoDiario(dias: r.dias))));
      final pintor = find.descendant(of: find.byType(RangoDiario), matching: find.byType(CustomPaint));
      // Una banda de normal, dos barras con dato y la lluvia de un día.
      expect(tester.renderObject(pintor.first), paints..path()..rrect()..rrect()..rect());
      expect(tonoAnomalia(3), kTonoCalido);
      expect(tonoAnomalia(-1.2), kTonoFresco);
      expect(tonoAnomalia(0.5), kTonoNormal);
      expect(anomaliaConSigno(-1.25), '−1,3');
    });

    testWidgets('sin normal no hay banda y la pantalla lo avisa', (tester) async {
      final r = ResumenEstudio.fromJson(_resumen(conNormal: false));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: RangoDiario(dias: r.dias))));
      final pintor = find.descendant(of: find.byType(RangoDiario), matching: find.byType(CustomPaint));
      expect(tester.renderObject(pintor.first), isNot(paints..path()));

      conNormal = false;
      await abrir(tester);
      expect(find.text('La normal del lugar aún se está calculando.'), findsOneWidget);
    });
  });
}
