import 'package:demeter/models/map_mode.dart';
import 'package:demeter/services/map_urls.dart';
import 'package:demeter/widgets/map_web_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'fakes/fake_webview.dart';

void main() {
  late FakeWebViewPlatform platform;
  late List<({double ratio, bool renew})> calls;
  late int view;

  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    calls = [];
    view = 1;
  });

  // `v` hace de token de vista: cambia solo al renovarlo.
  Future<Uri> buildUrl(double ratio, {bool renew = false}) async {
    calls.add((ratio: ratio, renew: renew));
    if (renew) view++;
    return MapUrls.guest(MapMode.basico, ratio: ratio).replace(
      queryParameters: {'ratio': ratio.toStringAsFixed(2), 'v': '$view'},
    );
  }

  Widget host({
    Object? target = 'a',
    double width = 400,
    double height = 800,
    bool visible = true,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: MapWebView(target: target, buildUrl: buildUrl, visible: visible),
            ),
          ),
        ),
      );

  // Pantalla grande para que el SizedBox del mapa no se recorte.
  Future<void> pump(WidgetTester tester, Widget widget) {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(widget);
  }

  FakeNavigationDelegate delegate() => platform.last.delegate!;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  testWidgets('carga la URL con el alto ÷ ancho del widget', (tester) async {
    await pump(tester, host());
    await settle(tester);

    expect(calls.single.ratio, 2.0);
    expect(platform.last.loaded.single.queryParameters['ratio'], '2.00');
    expect(find.byKey(const Key('fake-webview')), findsOneWidget);
  });

  testWidgets('sin target no carga nada; al llegar, sí', (tester) async {
    await pump(tester, host(target: null));
    await settle(tester);
    expect(calls, isEmpty);

    await pump(tester, host(target: 'a'));
    await settle(tester);
    expect(calls, hasLength(1));
  });

  testWidgets('otro target recarga; el mismo no', (tester) async {
    await pump(tester, host(target: 'a'));
    await settle(tester);
    await pump(tester, host(target: 'a'));
    await settle(tester);
    expect(calls, hasLength(1));

    await pump(tester, host(target: 'b'));
    await settle(tester);
    expect(calls, hasLength(2));
    expect(platform.last.loaded, hasLength(2));
  });

  testWidgets('recarga si el alto ÷ ancho cambia en 0,1 o más', (tester) async {
    await pump(tester, host(height: 800));
    await settle(tester);
    await pump(tester, host(height: 820)); // 2.05: no vale la pena
    await settle(tester);
    expect(calls, hasLength(1));

    await pump(tester, host(height: 880)); // 2.2
    await settle(tester);
    expect(calls.map((c) => c.ratio), [2.0, 2.2]);
  });

  testWidgets('solo navega al mapa; lo demás del sitio sale y lo ajeno se bloquea',
      (tester) async {
    await pump(tester, host());
    await settle(tester);
    final nav = delegate();

    expect(await nav.navigate('https://windowsdemeter.com/app/mapa/t/x/basico/f/2'),
        NavigationDecision.navigate);
    expect(await nav.navigate('https://windowsdemeter.com/blog'),
        NavigationDecision.prevent);
    expect(await nav.navigate('https://evil.test/app/mapa/basico'),
        NavigationDecision.prevent);
    expect(await nav.navigate('https://windowsdemeter.com/blog', isMainFrame: false),
        NavigationDecision.prevent);
  });

  testWidgets('un 404 pide un token nuevo una vez; el segundo muestra el error',
      (tester) async {
    await pump(tester, host());
    await settle(tester);
    final first = platform.last.loaded.single;

    delegate().httpError(first, 404);
    await settle(tester);
    expect(calls.last.renew, isTrue);
    expect(platform.last.loaded, hasLength(2));

    delegate().httpError(platform.last.loaded.last, 404);
    await settle(tester);
    expect(find.text('Este mapa ya no está disponible.'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await settle(tester);
    expect(platform.last.loaded, hasLength(3));
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('el 404 del refresco también renueva el token', (tester) async {
    await pump(tester, host());
    await settle(tester);
    final refresh = platform.last.loaded.single.replace(
      queryParameters: {'ratio': '2.00', 'fragmento': '1'},
    );

    delegate().httpError(refresh, 404);
    await settle(tester);
    expect(calls.last.renew, isTrue);
  });

  testWidgets('si falla el refresco con otro código, el mapa queda como estaba',
      (tester) async {
    await pump(tester, host());
    await settle(tester);
    delegate().finish('');
    final refresh = platform.last.loaded.single.replace(
      queryParameters: {'ratio': '2.00', 'fragmento': '1'},
    );

    delegate().httpError(refresh, 429);
    await settle(tester);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('sin red en el documento: pantalla de reintento', (tester) async {
    await pump(tester, host());
    await settle(tester);

    // Un recurso suelto que falla no cuenta.
    delegate().resourceError(WebResourceErrorType.hostLookup, mainFrame: false);
    await settle(tester);
    expect(find.text('Reintentar'), findsNothing);

    delegate().resourceError(WebResourceErrorType.hostLookup);
    await settle(tester);
    expect(find.text('Sin conexión. Revisa tu red e inténtalo de nuevo.'), findsOneWidget);
  });

  testWidgets('el error del servidor en el documento muestra el reintento',
      (tester) async {
    await pump(tester, host());
    await settle(tester);

    delegate().httpError(platform.last.loaded.single, 503);
    await settle(tester);
    expect(find.textContaining('mantenimiento'), findsOneWidget);
  });

  testWidgets('oculto sale del árbol y vuelve sin recargar', (tester) async {
    await pump(tester, host());
    await settle(tester);
    delegate().finish('');

    await pump(tester, host(visible: false));
    await settle(tester);
    expect(find.byKey(const Key('fake-webview')), findsNothing);

    await pump(tester, host(visible: true));
    await settle(tester);
    expect(find.byKey(const Key('fake-webview')), findsOneWidget);
    // Al volver revisa el token, pero con la misma URL no recarga.
    expect(calls, hasLength(2));
    expect(platform.controllers.single.loaded, hasLength(1));
  });

  testWidgets('en segundo plano no revisa nada; al volver, sí', (tester) async {
    await pump(tester, host());
    await settle(tester);
    delegate().finish('');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 31));
    expect(calls, hasLength(1));

    view++;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(platform.last.loaded.last.queryParameters['v'], '2');
  });

  testWidgets('al volver a la vista con un token renovado, recarga', (tester) async {
    await pump(tester, host());
    await settle(tester);
    delegate().finish('');
    await pump(tester, host(visible: false));
    await settle(tester);

    view++; // el servicio renovó el token mientras tanto
    await pump(tester, host(visible: true));
    await settle(tester);
    expect(platform.last.loaded.last.queryParameters['v'], '2');
  });
}
