import 'dart:convert';

import 'package:demeter/models/carta.dart';
import 'package:demeter/models/consultas.dart';
import 'package:demeter/screens/consulta_detalle_screen.dart';
import 'package:demeter/screens/consultas_screen.dart';
import 'package:demeter/services/anuncio_consulta.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/astral_chart_service.dart';
import 'package:demeter/services/coin_balance.dart';
import 'package:demeter/services/consultas_service.dart';
import 'package:demeter/services/location_service.dart';
import 'package:demeter/textos/consultas_textos.dart';
import 'package:demeter/theme/consultas_theme.dart';
import 'package:demeter/widgets/consultas/consola_consultas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

const _preguntaCampo = '¿Es buen día para cosechar?';
const _preguntaDia = '¿Cómo se presenta mi día en general?';

/// Lo mismo que devuelve `GET /api/consultas/catalogo`, recortado.
final Map<String, dynamic> _catalogoJson = {
  'success': true,
  'preguntas': {
    'oraculo': [
      {'icono': '🌅', 'titulo': 'Panorama del día', 'preguntas': [_preguntaDia]},
    ],
    'demeter': [
      {'icono': '🌾', 'titulo': 'Cosecha', 'preguntas': [_preguntaCampo]},
    ],
  },
  'cultivos': ['hierbas y aromáticas'],
  'proveedores': {
    'consulta': [
      {'clave': 'gemini', 'etiqueta': 'Gemini · Google 2.5 Flash', 'disponible': true},
      {'clave': 'groq', 'etiqueta': 'Groq', 'disponible': false},
    ],
    'compatibilidad': [
      {'clave': 'gemini', 'etiqueta': 'Gemini · Google 2.5 Flash', 'disponible': true},
    ],
  },
  'por_defecto': {'consulta': 'gemini', 'compatibilidad': 'gemini'},
  'niveles': {
    for (final (m, nombres, tokens) in [
      ('demeter', ['Básico', 'Agronómico', 'Completo'], [140, 320, 780]),
      ('oraculo', ['Básico', 'Astral', 'Divino'], [120, 350, 900]),
      ('persefone', ['Básico', 'Astral', 'Divino'], [120, 350, 900]),
    ])
      m: [
        for (final (i, clave) in ['basico', 'intermedio', 'premium'].indexed)
          {'clave': clave, 'nombre': nombres[i], 'costo': [5, 10, 20][i], 'tokens': tokens[i], 'descripcion': 'Nivel $clave'},
      ],
  },
  'nivel_por_defecto': 'basico',
  'costo_firmamento': 50,
  'tokens_firmamento': 200,
};

final _catalogo = CatalogoConsultas.fromJson(_catalogoJson);

const _cartas = [Carta(id: 1, titulo: 'Ana'), Carta(id: 2, titulo: 'Bruno')];

const _contexto = ContextoMomento(
  lugar: 'Valle Ñandú de los Andes',
  fecha: '05 Nov 2026',
  hora: '10:30',
  franjaDemeter: [
    CasillaFranja(rotulo: 'Cielo', valor: '☀️ Despejado'),
    CasillaFranja(rotulo: 'Temperatura', valor: '18°C'),
    CasillaFranja(rotulo: 'Humedad', valor: '40%'),
    CasillaFranja(rotulo: 'Viento', valor: '12 km/h'),
    CasillaFranja(rotulo: 'Lluvia hoy', valor: '10%'),
  ],
  franjaOraculo: [
    CasillaFranja(rotulo: 'Sol', valor: '☉ Escorpio', nota: '12° 03′', color: '#22c55e'),
  ],
  contextoDemeter: {'hemisferio': 'Sur'},
);

/// Sin GPS: el contexto se pide sin lat ni lon.
class _SinUbicacion extends LocationService {
  @override
  Future<RoundedLocation?> current() async => null;
}

ApiClient _api(Future<http.Response> Function(http.Request) responder) =>
    ApiClient(baseUrl: 'https://windowsdemeter.com/api', httpClient: MockClient(responder));

