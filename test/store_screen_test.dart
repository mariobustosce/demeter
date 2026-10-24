import 'dart:convert';

import 'package:demeter/screens/store_screen.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/billing_service.dart';
import 'package:demeter/services/coin_balance.dart';
import 'package:demeter/services/store_service.dart';
import 'package:flutter/material.dart';
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

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    coinBalance.value = null;
    launched = [];
  });

  ApiClient api() => ApiClient(
        baseUrl: 'https://windowsdemeter.com/api',
        httpClient: MockClient((req) async {
          final body = req.url.path == '/api/me'
              ? {'id': 1, 'name': 'A', 'email': 'a@a.test', 'celestial_coins': 40}
              : storeCatalogJson(packages: [
                  storePackageJson(1, 'polvo_50', coins: 50),
                  storePackageJson(2, 'polvo_100', highlight: true),
                  // Todavía no está en Play Console.
                  storePackageJson(3, 'polvo_1000', coins: 1000),
                ]);
          return http.Response(jsonEncode(body), 200, headers: _json);
        }),
      );

  BillingService billing({bool available = true}) => BillingService(
        available: available,
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

  Future<void> pumpStore(WidgetTester tester, BillingService service) async {
    ApiClient.instance = api();
    await tester.pumpWidget(MaterialApp(
      home: StoreScreen(billing: service, store: StoreService(api: api())),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el precio de Play, no el de la web, y nada de Mercado Pago',
      (tester) async {
    await pumpStore(tester, billing());

    expect(find.text('40'), findsOneWidget); // El saldo de /me.
    expect(find.text(r'$1.990'), findsOneWidget);
    expect(find.text(r'$3.490'), findsOneWidget);
    expect(find.textContaining('3490'), findsNothing);
    expect(find.textContaining('Mercado Pago'), findsNothing);
    // El que Play no conoce no se ofrece.
    expect(find.text('1000 ✨'), findsNothing);
    expect(find.text('Comprar'), findsNWidgets(2));
  });

  testWidgets('al comprar, los botones esperan el resultado', (tester) async {
    final service = billing();
    await pumpStore(tester, service);

    await tester.ensureVisible(find.text('Comprar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comprar').last);
    // La rueda gira hasta que Play conteste: no hay pumpAndSettle.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(launched.single.productDetails.id, 'polvo_100');
    expect(launched.single.applicationUserName, kObfuscatedAccountId);
    expect(find.text('Comprar'), findsOneWidget); // El otro es la rueda.
    final buttons = tester.widgetList<ElevatedButton>(find.byType(ElevatedButton));
    expect(buttons.every((b) => b.onPressed == null), isTrue);
  });

  testWidgets('en iPhone se ve el saldo pero no se vende nada', (tester) async {
    await pumpStore(tester, billing(available: false));

    expect(find.text('40'), findsOneWidget);
    expect(find.textContaining('no se vende en iPhone'), findsOneWidget);
    expect(find.text('Comprar'), findsNothing);
  });
}
