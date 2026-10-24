import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'api_client.dart';
import 'coin_balance.dart';
import 'store_service.dart';
import 'token_store.dart';

/// Lo que pasó con una compra, para avisarle al usuario.
enum PurchaseOutcome {
  /// El servidor acreditó el polvo.
  credited,

  /// Google todavía no cobra (efectivo, etc.). El polvo llega cuando pague.
  pending,

  /// Play o el servidor la rechazaron. No se consumió.
  failed,

  /// No se pudo confirmar ahora. Queda en Play y se vuelve a mandar.
  retryLater,
}

class PurchaseUpdate {
  const PurchaseUpdate(this.outcome, this.message);

  final PurchaseOutcome outcome;
  final String message;
}

/// Un error al preparar la compra, con un mensaje para el usuario.
class BillingException implements Exception {
  const BillingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Compras de polvo estelar con Google Play Billing (solo Android).
///
/// - Cada compra lleva la cuenta ofuscada del servidor, pedida justo antes.
/// - Con la compra hecha, el servidor la confirma con Google y acredita el
///   polvo. **Solo con su 200 se consume** (`autoConsume` apagado).
/// - Lo que no se consumió (la app se cerró, sin red, pago pendiente…) se
///   vuelve a mandar al entrar con sesión y al volver a la app. El servidor
///   no acredita dos veces el mismo `purchase_token`.
///
/// El `purchase_token` nunca va a los logs.
class BillingService {
  BillingService({
    ApiClient? api,
    TokenStore? session,
    StoreService? store,
    bool? available,
    Stream<List<PurchaseDetails>>? purchaseStream,
    Future<List<PurchaseDetails>> Function()? queryPurchases,
    Future<ProductDetailsResponse> Function(Set<String> ids)? queryProducts,
    Future<bool> Function(PurchaseParam param)? launch,
    Future<bool> Function(PurchaseDetails purchase)? consume,
  })  : _apiOverride = api,
        _session = session ?? TokenStore(),
        _store = store ?? StoreService(api: api),
        _availableOverride = available,
        _purchaseStream = purchaseStream,
        _queryPurchases = queryPurchases,
        _queryProducts = queryProducts,
        _launch = launch,
        _consume = consume;

  /// Instancia que usa la app. Los tests pueden reemplazarla.
  static BillingService instance = BillingService();

  final ApiClient? _apiOverride;
  ApiClient get _api => _apiOverride ?? ApiClient.instance;
  final TokenStore _session;
  final StoreService _store;
  final bool? _availableOverride;
  final Stream<List<PurchaseDetails>>? _purchaseStream;
  final Future<List<PurchaseDetails>> Function()? _queryPurchases;
  final Future<ProductDetailsResponse> Function(Set<String>)? _queryProducts;
  final Future<bool> Function(PurchaseParam)? _launch;
  final Future<bool> Function(PurchaseDetails)? _consume;

  final StreamController<PurchaseUpdate> _updates =
      StreamController<PurchaseUpdate>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Tokens que se están verificando (con si hay que avisar), y los ya
  // consumidos en esta sesión. Al cerrarse el diálogo de Play la compra llega
  // a la vez por el stream y por el [recover] de volver a la app.
  final Map<String, bool> _inFlight = {};
  final Set<String> _consumed = {};

  /// El producto que se está comprando desde la tienda, o `null`.
  final ValueNotifier<String?> buying = ValueNotifier<String?>(null);

  /// Avisos para el usuario. Las compras recuperadas solo avisan si se
  /// acreditaron.
  Stream<PurchaseUpdate> get updates => _updates.stream;

  /// En iOS no se vende nada: Apple exige su propio sistema de pago y el
  /// servidor solo verifica compras de Google Play.
  bool get available => _availableOverride ?? Platform.isAndroid;