http.Response _ok(Object body) => http.Response(jsonEncode(body), 200, headers: _json);

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    ConsultasService.olvidarCatalogo();
    coinBalance.value = null;
  });

  Future<void> telefono(WidgetTester tester, {double alto = 800}) async {
    tester.view.physicalSize = Size(360, alto);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Sin animaciones: el fondo titila en bucle y nunca «se asienta».
  Widget envolver(Widget child) => MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        ),
      );

  Future<void> consola(
    WidgetTester tester, {
    ConsultasService? service,
    ModuloConsulta inicial = ModuloConsulta.demeter,
  }) async {
    await telefono(tester, alto: 5000);
    await tester.pumpWidget(envolver(ConsolaConsultas(
      catalogo: _catalogo,
      contexto: _contexto,
      cartas: _cartas,
      service: service ?? ConsultasService(api: _api((_) async => _ok({}))),
      anuncio: AnuncioConsulta.ninguno(),
      onCrearFirmamento: () {},
      inicial: inicial,
    )));
    await tester.pumpAndSettle();
  }

  bool habilitado(WidgetTester tester) =>
      tester.widget<InkWell>(find.byKey(const ValueKey('boton-consultar'))).onTap != null;

  String costo(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('resumen-costo'))).data!;

  String tokens(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('resumen-tokens'))).data!;

  Future<void> elegir(WidgetTester tester, Finder campo, String opcion) async {
    await tester.tap(campo);
    await tester.pumpAndSettle();
    await tester.tap(find.text(opcion).last);
    await tester.pumpAndSettle();
  }

  group('reglas del resumen', () {
    const basico = NivelConsulta(clave: 'basico', nombre: 'Básico', costo: 5, tokens: 140);

    test('costo: el firmamento suma 50', () {
      expect(costoConsulta(basico), 5);
      expect(costoConsulta(basico, conFirmamento: true, costoFirmamento: 50), 55);
    });

    test('tokens: nivel + ⌈largo/4⌉ + 200 con firmamento', () {
      expect(tokensEstimados(basico, ''), 140);
      expect(tokensEstimados(basico, 'abcde'), 142);
      expect(tokensEstimados(basico, 'abcd', conFirmamento: true, tokensFirmamento: 200), 341);
    });

    test('validez de cada módulo', () {
      expect(puedeConsultarDemeter(null), isFalse);
      expect(puedeConsultarDemeter('x'), isTrue);
      expect(puedeConsultarOraculo('x', conFirmamento: true), isFalse);
      expect(puedeConsultarOraculo('x', conFirmamento: true, cartaId: 1), isTrue);
      expect(puedeConsultarOraculo('', conFirmamento: false), isFalse);
      expect(puedeConsultarPersefone(1, 1), isFalse);
      expect(puedeConsultarPersefone(1, null), isFalse);
      expect(puedeConsultarPersefone(1, 2), isTrue);
    });
  });

  group('consola', () {
    testWidgets('Demeter va primero y por defecto, en el orden de la web', (tester) async {
      await consola(tester);

      final pestanas = [TxConsultas.moduloDemeter, TxConsultas.moduloOraculo, TxConsultas.moduloPersefone]
          .map((t) => tester.getTopLeft(find.text(t.toUpperCase())).dx)
          .toList();
      expect(pestanas, orderedEquals([...pestanas]..sort()));
      expect(find.text(TxConsultas.demeterNombre), findsOneWidget);
      expect(find.text('☀️ Despejado'), findsOneWidget);
    });

    testWidgets('Demeter: el botón se habilita al elegir la pregunta', (tester) async {
      await consola(tester);

      expect(habilitado(tester), isFalse);
      expect(find.text(TxConsultas.previewVacio), findsOneWidget);

      await elegir(tester, find.byKey(const ValueKey('selector-pregunta')), _preguntaCampo);

      expect(habilitado(tester), isTrue);
      // La vista previa trae el tema y la pregunta.
      expect(find.text('COSECHA'), findsOneWidget);
      expect(find.text(TxConsultas.previewVacio), findsNothing);
    });

    testWidgets('Demeter: costo y tokens como la web', (tester) async {
      await consola(tester);
      expect(costo(tester), '5 ✨');
      expect(tokens(tester), '~ 140 ${TxConsultas.tokensEstimados}');

      await elegir(tester, find.byKey(const ValueKey('selector-pregunta')), _preguntaCampo);
      final t = 140 + (_preguntaCampo.length / 4).ceil();
      expect(tokens(tester), '~ $t ${TxConsultas.tokensEstimados}');

      await tester.tap(find.text('COMPLETO'));
      await tester.pumpAndSettle();
      expect(costo(tester), '20 ✨');
      expect(tokens(tester), '~ ${780 + (_preguntaCampo.length / 4).ceil()} ${TxConsultas.tokensEstimados}');
    });

    testWidgets('Oráculo: con firmamento hace falta elegirlo, y cobra +50 y +200 tokens', (tester) async {
      await consola(tester, inicial: ModuloConsulta.oraculo);
      await elegir(tester, find.byKey(const ValueKey('selector-pregunta')), _preguntaDia);
      expect(habilitado(tester), isTrue);

      await tester.tap(find.text('DIVINO'));
      await tester.tap(find.byKey(const ValueKey('usar-firmamento')));
      await tester.pumpAndSettle();

      final largo = (_preguntaDia.length / 4).ceil();
      expect(costo(tester), '70 ✨');
      expect(tokens(tester), '~ ${900 + largo + 200} ${TxConsultas.tokensEstimados}');
      expect(habilitado(tester), isFalse);

      await elegir(tester, find.byKey(const ValueKey('carta-oraculo')), 'Ana');
      expect(habilitado(tester), isTrue);
      expect(find.text(TxConsultas.cieloActualMas('Ana')), findsOneWidget);
    });

    testWidgets('Perséfone: A ⇅ B intercambia y exige dos distintos', (tester) async {
      await consola(tester, inicial: ModuloConsulta.persefone);
      expect(habilitado(tester), isFalse);

      await elegir(tester, find.byKey(const ValueKey('persona-a')), 'Ana');
      await elegir(tester, find.byKey(const ValueKey('persona-b')), 'Ana');
      expect(habilitado(tester), isFalse);

      await elegir(tester, find.byKey(const ValueKey('persona-b')), 'Bruno');
      expect(habilitado(tester), isTrue);

      String campo(String clave) => tester
          .widget<Text>(find.descendant(of: find.byKey(ValueKey(clave)), matching: find.byType(Text)))
          .data!;
      expect((campo('persona-a'), campo('persona-b')), ('Ana', 'Bruno'));

      await tester.tap(find.byKey(const ValueKey('intercambiar')));
      await tester.pumpAndSettle();

      expect((campo('persona-a'), campo('persona-b')), ('Bruno', 'Ana'));
      final giro = tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(giro.turns, .5);
      expect(habilitado(tester), isTrue);
    });

    testWidgets('consulta Demeter: manda módulo, IA y cultivo, y pinta la respuesta', (tester) async {
      Map<String, dynamic>? cuerpo;
      final service = ConsultasService(
        api: _api((req) async {
          cuerpo = jsonDecode(req.body) as Map<String, dynamic>;
          return _ok({
            'success': true,
            'response': '**Sí**, coseche temprano.',
            'nuevo_balance': 995,
            'proveedor': 'gemini',
            'proveedor_etiqueta': 'Gemini · Google 2.5 Flash',
          });
        }),
      );
      await consola(tester, service: service);

      await elegir(tester, find.byKey(const ValueKey('selector-pregunta')), _preguntaCampo);
      await elegir(tester, find.text(TxConsultas.sinEspecificar).first, 'Hierbas y aromáticas');
      await tester.tap(find.byKey(const ValueKey('boton-consultar')));
      await tester.pumpAndSettle();

      expect(cuerpo, containsPair('modulo', 'demeter'));
      expect(cuerpo, containsPair('proveedor', 'gemini'));
      expect(cuerpo, containsPair('nivel_contexto', 'basico'));
      expect(cuerpo!['contexto_completo'], {'hemisferio': 'Sur', 'cultivo': 'hierbas y aromáticas'});
      expect(cuerpo!['usa_carta_astral'], isFalse);

      expect(find.text(TxConsultas.demeterRespuesta.toUpperCase()), findsOneWidget);
      expect(find.textContaining('coseche temprano', findRichText: true), findsOneWidget);
      expect(find.text('${TxConsultas.completada} · Gemini · Google 2.5 Flash'), findsOneWidget);
      expect(coinBalance.value, 995);

      await tester.tap(find.text(TxConsultas.limpiar.toUpperCase()));
      await tester.pumpAndSettle();
      expect(find.text(TxConsultas.demeterRespuesta.toUpperCase()), findsNothing);
    });

    testWidgets('un 200 con success: false se avisa como error y no pinta respuesta', (tester) async {
      final service = ConsultasService(
        api: _api((_) async => _ok({'success': false, 'error': 'Groq no está configurado en este servidor.', 'nuevo_balance': 1000})),
      );
      await consola(tester, service: service);
      await elegir(tester, find.byKey(const ValueKey('selector-pregunta')), _preguntaCampo);
      await tester.tap(find.byKey(const ValueKey('boton-consultar')));
      await tester.pumpAndSettle();

      expect(find.text('Groq no está configurado en este servidor.'), findsOneWidget);
      expect(find.text(TxConsultas.demeterRespuesta.toUpperCase()), findsNothing);
      expect(coinBalance.value, 1000);
    });

    testWidgets('sin saldo ofrece ir a la tienda', (tester) async {
      final service = ConsultasService(
        api: _api((_) async => http.Response(
              jsonEncode({
                'success': false,
                'error': 'No tienes suficiente Polvo Estelar (5 requeridos)…',
                'insufficient_coins': true,
                'current_balance': 3,
                'required_coins': 5,
              }),
              403,
              headers: _json,
            )),
      );
      await consola(tester, service: service);
      await elegir(tester, find.byKey(const ValueKey('selector-pregunta')), _preguntaCampo);
      await tester.tap(find.byKey(const ValueKey('boton-consultar')));
      await tester.pumpAndSettle();

      expect(find.text(TxConsultas.sinSaldo), findsOneWidget);
      expect(find.text(TxConsultas.irTienda), findsOneWidget);
      expect(coinBalance.value, 3);
    });
  });

  group('pantalla', () {
    testWidgets('a 360 px sin desbordes: consola, historial con insignias y paginación', (tester) async {
      await telefono(tester, alto: 800);
      final pedidos = <Uri>[];
      final api = _api((req) async {
        pedidos.add(req.url);
        return switch (req.url.path) {
          '/api/consultas/catalogo' => _ok(_catalogoJson),
          '/api/consultas/contexto' => _ok({
              'success': true,
              'lugar': 'Valle Ñandú de los Andes con un nombre larguísimo',
              'fecha': '05 Nov 2026',
              'hora': '10:30',
              'franja_demeter': [],
              'franja_oraculo': [],
              'contexto_demeter': {},
              'contexto_oraculo': {},
            }),
          '/api/user/charts' => _ok({'status': 'success', 'data': []}),
          _ => _ok({
              'status': 'success',
              'data': {
                'current_page': int.parse(req.url.queryParameters['page'] ?? '1'),
                'last_page': 2,
                'total': 16,
                'data': [
                  {
                    'id': req.url.queryParameters['page'] == '2' ? 99 : 7,
                    'modulo': req.url.queryParameters['page'] == '2' ? 'persefone' : 'demeter',
                    'pregunta': '¿Es buen momento para sembrar raíces y tubérculos en el huerto del fondo?',
                    'respuesta': '## Sí\nSiembre con luna menguante. ' * 6,
                    'tiempo_respuesta_ms': 1234,
                    'contexto_astronomico': {
                      'planetas_visibles': ['Marte', 'Venus', 'Júpiter', 'Saturno'],
                    },
                    'notas': [],
                    'created_at': '2026-11-05T13:30:00.000000Z',
                  },
                ],
              },
            }),
        };
      });

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Scaffold(
              body: ConsultasScreen(
                service: ConsultasService(api: api, ubicacion: _SinUbicacion()),
                cartas: AstralChartService(api: api),
                anuncio: AnuncioConsulta.ninguno(),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Sin GPS, el contexto va sin coordenadas.
      final contexto = pedidos.firstWhere((u) => u.path.endsWith('/consultas/contexto'));
      expect(contexto.queryParameters, isEmpty);
      expect(find.textContaining('📍 Valle Ñandú'), findsOneWidget);
      expect(find.text(TxConsultas.archivo(16, 0)), findsOneWidget);

      // Baja hasta el historial y pide la segunda página.
      await tester.scrollUntilVisible(find.byKey(const ValueKey('consulta-7')), 400);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const ValueKey('consulta-7')), matching: find.text('🌾 DEMETER')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('consulta-7')), matching: find.text('+1')),
        findsOneWidget,
      );
      expect(find.text('⏱ 1,2 s'), findsWidgets);

      await tester.scrollUntilVisible(find.byKey(const ValueKey('consulta-99')), 400);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const ValueKey('consulta-99')), matching: find.text('💞 PERSÉFONE')), findsOneWidget);
      expect(pedidos.where((u) => u.path.endsWith('/user/history')).map((u) => u.queryParameters['page']), ['1', '2']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('detalle: paneles, cultivo en el contexto y una nota nueva', (tester) async {
      await telefono(tester, alto: 4000);
      Map<String, dynamic>? nota;
      final api = _api((req) async {
        if (req.method == 'POST') {
          nota = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'nota': {'id': 3, 'contenido': nota!['contenido'], 'created_at': '2026-11-05T13:40:00.000000Z'},
            }),
            201,
            headers: _json,
          );
        }
        return _ok({
          'status': 'success',
          'data': {
            'id': 7,
            'modulo': 'demeter',
            'pregunta': _preguntaCampo,
            'respuesta': '**Sí**, coseche temprano.',
            'fuente': 'gemini',
            'modelo_ia': 'gemini-2.5-flash',
            'desde_cache': true,
            'tiempo_respuesta_ms': 2345,
            'caracteres_respuesta': 1234,
            'contexto_astronomico': {
              'estacion': 'primavera',
              'luna': {'fase': 'Luna llena', 'iluminacion': 98},
              'clima': {'temperatura': 17.6},
              'cultivo': 'frutales y parronales',
            },
            'notas': [],
            'created_at': '2026-11-05T13:30:00.000000Z',
          },
        });
      });

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: ConsultaDetalleScreen(consultaId: 7, service: ConsultasService(api: api)),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(TxConsultas.moduloNombreDemeter), findsWidgets);
      for (final panel in [
        TxConsultas.preguntaTitulo,
        TxConsultas.respuestaTitulo,
        TxConsultas.parametrosTitulo,
        TxConsultas.cieloTitulo,
        TxConsultas.contextoTitulo,
        TxConsultas.notasTitulo,
      ]) {
        expect(find.text(panel.toUpperCase()), findsOneWidget, reason: panel);
      }
      expect(find.text(TxConsultas.chipCache), findsOneWidget);
      expect(find.text(TxConsultas.caracteres('1.234')), findsOneWidget);
      expect(find.text('2,35 s'), findsOneWidget);
      expect(find.text('Luna llena'), findsOneWidget);
      // Lo que no es cielo también se muestra.
      expect(find.text('Cultivo'), findsOneWidget);
      expect(find.text('frutales y parronales'), findsOneWidget);
      expect(find.text('Clima · Temperatura'), findsOneWidget);
      expect(find.text(TxConsultas.sinNotas), findsOneWidget);

      await tester.tap(find.text(TxConsultas.agregar));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('nota-texto')), 'Regué al día siguiente');
      await tester.tap(find.text(TxConsultas.guardar));
      await tester.pumpAndSettle();

      expect(nota, {'contenido': 'Regué al día siguiente'});
      expect(find.text('Regué al día siguiente'), findsOneWidget);
      expect(find.text(TxConsultas.sinNotas), findsNothing);
    });

    testWidgets('a tamaño tableta tampoco desborda', (tester) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _api((req) async => switch (req.url.path) {
            '/api/consultas/catalogo' => _ok(_catalogoJson),
            '/api/user/charts' => _ok({'status': 'success', 'data': []}),
            '/api/user/history' => _ok({
                'status': 'success',
                'data': {'current_page': 1, 'last_page': 1, 'total': 0, 'data': []},
              }),
            _ => _ok({'success': true, 'lugar': 'Ñuñoa', 'fecha': '05 Nov 2026', 'hora': '10:30'}),
          });
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Scaffold(
              body: ConsultasScreen(
                service: ConsultasService(api: api, ubicacion: _SinUbicacion()),
                cartas: AstralChartService(api: api),
                anuncio: AnuncioConsulta.ninguno(),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(TxConsultas.vacioTitulo), findsOneWidget);
    });
  });
}
