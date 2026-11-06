import 'dart:async';
import 'dart:convert';

import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/billing_service.dart';
import 'package:demeter/services/coin_balance.dart';
import 'package:demeter/services/tienda_plataforma.dart';
import 'package:demeter/services/token_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'fakes/store_json.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _verify = '/api/store/app-store/verificar';

/// Una transacción de StoreKit 2: `purchaseID` es el `transactionId`.
PurchaseDetails transaction(
  String? id, {
  String product = 'polvo_100',
  PurchaseStatus status = PurchaseStatus.purchased,
}) =>
    PurchaseDetails(
      purchaseID: id,
      productID: product,
      verificationData: PurchaseVerificationData(
        localVerificationData: '{}',
        // El recibo antiguo: no debe llegar al servidor.
        serverVerificationData: 'recibo-que-no-sirve',
        source: 'app_store',
      ),
      transactionDate: '0',
      status: status,
    );

ProductDetails product(String id) => ProductDetails(
      id: id,
      title: id,
      description: '',
      price: r'$3.490',
      rawPrice: 3490,
      currencyCode: 'CLP',
    );

Map<String, Object> verified({bool credited = true}) => {
      'success': true,
      'acreditado': credited,
      'pendiente': false,
      'polvo': 100,
      'saldo': 1100,
    };

void main() {
  late List<String> log;
  late List<http.Request> verifications;
  late List<PurchaseParam> launched;
  late List<PurchaseDetails> unfinished;
  late StreamController<List<PurchaseDetails>> storeKit;
  late List<PurchaseUpdate> updates;
  late (int, Object) verifyResponse;
  Completer<void>? serverGate;
  Object? launchThrows;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    coinBalance.value = null;
    log = [];
    verifications = [];
    launched = [];
    unfinished = [];
    updates = [];
    storeKit = StreamController<List<PurchaseDetails>>.broadcast();
    verifyResponse = (200, verified());
    serverGate = null;
    launchThrows = null;
  });

  tearDown(() => storeKit.close());

  BillingService service() {
    final billing = BillingService(
      available: true,
      plataforma: const TiendaAppStore(),
      api: ApiClient(
        baseUrl: 'https://windowsdemeter.com/api',
        httpClient: MockClient((req) async {
          log.add('${req.method} ${req.url.path}');
          if (req.url.path == '/api/store/packages') {
            expect(req.url.queryParameters, {'plataforma': 'ios'});
            return http.Response(jsonEncode(storeCatalogJsonIos()), 200, headers: _json);
          }
          verifications.add(req);
          await serverGate?.future;
          final (status, body) = verifyResponse;
          return http.Response(jsonEncode(body), status, headers: _json);
        }),
      ),
      purchaseStream: storeKit.stream,
      queryPurchases: () async => unfinished,
      launch: (param) async {
        if (launchThrows case final error?) throw error;
        launched.add(param);
        return true;
      },
      consume: (purchase) async {
        log.add('finish ${purchase.purchaseID}');
        return true;
      },
      launchGrace: Duration.zero,
    )..start();
    billing.updates.listen(updates.add);
    return billing;
  }

  test('compra con el app_account_token que el servidor da justo antes', () async {
    final billing = service();

    await billing.buy(product('polvo_100'));

    expect(log, ['GET /api/store/packages']);
    expect(launched.single.applicationUserName, kAppAccountToken);
    expect(billing.buying.value, 'polvo_100');
  });

  test('con el 200 verifica con transaction_id y recién entonces termina', () async {
    final billing = service();
    await billing.buy(product('polvo_100'));

    storeKit.add([transaction('2000000123')]);
    await pumpEventQueue();

    expect(log, ['GET /api/store/packages', 'POST $_verify', 'finish 2000000123']);
    expect(jsonDecode(verifications.single.body), {
      'product_id': 'polvo_100',
      'transaction_id': '2000000123',
    });
    expect(coinBalance.value, 1100);
    expect(updates.single.outcome, PurchaseOutcome.credited);
    expect(billing.buying.value, isNull);
  });

  test('ya acreditada (acreditado: false): termina sin avisar de nuevo', () async {
    verifyResponse = (200, verified(credited: false));
    service();

    storeKit.add([transaction('2000000123')]);
    await pumpEventQueue();

    expect(log, ['POST $_verify', 'finish 2000000123']);
    expect(updates, isEmpty);
  });

  test('422: no termina y muestra el mensaje del servidor', () async {
    verifyResponse = (422, {'success': false, 'message': 'Esta compra se hizo con otra cuenta.'});
    service();

    storeKit.add([transaction('2000000123')]);
    await pumpEventQueue();

    expect(log, ['POST $_verify']);
    expect(updates.single.outcome, PurchaseOutcome.failed);
    expect(updates.single.message, 'Esta compra se hizo con otra cuenta.');
  });

  test('503: no termina y avisa que se volverá a revisar', () async {
    verifyResponse = (503, {'success': false, 'message': 'Apple no respondió.'});
    service();

    storeKit.add([transaction('2000000123')]);
    await pumpEventQueue();

    expect(log, ['POST $_verify']);
    expect(updates.single.outcome, PurchaseOutcome.retryLater);
  });

  test('al entrar con sesión, manda y termina las transacciones sin terminar', () async {
    unfinished = [transaction('2000000123'), transaction('2000000456', product: 'polvo_50')];
    final billing = service();

    await billing.recover();
    await pumpEventQueue();

    expect(log, [
      'POST $_verify',
      'finish 2000000123',
      'POST $_verify',
      'finish 2000000456',
    ]);
    // Las revisiones automáticas solo avisan lo acreditado.
    expect(updates.map((u) => u.outcome), [PurchaseOutcome.credited, PurchaseOutcome.credited]);
  });

  test('«Ask to Buy» pendiente: avisa y no va al servidor', () async {
    service();

    storeKit.add([transaction(null, status: PurchaseStatus.pending)]);
    await pumpEventQueue();

    expect(log, isEmpty);
    expect(updates.single.outcome, PurchaseOutcome.pending);
    expect(updates.single.message, contains('la App Store'));
  });

  test('comprada sin transactionId: no va al servidor y avisa', () async {
    service();

    storeKit.add([transaction(null)]);
    await pumpEventQueue();

    expect(log, isEmpty);
    expect(updates.single.outcome, PurchaseOutcome.failed);
  });

  test('si StoreKit tiene otra del paquete sin terminar, la reverifica', () async {
    launchThrows = PlatformException(code: TiendaAppStore.duplicada);
    unfinished = [transaction('2000000123')];
    final billing = service();

    await billing.buy(product('polvo_100'));
    await pumpEventQueue();

    expect(updates.first.outcome, PurchaseOutcome.retryLater);
    expect(log, ['GET /api/store/packages', 'POST $_verify', 'finish 2000000123']);
    expect(updates.last.outcome, PurchaseOutcome.credited);
    expect(billing.buying.value, isNull);
  });

  test('si se cierra la sesión mientras se verifica, termina pero no toca el saldo ni avisa',
      () async {
    serverGate = Completer<void>();
    service();

    storeKit.add([transaction('2000000123')]);
    await pumpEventQueue();
    await TokenStore().clear();
    serverGate!.complete();
    await pumpEventQueue();

    expect(log, ['POST $_verify', 'finish 2000000123']);
    expect(coinBalance.value, isNull);
    expect(updates, isEmpty);
  });
}