  /// Se llama al arrancar, lo antes posible, para no perder compras que Play
  /// avise con la app abierta.
  void start() {
    if (_subscription != null || !available) return;
    _subscription = (_purchaseStream ?? InAppPurchase.instance.purchaseStream)
        .listen(
      (purchases) {
        for (final purchase in purchases) {
          unawaited(_handle(purchase, notify: true));
        }
      },
      onError: (Object e) =>
          debugPrint('Compras: Play falló (${e.runtimeType}).'),
    );
  }

  /// Los productos de Play de estos paquetes, por id. Los que Play no
  /// conoce no vienen.
  Future<Map<String, ProductDetails>> products(Set<String> ids) async {
    if (!available) return const {};
    if (_queryProducts == null && !await InAppPurchase.instance.isAvailable()) {
      throw const BillingException(
        'Google Play no está disponible en este teléfono.',
      );
    }
    final response =
        await (_queryProducts ?? InAppPurchase.instance.queryProductDetails)(ids);
    if (response.error != null && response.productDetails.isEmpty) {
      throw const BillingException(
        'No se pudieron cargar los precios de Google Play.',
      );
    }
    return {
      for (final product in response.productDetails)
        if (ids.contains(product.id)) product.id: product,
    };
  }

  /// Abre la compra de Play. El resultado llega por [updates] y mientras
  /// tanto [buying] tiene el producto.
  Future<void> buy(ProductDetails product) async {
    if (!available || buying.value != null) return;
    buying.value = product.id;
    try {
      // Fija por usuario, pero el contrato pide no guardarla.
      final accountId = (await _store.catalog()).accountId;
      if (accountId == null) {
        throw const BillingException('No se pudo preparar la compra.');
      }
      final launched = await (_launch ?? _buyConsumable)(PurchaseParam(
        productDetails: product,
        applicationUserName: accountId,
      ));
      if (!launched) {
        // Puede ser una compra anterior de ese paquete sin consumir.
        unawaited(recover());
        _finish(product.id, const PurchaseUpdate(
          PurchaseOutcome.failed,
          'No se pudo abrir la compra de Google Play.',
        ));
      }
    } on ApiException catch (e) {
      _finish(product.id, PurchaseUpdate(PurchaseOutcome.failed, e.message));
    } on BillingException catch (e) {
      _finish(product.id, PurchaseUpdate(PurchaseOutcome.failed, e.message));
    } catch (e) {
      debugPrint('Compras: no se abrió la compra (${e.runtimeType}).');
      _finish(product.id, const PurchaseUpdate(
        PurchaseOutcome.failed,
        'No se pudo abrir la compra de Google Play.',
      ));
    }
  }

  /// Vuelve a mandar al servidor lo que Play tiene sin consumir. Va al entrar
  /// con sesión y al volver a la app. Nunca lanza.
  Future<void> recover() async {
    if (!available || await _session.read() == null) return;
    try {
      final purchases = await (_queryPurchases ?? _pastPurchases)();
      for (final purchase in purchases) {
        // Las pendientes las avisa Play por el stream cuando se pagan.
        if (purchase.status == PurchaseStatus.purchased) {
          await _handle(purchase, notify: false);
        }
      }
    } catch (e) {
      debugPrint('Compras: no se revisaron las pendientes (${e.runtimeType}).');
    }
  }

  Future<void> _handle(PurchaseDetails purchase, {required bool notify}) async {
    final product = purchase.productID;
    switch (purchase.status) {
      case PurchaseStatus.pending:
        _finish(product, notify ? _pending : null);
        return;
      case PurchaseStatus.canceled:
        _finish(product, null);
        return;
      case PurchaseStatus.error:
        _finish(product, _playError(purchase));
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        final token = purchase.verificationData.serverVerificationData;
        if (token.isEmpty || _consumed.contains(token)) return;
        if (_inFlight.containsKey(token)) {
          if (notify) _inFlight[token] = true;
          return;
        }
        _inFlight[token] = notify;
        try {
          final update = await _verify(purchase, token);
          // Se avisa si alguna de las dos vías lo pedía.
          final tell = _inFlight[token] == true ||
              update?.outcome == PurchaseOutcome.credited;
          _finish(product, tell ? update : null);
        } finally {
          _inFlight.remove(token);
        }
    }
  }

