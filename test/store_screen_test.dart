import 'dart:convert';

import 'package:demeter/screens/store_screen.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/billing_service.dart';
import 'package:demeter/services/coin_balance.dart';
import 'package:demeter/services/store_service.dart';
import 'package:demeter/services/tienda_plataforma.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'fakes/store_json.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

ProductDetails _product(String id, String price) => ProductDetails(
      id: id,
      title: id,
      description: '',
      price: price,
      rawPrice: 0,
      currencyCode: 'CLP',
    );

void main() {
  late List<PurchaseParam> launched;
  late bool conReferido;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    coinBalance.value = null;
    launched = [];
    conReferido = true;
  });

  ApiClient api() => ApiClient(
        baseUrl: 'https://windowsdemeter.com/api',
        httpClient: MockClient((req) async {
          switch (req.url.path) {
            case '/api/me':
              return http.Response(
                jsonEncode({'id': 1, 'name': 'A', 'email': 'a@a.test', 'celestial_coins': 40}),
                200,
                headers: _json,
              );
            case '/api/user/referral':
              if (!conReferido) return http.Response('{"message":"x"}', 500, headers: _json);
              return http.Response(
                jsonEncode({
                  'data': {'referral_code': 'CELEST-PRUEBA', 'reward_per_referral': 25},
                }),
                200,
                headers: _json,
              );
          }
          final paquetes = [
            storePackageJson(1, 'polvo_50', coins: 50),
            storePackageJson(2, 'polvo_100', highlight: true),
            // Todavía no está en la tienda.
            storePackageJson(3, 'polvo_1000', coins: 1000),
          ];
          return http.Response(
            jsonEncode(req.url.queryParameters['plataforma'] == 'ios'
                ? storeCatalogJsonIos(packages: paquetes)
                : storeCatalogJson(packages: paquetes)),
            200,
            headers: _json,
          );
        }),
      );

  BillingService billing({bool available = true, TiendaPlataforma? plataforma}) => BillingService(
        available: available,
        plataforma: plataforma,
        api: api(),
        purchaseStream: const Stream.empty(),
        queryProducts: (ids) async => ProductDetailsResponse(
          productDetails: [
            _product('polvo_50', r'$1.990'),
            _product('polvo_100', r'$3.490'),
          ],
          notFoundIDs: const ['polvo_1000'],
        ),
        launch: (param) async {
          launched.add(param);
          return true;
        },
      );

  Future<void> pumpStore(
    WidgetTester tester,
    BillingService service, {
    TargetPlatform platform = TargetPlatform.android,
    TiendaPlataforma? tienda,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    ApiClient.instance = api();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: platform),
      // Las estrellas quietas, para que pumpAndSettle termine.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: StoreScreen(billing: service, store: StoreService(api: api(), plataforma: tienda)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el precio de la tienda, no el de la web, y nada de Mercado Pago',
      (tester) async {
    await pumpStore(tester, billing());

    expect(find.text('40 ✨'), findsOneWidget); // El saldo de /me.
    expect(find.text('TIENDA ESTELAR'), findsOneWidget);
    expect(find.text(r'$1.990'), findsOneWidget);
    expect(find.text(r'$3.490'), findsOneWidget);
    expect(find.textContaining('3490'), findsNothing);
    expect(find.textContaining('Mercado Pago'), findsNothing);
    // El que Play no conoce no se ofrece.
    expect(find.byKey(const ValueKey('paquete-polvo_1000')), findsNothing);
    expect(find.text('Comprar ahora'), findsNWidgets(2));
    expect(find.text('Pago seguro con Google Play.'), findsOneWidget);
  });

  testWidgets('la cinta MEJOR VALOR sale solo en el paquete destacado', (tester) async {
    await pumpStore(tester, billing());

    expect(find.text('MEJOR VALOR'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('paquete-polvo_100')),
        matching: find.text('MEJOR VALOR'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('al comprar, el botón dice Procesando... y los demás esperan', (tester) async {
    final service = billing();
    await pumpStore(tester, service);

    final destacado = find.descendant(
      of: find.byKey(const ValueKey('paquete-polvo_100')),
      matching: find.text('Comprar ahora'),
    );
    await tester.ensureVisible(destacado);
    await tester.pumpAndSettle();
    await tester.tap(destacado);
    // La rueda gira hasta que Play conteste: no hay pumpAndSettle.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(launched.single.productDetails.id, 'polvo_100');
    expect(launched.single.applicationUserName, kObfuscatedAccountId);
    expect(find.text('Procesando...'), findsOneWidget);
    expect(find.text('Comprar ahora'), findsOneWidget);
    final compras = tester.widgetList<ButtonStyleButton>(
      find.byWidgetPredicate((w) => w is FilledButton || w is OutlinedButton),
    );
    expect(compras, hasLength(2));
    expect(compras.every((b) => b.onPressed == null), isTrue);
  });

  testWidgets('tocar el código de referido lo copia y avisa 2 s', (tester) async {
    String? copiado;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiado = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpStore(tester, billing());
    expect(find.text('GANA POLVO ESTELAR'), findsOneWidget);
    expect(find.textContaining('25 ✨', findRichText: true), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('tienda-codigo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tienda-codigo')));
    await tester.pump();

    expect(copiado, 'CELEST-PRUEBA');
    expect(find.text('¡CÓDIGO COPIADO!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('¡CÓDIGO COPIADO!'), findsNothing);
  });

  testWidgets('si el referido falla, no hay tarjeta y la tienda sigue', (tester) async {
    conReferido = false;
    await pumpStore(tester, billing());

    expect(find.byKey(const ValueKey('tienda-referido')), findsNothing);
    expect(find.text('Comprar ahora'), findsNWidgets(2));
  });

  testWidgets('en iPhone vende con la App Store, con su cuenta', (tester) async {
    const appStore = TiendaAppStore();
    await pumpStore(
      tester,
      billing(plataforma: appStore),
      platform: TargetPlatform.iOS,
      tienda: appStore,
    );

    expect(find.textContaining('se compra desde la app'), findsNothing);
    expect(find.text('Comprar ahora'), findsNWidgets(2));
    expect(find.text('Pago seguro con la App Store.'), findsOneWidget);
    expect(find.textContaining('Mercado Pago'), findsNothing);

    await tester.tap(find.text('Comprar ahora').first);
    await tester.pump();
    expect(launched.single.applicationUserName, kAppAccountToken);
  });

  testWidgets('sin tienda en el teléfono se ve el saldo y el aviso, pero no se vende', (tester) async {
    await pumpStore(tester, billing(available: false));

    expect(find.text('40 ✨'), findsOneWidget);
    expect(find.textContaining('se compra desde la app'), findsOneWidget);
    expect(find.text('Comprar ahora'), findsNothing);
    expect(find.textContaining('Pago seguro'), findsNothing);
  });

  testWidgets('sin productos en la tienda, lo dice', (tester) async {
    final vacio = BillingService(
      available: true,
      api: api(),
      purchaseStream: const Stream.empty(),
      queryProducts: (ids) async => ProductDetailsResponse(productDetails: const [], notFoundIDs: ids.toList()),
    );
    await pumpStore(tester, vacio);

    expect(find.textContaining('no hay paquetes a la venta'), findsOneWidget);
    expect(find.text('Comprar ahora'), findsNothing);
  });
}
