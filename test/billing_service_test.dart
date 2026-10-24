import 'dart:async';
import 'dart:convert';

import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/billing_service.dart';
import 'package:demeter/services/coin_balance.dart';
import 'package:demeter/services/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

import 'fakes/store_json.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _verify = '/api/store/google-play/verificar';

PurchaseDetails purchase(
  String token, {
  String product = 'polvo_100',
  PurchaseStatus status = PurchaseStatus.purchased,
  IAPError? error,
}) =>
    PurchaseDetails(
      productID: product,
      verificationData: PurchaseVerificationData(
        localVerificationData: '{}',
        serverVerificationData: token,
        source: 'google_play',
      ),
      transactionDate: '0',
      status: status,
    )..error = error;

ProductDetails product(String id) => ProductDetails(
      id: id,
      title: id,
      description: '',
      price: r'$3.490',
      rawPrice: 3490,
      currencyCode: 'CLP',
    );

Map<String, Object> verified({
  bool credited = true,
  bool pending = false,
}) =>
    {
      'success': true,
      'acreditado': credited,
      'pendiente': pending,
      'polvo': 100,
      'saldo': 1100,
    };

void main() {
  // Lo que pasa, en orden: llamadas al servidor y consumos en Play.
  late List<String> log;
  late List<http.Request> verifications;
  late List<PurchaseParam> launched;
  late List<PurchaseDetails> owned;
  late StreamController<List<PurchaseDetails>> play;
  late List<PurchaseUpdate> updates;
  late (int, Object) verifyResponse;
  late bool consumeWorks;
  Completer<void>? serverGate;
  // Al abrir la compra: si Play la abre y lo que avisa por el stream.
  late bool launchWorks;
  List<PurchaseDetails>? onLaunch;
  // Lo que lanza la verificación en vez de responder.
  Object? serverThrows;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    coinBalance.value = null;
    log = [];
    verifications = [];
    launched = [];
    owned = [];
    updates = [];
    play = StreamController<List<PurchaseDetails>>.broadcast();
    verifyResponse = (200, verified());
    consumeWorks = true;
    serverGate = null;
    launchWorks = true;
    onLaunch = null;
    serverThrows = null;
  });

  tearDown(() => play.close());

  BillingService service() {
    final billing = BillingService(
      available: true,
      api: ApiClient(
        baseUrl: 'https://windowsdemeter.com/api',
        httpClient: MockClient((req) async {
          log.add('${req.method} ${req.url.path}');
          if (req.url.path == '/api/store/packages') {
            return http.Response(jsonEncode(storeCatalogJson()), 200, headers: _json);
          }
          verifications.add(req);
          await serverGate?.future;
          if (serverThrows case final error?) throw error;
          final (status, body) = verifyResponse;
          return http.Response(jsonEncode(body), status, headers: _json);
        }),
      ),
      purchaseStream: play.stream,
      queryPurchases: () async => owned,
      launch: (param) async {
        launched.add(param);
        if (onLaunch case final events?) play.add(events);
        return launchWorks;
      },
      consume: (purchase) async {
        log.add('consume ${purchase.verificationData.serverVerificationData}');
        return consumeWorks;
      },
      launchGrace: Duration.zero,
    )..start();
    billing.updates.listen(updates.add);
    return billing;
  }

  test('compra con la cuenta ofuscada que el servidor da justo antes', () async {
    final billing = service();

    await billing.buy(product('polvo_100'));

    expect(log, ['GET /api/store/packages']);
    final param = launched.single;
    expect(param.applicationUserName, kObfuscatedAccountId);
    expect(param.productDetails.id, 'polvo_100');
    expect(billing.buying.value, 'polvo_100');
  });

  test('sin la cuenta ofuscada no abre la compra', () async {
    final billing = BillingService(
      available: true,
      api: ApiClient(
        baseUrl: 'https://windowsdemeter.com/api',
        httpClient: MockClient((_) async => http.Response(
              jsonEncode(storeCatalogJson(accountId: null)),
              200,
              headers: _json,
            )),
      ),
      launch: (param) async {
        launched.add(param);
        return true;
      },
    );
    billing.updates.listen(updates.add);

    await billing.buy(product('polvo_100'));
    await pumpEventQueue();

    expect(launched, isEmpty);
    expect(updates.single.outcome, PurchaseOutcome.failed);
    expect(billing.buying.value, isNull);
  });

  test('sin paquetes no le pregunta a Play, que respondería con un error', () async {
    final billing = BillingService(
      available: true,
      queryProducts: (_) async => throw StateError('no debía consultar'),
    );

    expect(await billing.products({}), isEmpty);
  });

  test('con el 200 acredita, deja el saldo y recién entonces consume', () async {
    final billing = service();
    await billing.buy(product('polvo_100'));

    play.add([purchase('compra-1')]);
    await pumpEventQueue();

    expect(log, ['GET /api/store/packages', 'POST $_verify', 'consume compra-1']);
    expect(jsonDecode(verifications.single.body), {
      'product_id': 'polvo_100',
      'purchase_token': 'compra-1',
    });
    expect(verifications.single.headers['Authorization'], 'Bearer tok-1');
    expect(coinBalance.value, 1100);
    expect(updates.single.outcome, PurchaseOutcome.credited);
    expect(updates.single.message, contains('100 ✨'));
    expect(billing.buying.value, isNull);
  });

  test('ya acreditada (acreditado: false): la consume sin avisar de nuevo', () async {
    verifyResponse = (200, verified(credited: false));
    service();

    play.add([purchase('compra-1')]);
    await pumpEventQueue();

    expect(log, ['POST $_verify', 'consume compra-1']);
    expect(updates, isEmpty);
  });

  test('202 pendiente: no la consume y avisa que el pago está pendiente', () async {
    verifyResponse = (202, verified(credited: false, pending: true));
    service();

    play.add([purchase('compra-1')]);
    await pumpEventQueue();

    expect(log, ['POST $_verify']);
    expect(updates.single.outcome, PurchaseOutcome.pending);
  });

  test('422: no la consume y muestra el mensaje del servidor', () async {
    verifyResponse = (422, {'success': false, 'message': 'Esa compra es de otra cuenta.'});
    final billing = service();
    await billing.buy(product('polvo_100'));

    play.add([purchase('compra-1')]);
    await pumpEventQueue();

    expect(log.where((e) => e.startsWith('consume')), isEmpty);
    expect(updates.single.outcome, PurchaseOutcome.failed);
    expect(updates.single.message, 'Esa compra es de otra cuenta.');
    expect(billing.buying.value, isNull);
  });

  test('503: no la consume y avisa que se volverá a revisar', () async {
    verifyResponse = (503, {'success': false, 'message': 'Google no respondió.'});
    service();

    play.add([purchase('compra-1')]);
    await pumpEventQueue();

    expect(log, ['POST $_verify']);
    expect(updates.single.outcome, PurchaseOutcome.retryLater);
    expect(updates.single.message, startsWith('Google no respondió.'));
  });

  test('una compra pendiente en Play no va al servidor', () async {
    final billing = service();
    await billing.buy(product('polvo_100'));
    log.clear();

    play.add([purchase('compra-1', status: PurchaseStatus.pending)]);
    await pumpEventQueue();

    expect(log, isEmpty);
    expect(updates.single.outcome, PurchaseOutcome.pending);
    expect(billing.buying.value, isNull);
  });

  test('cancelar libera la tienda sin avisar nada', () async {
    final billing = service();
    await billing.buy(product('polvo_100'));
    log.clear();

    // Play avisa la cancelación sin producto.
    play.add([purchase('', product: '', status: PurchaseStatus.canceled)]);
    await pumpEventQueue();

    expect(log, isEmpty);
    expect(updates, isEmpty);
    expect(billing.buying.value, isNull);
  });

  group('al entrar con sesión', () {
    test('reverifica las compras sin consumir y salta las pendientes', () async {
      owned = [
        purchase('compra-1'),
        purchase('compra-2', status: PurchaseStatus.pending),
      ];

      await service().recover();
      await pumpEventQueue();

      expect(log, ['POST $_verify', 'consume compra-1']);
      expect(jsonDecode(verifications.single.body)['purchase_token'], 'compra-1');
      // Recuperada y acreditada: sí se avisa.
      expect(updates.single.outcome, PurchaseOutcome.credited);
    });

    // Ninguno consume ni avisa, y la compra se vuelve a mandar después.
    for (final (name, response, error) in <(String, (int, Object)?, Object?)>[
      ('un 422', (422, {'success': false, 'message': 'Cancelada.'}), null),
      ('un 503', (503, {'success': false, 'message': 'Google no respondió.'}), null),
      ('sin red', null, http.ClientException('sin red')),
      ('un error ajeno al API', null, StateError('TLS')),
    ]) {
      test('calla $name y la vuelve a mandar en la próxima revisión', () async {
        owned = [purchase('compra-1')];
        if (response != null) verifyResponse = response;
        serverThrows = error;
        final billing = service();

        await billing.recover();
        await pumpEventQueue();
        expect(log, ['POST $_verify']);
        expect(updates, isEmpty);

        verifyResponse = (200, verified());
        serverThrows = null;
        await billing.recover();
        expect(log, ['POST $_verify', 'POST $_verify', 'consume compra-1']);
      });
    }

    test('un 401 deja la compra en Play para la próxima sesión', () async {
      owned = [purchase('compra-1')];
      verifyResponse = (401, {'message': 'Unauthenticated.'});
      final billing = service();

      await billing.recover();
      await pumpEventQueue();
      expect(log, ['POST $_verify']);
      expect(updates, isEmpty);

      // Vuelve a entrar.
      FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-2'});
      verifyResponse = (200, verified());
      await billing.recover();
      expect(log.last, 'consume compra-1');
      expect(verifications.last.headers['Authorization'], 'Bearer tok-2');
    });

    test('sin sesión no manda nada', () async {
      FlutterSecureStorage.setMockInitialValues({});
      owned = [purchase('compra-1')];

      await service().recover();
      await pumpEventQueue();

      expect(log, isEmpty);
    });

    test('si no se pudo consumir, la próxima revisión la consume', () async {
      owned = [purchase('compra-1')];
      consumeWorks = false;
      final billing = service();
      await billing.recover();

      consumeWorks = true;
      verifyResponse = (200, verified(credited: false));
      await billing.recover();

      expect(log, [
        'POST $_verify',
        'consume compra-1',
        'POST $_verify',
        'consume compra-1',
      ]);
    });
  });

  test('la misma compra por el stream y por recover va una sola vez y avisa', () async {
    // Al cerrarse el diálogo de Play llegan las dos a la vez.
    owned = [purchase('compra-1')];
    verifyResponse = (503, {'success': false, 'message': 'Google no respondió.'});
    serverGate = Completer<void>();
    final billing = service();

    final recovering = billing.recover();
    await pumpEventQueue();
    play.add([purchase('compra-1')]);
    await pumpEventQueue();
    serverGate!.complete();
    await recovering;
    await pumpEventQueue();

    expect(verifications, hasLength(1));
    // recover calla los errores, pero el stream pedía avisar.
    expect(updates.single.outcome, PurchaseOutcome.retryLater);
  });

  test('si Play ya tiene una compra sin consumir del paquete, la reverifica', () async {
    owned = [purchase('compra-vieja')];
    final billing = service();
    await billing.buy(product('polvo_100'));

    play.add([
      purchase(
        '',
        product: '',
        status: PurchaseStatus.error,
        error: IAPError(
          source: 'google_play',
          code: 'purchase_error',
          message: BillingResponse.itemAlreadyOwned.toString(),
        ),
      ),
    ]);
    await pumpEventQueue();

    expect(log, contains('consume compra-vieja'));
    expect(
      [for (final u in updates) u.outcome],
      [PurchaseOutcome.retryLater, PurchaseOutcome.credited],
    );
    expect(billing.buying.value, isNull);
  });

  group('si Play no abre la compra', () {
    final alreadyOwned = purchase(
      '',
      product: '',
      status: PurchaseStatus.error,
      error: IAPError(
        source: 'google_play',
        code: 'purchase_error',
        message: BillingResponse.itemAlreadyOwned.toString(),
      ),
    );

    test('porque ya hay una sin consumir: avisa una vez y luego el 422', () async {
      // Una compra de otra cuenta de la app con la misma cuenta de Google.
      owned = [purchase('compra-ajena'), purchase('otra', product: 'polvo_50')];
      verifyResponse = (422, {'success': false, 'message': 'Esa compra es de otra cuenta.'});
      launchWorks = false;
      onLaunch = [alreadyOwned];
      final billing = service();

      await billing.buy(product('polvo_100'));
      await pumpEventQueue();

      // Solo se revisa el paquete que se quiso comprar.
      expect([for (final r in verifications) jsonDecode(r.body)['purchase_token']], ['compra-ajena']);
      expect([for (final u in updates) u.message], [
        'Tienes una compra de este paquete sin terminar. La estamos revisando.',
        'Esa compra es de otra cuenta.',
      ]);
      expect(log.where((e) => e.startsWith('consume')), isEmpty);
      expect(billing.buying.value, isNull);
    });

    test('porque ya hay una pendiente: avisa que el pago está pendiente', () async {
      owned = [purchase('compra-1', status: PurchaseStatus.pending)];
      launchWorks = false;
      onLaunch = [alreadyOwned];
      final billing = service();

      await billing.buy(product('polvo_100'));
      await pumpEventQueue();

      expect(verifications, isEmpty);
      expect(
        [for (final u in updates) u.outcome],
        [PurchaseOutcome.retryLater, PurchaseOutcome.pending],
      );
    });

    test('sin decir por qué: libera la tienda con un solo aviso', () async {
      launchWorks = false;
      final billing = service();

      await billing.buy(product('polvo_100'));
      await pumpEventQueue();

      expect(updates.single.outcome, PurchaseOutcome.failed);
      expect(billing.buying.value, isNull);
    });
  });

  test('Play responde OK sin compras: no verifica nada y libera la tienda', () async {
    final billing = service();
    await billing.buy(product('polvo_100'));
    log.clear();

    play.add([purchase('', product: '')]);
    await pumpEventQueue();

    expect(log, isEmpty);
    expect(updates, isEmpty);
    expect(billing.buying.value, isNull);
  });

  test('un error ajeno al API al verificar no deja la tienda trabada', () async {
    serverThrows = StateError('TLS');
    final billing = service();
    await billing.buy(product('polvo_100'));

    play.add([purchase('compra-1')]);
    await pumpEventQueue();

    expect(log.where((e) => e.startsWith('consume')), isEmpty);
    expect(updates.single.outcome, PurchaseOutcome.retryLater);
    expect(billing.buying.value, isNull);
  });

  test('si se cierra la sesión mientras se verifica, consume pero no toca el saldo ni avisa',
      () async {
    serverGate = Completer<void>();
    service();

    play.add([purchase('compra-1')]);
    await pumpEventQueue();
    await TokenStore().clear(); // Logout con la verificación en vuelo.
    serverGate!.complete();
    await pumpEventQueue();

    // El 200 ya acreditó a la cuenta que compró: se consume igual.
    expect(log, ['POST $_verify', 'consume compra-1']);
    expect(coinBalance.value, isNull);
    expect(updates, isEmpty);
  });
}