  /// Manda la compra al servidor y la consume solo si respondió 200.
  Future<PurchaseUpdate?> _verify(PurchaseDetails purchase, String token) async {
    // Sin sesión no hay a quién acreditarla: queda en Play para después.
    if (await _session.read() == null) return null;
    final Map<String, dynamic> body;
    try {
      body = jsonMap(await _api.post('/store/google-play/verificar', body: {
        'product_id': purchase.productID,
        'purchase_token': token,
      }));
    } on ApiException catch (e) {
      // 422 rechazada, 503 Google no respondió, sin red…: no se consume.
      return e.statusCode == 422
          ? PurchaseUpdate(PurchaseOutcome.failed, e.message)
          : _retryLater(e.message);
    }

    updateCoinBalance(body['saldo']);
    // 202: Google todavía no cobra. Se vuelve a mandar cuando Play avise.
    if (body['pendiente'] == true) return _pending;
    if (body['success'] != true) {
      return _retryLater('No pudimos confirmar tu compra.');
    }

    if (await _consumeQuietly(purchase)) _consumed.add(token);
    // `acreditado: false` es un reintento de algo ya acreditado.
    if (body['acreditado'] != true) return null;
    final coins = body['polvo'];
    return PurchaseUpdate(
      PurchaseOutcome.credited,
      coins is num
          ? 'Se sumaron ${coins.toInt()} ✨ a tu polvo estelar.'
          : 'Tu compra ya se acreditó.',
    );
  }

  static PurchaseUpdate _retryLater(String reason) => PurchaseUpdate(
        PurchaseOutcome.retryLater,
        '$reason Tu compra quedó guardada y la volveremos a revisar.',
      );

  /// Si falla, la compra sigue en Play: el próximo [recover] la manda otra
  /// vez, el servidor responde 200 sin sumar nada y se vuelve a consumir.
  Future<bool> _consumeQuietly(PurchaseDetails purchase) async {
    try {
      return await (_consume ?? _consumeOnPlay)(purchase);
    } catch (e) {
      debugPrint('Compras: no se consumió (${e.runtimeType}).');
      return false;
    }
  }

  PurchaseUpdate _playError(PurchaseDetails purchase) {
    if (purchase.error?.message == BillingResponse.itemAlreadyOwned.toString()) {
      // Quedó sin consumir una compra anterior de ese paquete.
      unawaited(recover());
      return const PurchaseUpdate(
        PurchaseOutcome.retryLater,
        'Tienes una compra de este paquete sin terminar. La estamos revisando.',
      );
    }
    return const PurchaseUpdate(
      PurchaseOutcome.failed,
      'Google Play no pudo completar la compra.',
    );
  }

  /// Avisa al usuario, si hay qué, y libera la tienda. Un error de Play sin
  /// compras llega sin producto.
  void _finish(String product, PurchaseUpdate? update) {
    if (update != null) _updates.add(update);
    if (product.isEmpty || buying.value == product) buying.value = null;
  }

  static const _pending = PurchaseUpdate(
    PurchaseOutcome.pending,
    'Tu pago está pendiente en Google Play. El polvo llegará cuando se '
    'confirme.',
  );

  static Future<bool> _buyConsumable(PurchaseParam param) => InAppPurchase
      .instance
      .buyConsumable(purchaseParam: param, autoConsume: false);

  static Future<List<PurchaseDetails>> _pastPurchases() async {
    // `restorePurchases()` las marca todas como restored, también las
    // pendientes: por eso se consultan aquí.
    final response = await InAppPurchase.instance
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
        .queryPastPurchases();
    return response.pastPurchases;
  }

  static Future<bool> _consumeOnPlay(PurchaseDetails purchase) async {
    final result = await InAppPurchase.instance
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
        .consumePurchase(purchase);
    return result.responseCode == BillingResponse.ok;
  }
}
