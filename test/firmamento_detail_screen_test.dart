import 'dart:convert';
import 'dart:io';

import 'package:demeter/models/firmamento.dart';
import 'package:demeter/screens/firmamento_detail_screen.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/astral_chart_service.dart';
import 'package:demeter/widgets/firmamento/anticolision.dart';
import 'package:demeter/widgets/firmamento/rueda_natal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

// Santiago, 07/04/2021 12:33 guardada en UTC: la carta de ejemplo del prompt.
final Map<String, dynamic> _fixture =
    jsonDecode(File('test/fixtures/firmamento_santiago.json').readAsStringSync()) as Map<String, dynamic>;

Firmamento _firmamento() => Firmamento.fromJson(_fixture['firmamento'])!;

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
  });

  // Alto de sobra: el ListView construye todas las secciones sin desplazar.
  Future<void> pantallaAlta(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder filaDe(String nombre) =>
      find.ancestor(of: find.text(nombre), matching: find.byType(Row)).first;

  group('modelo', () {
    test('lee el JSON real, también house_rulers en lista y orbes en mapa', () {
      final f = _firmamento();
      expect(f.cuerpos, hasLength(14));
      expect(f.zona.revisar, isTrue);
      expect(f.zona.sugerida?.timezone, 'America/Santiago');
      expect(f.zona.sugerida?.rotulo, 'UTC−04:00');
      expect(f.natal.chartRuler?.body, 'venus');
      expect(f.natal.chartRuler?.dignity, 'detriment');
      expect(f.natal.secta?.type, 'diurnal');
      expect(f.luna?.rudhyar, 'last_quarter');
      expect(f.cuerpo('mars')!.fueraDeLimites, isTrue);
      expect(f.natal.regentesCasas, hasLength(12));
      expect(f.orbes, hasLength(7));
      expect(f.aspectos.any((a) => a.une('mars', 'node_north')), isFalse);
      expect(f.figuras.map((x) => x.tipo), ['angular', 'small_grand_trine']);
    });
  });

  group('anticolisión', () {
    test('los 14 cuerpos quedan a la separación mínima o más', () {
      final layout = RuedaLayout(_firmamento(), 360);
      final pos = layout.pos;
      expect(pos, hasLength(14));
      for (var i = 0; i < pos.length; i++) {
        for (var j = i + 1; j < pos.length; j++) {
          expect(distanciaAngular(pos[i], pos[j]), greaterThanOrEqualTo(kSeparacionGlifos - 1e-6),
              reason: '${layout.f.cuerpos[i].clave} y ${layout.f.cuerpos[j].clave}');
        }
      }
    });

    test('un grupo apretado se separa sin perder su centro', () {
      final pos = separarGlifos([100, 101, 102]);
      expect(distanciaAngular(pos[0], pos[1]), closeTo(12.5, 1e-9));
      expect(distanciaAngular(pos[1], pos[2]), closeTo(12.5, 1e-9));
      expect((pos[0] + pos[1] + pos[2]) / 3, closeTo(101, 1e-9));
      // El orden se conserva.
      expect(pos[0] < pos[1] && pos[1] < pos[2], isTrue);
    });
  });

  testWidgets('la rueda pinta los 14 cuerpos', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: 360, child: RuedaNatal(firmamento: _firmamento()))),
    ));
    final pintor = find.descendant(of: find.byType(RuedaNatal), matching: find.byType(CustomPaint));
    // Fondo, borde, anillo, centro y un disco con borde por cuerpo.
    expect(tester.renderObject(pintor.first), paintsExactlyCountTimes(#drawCircle, 4 + 14 * 2));
  });

  testWidgets('con el fixture muestra lo que lee un astrólogo', (tester) async {
    await pantallaAlta(tester);
    await tester.pumpWidget(MaterialApp(
      home: FirmamentoDetailScreen(cartaId: 1, inicial: FirmamentoDetalle(firmamento: _firmamento())),
    ));
    await frames(tester);

    // Cuadratura angular y pequeño gran trígono (en Dominantes y en Figuras).
    expect(find.textContaining('CUADRATURA FIJA ANGULAR'), findsNWidgets(2));
    expect(find.text('PEQUEÑO GRAN TRÍGONO'), findsNWidgets(2));
    expect(find.text('Saturno/MC – Urano/AC'), findsOneWidget);
    expect(find.textContaining('asociados por conjunción: Sol, Luna'), findsOneWidget);

    // Venus en exilio y Marte fuera de límites.
    expect(find.descendant(of: filaDe('Venus'), matching: find.text('Exilio')), findsOneWidget);
    expect(find.descendant(of: filaDe('Marte'), matching: find.text('OOB')), findsOneWidget);

    // Regente, secta, fase lunar y aviso de zona.
    expect(find.textContaining('Venus en Aries, casa XII, exilio'), findsOneWidget);
    expect(find.textContaining('Carta diurna'), findsOneWidget);
    expect(find.text('Cuarto menguante'), findsOneWidget);
    expect(find.textContaining('regía America/Santiago, UTC−04:00'), findsOneWidget);

    // Luna sextil Venus a 4°45′, y ningún Marte–Nodo Norte.
    expect(find.text('Luna sextil Venus'), findsOneWidget);
    expect(find.textContaining('Marte trígono Nodo Norte'), findsNothing);
  });

  testWidgets('la grilla y el filtro de aspectos', (tester) async {
    await pantallaAlta(tester);
    await tester.pumpWidget(MaterialApp(
      home: FirmamentoDetailScreen(cartaId: 1, inicial: FirmamentoDetalle(firmamento: _firmamento())),
    ));
    await frames(tester);

    // Apagar los sextiles quita la fila de la lista.
    await tester.tap(find.textContaining(' sextil · '));
    await tester.pump();
    expect(find.text('Luna sextil Venus'), findsNothing);
    await tester.tap(find.textContaining(' sextil · '));
    await tester.pump();
    expect(find.text('Luna sextil Venus'), findsOneWidget);

    await tester.tap(find.text('Grilla'));
    await tester.pump();
    // La celda Venus–Marte: orbe y separativo.
    expect(find.text('0°40′s'), findsOneWidget);
  });

  testWidgets('pide el detalle por id y usa la carta para la cabecera', (tester) async {
    await pantallaAlta(tester);
    final pedidos = <String>[];
    final service = AstralChartService(
      api: ApiClient(
        baseUrl: 'https://windowsdemeter.com/api',
        httpClient: MockClient((req) async {
          pedidos.add(req.url.path);
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': {
                'carta_astral': {
                  'id': 5,
                  'titulo': 'Ejemplo',
                  'birth_date': '2021-04-07T00:00:00.000000Z',
                  'birth_time': '12:33',
                  'birth_lat': '-33.4489000',
                  'birth_lon': '-70.6693000',
                  'timezone': 'UTC',
                },
                'firmamento': _fixture['firmamento'],
              },
            }),
            200,
            headers: _json,
          );
        }),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: FirmamentoDetailScreen(cartaId: 5, service: service)));
    await frames(tester);

    expect(pedidos, ['/api/user/charts/5']);
    expect(find.text('Ejemplo'), findsOneWidget);
    expect(find.textContaining('07/04/2021 12:33'), findsOneWidget);
  });

  group('recalcular con la zona del lugar', () {
    // Lo que responde el servidor tras corregir la zona.
    Map<String, dynamic> corregido() {
      final f = jsonDecode(jsonEncode(_fixture['firmamento'])) as Map<String, dynamic>;
      f['zona'] = {
        'timezone': 'America/Santiago',
        'desfase': -14400,
        'rotulo': 'UTC−04:00',
        'horario_verano': false,
        'revisar': false,
        'sugerida': null,
      };
      return f;
    }

    late List<http.Request> pedidos;
    late int estado;

    AstralChartService service() => AstralChartService(
          api: ApiClient(
            baseUrl: 'https://windowsdemeter.com/api',
            httpClient: MockClient((req) async {
              pedidos.add(req);
              if (estado != 200) {
                return http.Response(jsonEncode({'success': false, 'message': 'Zona no válida.'}), estado,
                    headers: _json);
              }
              return http.Response(
                jsonEncode({
                  'success': true,
                  'message': 'Zona corregida a America/Santiago.',
                  'data': {'firmamento': corregido()},
                }),
                200,
                headers: _json,
              );
            }),
          ),
        );

    setUp(() {
      pedidos = [];
      estado = 200;
    });

    Future<void> abrirYConfirmar(WidgetTester tester) async {
      await pantallaAlta(tester);
      await tester.pumpWidget(MaterialApp(
        home: FirmamentoDetailScreen(
          cartaId: 3,
          inicial: FirmamentoDetalle(firmamento: _firmamento()),
          service: service(),
        ),
      ));
      await frames(tester);
      await tester.tap(find.text('Recalcular con America/Santiago'));
      await tester.pumpAndSettle();
      expect(find.text('El Ascendente y las casas van a cambiar. ¿Recalcular?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Recalcular'));
      await frames(tester);
    }

    testWidgets('manda el nombre IANA y repinta con la respuesta', (tester) async {
      await abrirYConfirmar(tester);

      expect(pedidos, hasLength(1));
      expect(pedidos.single.method, 'PATCH');
      expect(pedidos.single.url.path, '/api/user/charts/3/zona');
      expect(jsonDecode(pedidos.single.body), {'timezone': 'America/Santiago'});

      // Ya no hay aviso y se ve el mensaje del servidor.
      expect(find.textContaining('regía America/Santiago'), findsNothing);
      expect(find.text('Zona corregida a America/Santiago.'), findsOneWidget);
      expect(find.textContaining('America/Santiago (UTC−04:00)'), findsWidgets);
    });

    testWidgets('cancelar no manda nada', (tester) async {
      await pantallaAlta(tester);
      await tester.pumpWidget(MaterialApp(
        home: FirmamentoDetailScreen(
          cartaId: 3,
          inicial: FirmamentoDetalle(firmamento: _firmamento()),
          service: service(),
        ),
      ));
      await frames(tester);
      await tester.tap(find.text('Recalcular con America/Santiago'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(pedidos, isEmpty);
    });

    testWidgets('un 422 muestra el mensaje y deja el aviso', (tester) async {
      estado = 422;
      await abrirYConfirmar(tester);

      expect(find.text('Zona no válida.'), findsOneWidget);
      expect(find.textContaining('regía America/Santiago'), findsOneWidget);
      // El botón vuelve a estar activo.
      final boton = tester.widget<OutlinedButton>(
          find.ancestor(of: find.text('Recalcular con America/Santiago'), matching: find.byType(OutlinedButton)));
      expect(boton.onPressed, isNotNull);
    });
  });

  testWidgets('un 404 es «no existe»', (tester) async {
    final service = AstralChartService(
      api: ApiClient(
        baseUrl: 'https://windowsdemeter.com/api',
        httpClient: MockClient((_) async => http.Response('{"message":"No query results"}', 404, headers: _json)),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: FirmamentoDetailScreen(cartaId: 9, service: service)));
    await frames(tester);

    expect(find.text('Ese firmamento no existe.'), findsOneWidget);
  });
}
