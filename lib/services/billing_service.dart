import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'api_client.dart';
import 'coin_balance.dart';
import 'store_service.dart';
import 'tienda_plataforma.dart';
import 'token_store.dart';

/// Lo que pasó con una compra, para avisarle al usuario.
enum PurchaseOutcome {
  /// El servidor acreditó el polvo.
  credited,

  /// La tienda todavía no cobra (efectivo, «Ask to Buy»…). El polvo llega
  /// cuando se pague.
  pending,

  /// La tienda o el servidor la rechazaron. No se cerró.
  failed,

  /// No se pudo confirmar ahora. Queda en la tienda y se vuelve a mandar.
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

/// Compras de polvo estelar con Google Play (Android) o la App Store (iOS).
///
/// - Cada compra lleva la cuenta que da el servidor, pedida justo antes.
/// - Con la compra hecha, el servidor la confirma con la tienda y acredita
///   el polvo. **Solo con su 200 se cierra** (consumir en Play, terminar la
///   transacción en la App Store).
/// - Lo que no se cerró (la app se cerró, sin red, pago pendiente…) se
///   vuelve a mandar al entrar con sesión y al volver a la app. El servidor
///   no acredita dos veces la misma compra.
///
/// El token o id de la compra nunca va a los logs.
class BillingService {
  BillingService({
    ApiClient? api,
    TokenStore? session,
    StoreService? store,
    TiendaPlataforma? plataforma,
    bool? available,
    Stream<List<PurchaseDetails>>? purchaseStream,
    Future<List<PurchaseDetails>> Function()? queryPurchases,
    Future<ProductDetailsResponse> Function(Set<String> ids)? queryProducts,
    Future<bool> Function(PurchaseParam param)? launch,
    Future<bool> Function(PurchaseDetails purchase)? consume,
    Duration launchGrace = const Duration(seconds: 2),
  })  : _apiOverride = api,
        _session = session ?? TokenStore(),
        _plataforma = plataforma ?? TiendaPlataforma.actual(),
        _store = store ?? StoreService(api: api, plataforma: plataforma),
        _availableOverride = available,
        _purchaseStream = purchaseStream,
        _queryPurchases = queryPurchases,
        _queryProducts = queryProducts,
        _launch = launch,
        _consume = consume,
        _launchGrace = launchGrace;

  /// Instancia que usa la app. Los tests pueden reemplazarla.
  static BillingService instance = BillingService();

  final ApiClient? _apiOverride;
  ApiClient get _api => _apiOverride ?? ApiClient.instance;
  final TokenStore _session;
  final TiendaPlataforma _plataforma;
  final StoreService _store;
  final bool? _availableOverride;
  final Stream<List<PurchaseDetails>>? _purchaseStream;
  final Future<List<PurchaseDetails>> Function()? _queryPurchases;
  final Future<ProductDetailsResponse> Function(Set<String>)? _queryProducts;
  final Future<bool> Function(PurchaseParam)? _launch;
  final Future<bool> Function(PurchaseDetails)? _consume;
  // Lo que se espera a que Play diga por qué no abrió la compra.
  final Duration _launchGrace;
  int _attempts = 0;

  final StreamController<PurchaseUpdate> _updates =
      StreamController<PurchaseUpdate>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Compras que se están verificando (con si hay que avisar), y las ya
  // cerradas en esta sesión. Al cerrarse el diálogo de la tienda la compra
  // llega a la vez por el stream y por el [recover] de volver a la app.
  final Map<String, bool> _inFlight = {};
  final Set<String> _consumed = {};

  /// El producto que se está comprando desde la tienda, o `null`.
  final ValueNotifier<String?> buying = ValueNotifier<String?>(null);

  /// Avisos para el usuario. Las revisiones automáticas ([recover]) solo
  /// avisan lo acreditado.
  Stream<PurchaseUpdate> get updates => _updates.stream;

  bool get available =>
      _availableOverride ?? (Platform.isAndroid || Platform.isIOS);

  String get _nombreMayuscula =>
      _plataforma.nombre[0].toUpperCase() + _plataforma.nombre.substring(1);

  /// Se llama al arrancar, lo antes posible, para no perder compras que la
  /// tienda avise con la app abierta.
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
          debugPrint('Compras: la tienda falló (${e.runtimeType}).'),
    );
  }

  /// Los productos de la tienda de estos paquetes, por id. Los que la
  /// tienda no conoce no vienen.
  Future<Map<String, ProductDetails>> products(Set<String> ids) async {
    // Sin paquetes, Play respondería con un error.
    if (!available || ids.isEmpty) return const {};
    if (_queryProducts == null && !await InAppPurchase.instance.isAvailable()) {
      throw BillingException('$_nombreMayuscula no está disponible en este teléfono.');
    }
    final response =
        await (_queryProducts ?? InAppPurchase.instance.queryProductDetails)(ids);
    if (response.error != null && response.productDetails.isEmpty) {
      throw BillingException(
        'No se pudieron cargar los precios de ${_plataforma.nombre}.',
      );
    }
    return {
      for (final product in response.productDetails)
        if (ids.contains(product.id)) product.id: product,
    };
  }

  /// Abre la compra de la tienda. El resultado llega por [updates] y
  /// mientras tanto [buying] tiene el producto.
  Future<void> buy(ProductDetails product) async {
    if (!available || buying.value != null) return;
    buying.value = product.id;
    final attempt = ++_attempts;
    try {
      // Fija por usuario, pero el contrato pide no guardarla.
      final accountId = (await _store.catalog()).accountId;
      if (accountId == null) {
        throw const BillingException('No se pudo preparar la compra.');
      }
      final launched = await (_launch ?? _plataforma.lanzar)(PurchaseParam(
        productDetails: product,
        applicationUserName: accountId,
      ));
      if (!launched) _releaseLater(product.id, attempt);
    } on ApiException catch (e) {
      _finish(product.id, PurchaseUpdate(PurchaseOutcome.failed, e.message));
    } on BillingException catch (e) {
      _finish(product.id, PurchaseUpdate(PurchaseOutcome.failed, e.message));
    } catch (e) {
      if (_plataforma.yaHayUna(e)) {
        // StoreKit no abre la compra si hay otra del paquete sin terminar.
        unawaited(_recover(product: product.id));
        _finish(product.id, _alreadyOwned);
        return;
      }
      debugPrint('Compras: no se abrió la compra (${e.runtimeType}).');
      _finish(product.id, _notOpened);
    }
  }

  /// Vuelve a mandar al servidor lo que la tienda tiene sin cerrar. Va al
  /// entrar con sesión y al volver a la app, y solo avisa lo acreditado.
  /// Nunca lanza.
  Future<void> recover() => _recover();

  /// Igual que [recover], pero solo con [product] y avisando todo: el usuario
  /// quiso comprarlo y la tienda dice que ya tiene una compra sin cerrar.
  Future<void> _recover({String? product}) async {
    final notify = product != null;
    try {
      if (!available || await _session.read() == null) return;
      final purchases = await (_queryPurchases ?? _plataforma.sinCerrar)();
      for (final purchase in purchases) {
        if (notify && purchase.productID != product) continue;
        if (purchase.status == PurchaseStatus.purchased) {
          await _handle(purchase, notify: notify);
        } else if (notify && purchase.status == PurchaseStatus.pending) {
          // Si no, las pendientes las avisa la tienda por el stream al pagarse.
          _updates.add(_pending);
        }
      }
    } catch (e) {
      debugPrint('Compras: no se revisaron las pendientes (${e.runtimeType}).');
    }
  }

  /// Play no abrió la compra: suele decir por qué en el stream (por ejemplo,
  /// que ya hay una de ese paquete sin consumir). Si no lo dice, se libera la
  /// tienda con un aviso genérico.
  void _releaseLater(String product, int attempt) {
    Timer(_launchGrace, () {
      if (attempt != _attempts || buying.value != product) return;
      _finish(product, _notOpened);
      unawaited(recover());
    });
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
        // Un error sin compras llega sin producto: es el que se compraba.
        _finish(product, _storeError(purchase, product.isEmpty ? buying.value : product));
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        final token = _plataforma.clave(purchase) ?? '';
        if (token.isEmpty) {
          // En Play es un OK sin compras: no hay nada que verificar.
          _finish(product, notify && _plataforma.sinClaveEsError ? _unreadable : null);
          return;
        }
        if (_consumed.contains(token)) return;
        if (_inFlight.containsKey(token)) {
          if (notify) _inFlight[token] = true;
          return;
        }
        _inFlight[token] = notify;
        PurchaseUpdate? update;
        try {
          update = await _verify(purchase, token);
        } catch (e) {
          // Algo ajeno al API (TLS, almacenamiento…) no deja la tienda
          // trabada. La compra sigue en la tienda.
          debugPrint('Compras: no se verificó (${e.runtimeType}).');
          update = _retryLater('No pudimos confirmar tu compra.');
        }
        // Se avisa si alguna de las dos vías lo pedía.
        final tell = _inFlight.remove(token) == true ||
            update?.outcome == PurchaseOutcome.credited;
        _finish(product, tell ? update : null);
    }
  }

  /// Manda la compra al servidor y la cierra solo si respondió 200.
  Future<PurchaseUpdate?> _verify(PurchaseDetails purchase, String token) async {
    // Sin sesión no hay a quién acreditarla: queda en la tienda para después.
    final session = await _session.read();
    if (session == null) return null;
    Map<String, dynamic>? body;
    PurchaseUpdate? rejected;
    try {
      body = jsonMap(await _api.post(
        _plataforma.rutaVerificar,
        body: _plataforma.cuerpo(purchase, token),
      ));
    } on ApiException catch (e) {
      // 422 rechazada, 503 la tienda no respondió, sin red…: no se cierra.
      rejected = e.statusCode == 422
          ? PurchaseUpdate(PurchaseOutcome.failed, e.message)
          : _retryLater(e.message);
    }

    // Si entretanto se cerró la sesión (o entró otra cuenta), el saldo y los
    // avisos ya no son de quien está. Con el 200 se cierra igual: el polvo
    // ya está en la cuenta que compró.
    final sameSession = await _session.read() == session;
    if (body == null) return sameSession ? rejected : null;

    if (sameSession) updateCoinBalance(body['saldo']);
    // 202 (solo Play): Google todavía no cobra. Se vuelve a mandar cuando avise.
    if (body['pendiente'] == true) return sameSession ? _pending : null;
    if (body['success'] != true) {
      return sameSession ? _retryLater('No pudimos confirmar tu compra.') : null;
    }

    if (await _closeQuietly(purchase)) _consumed.add(token);
    // `acreditado: false` es un reintento de algo ya acreditado.
    if (!sameSession || body['acreditado'] != true) return null;
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

  /// Si falla, la compra sigue en la tienda: el próximo [recover] la manda
  /// otra vez, el servidor responde 200 sin sumar nada y se vuelve a cerrar.
  Future<bool> _closeQuietly(PurchaseDetails purchase) async {
    try {
      return await (_consume ?? _plataforma.cerrar)(purchase);
    } catch (e) {
      debugPrint('Compras: no se cerró (${e.runtimeType}).');
      return false;
    }
  }

  PurchaseUpdate _storeError(PurchaseDetails purchase, String? product) {
    if (_plataforma.yaHayUna(purchase.error)) {
      // Quedó sin cerrar una compra anterior de ese paquete: se revisa y
      // se avisa cómo terminó (acreditada, rechazada, pendiente…).
      unawaited(product == null ? recover() : _recover(product: product));
      return _alreadyOwned;
    }
    return PurchaseUpdate(
      PurchaseOutcome.failed,
      '$_nombreMayuscula no pudo completar la compra.',
    );
  }

  /// Avisa al usuario, si hay qué, y libera la tienda. Un error de Play sin
  /// compras llega sin producto.
  void _finish(String product, PurchaseUpdate? update) {
    if (update != null) _updates.add(update);
    if (product.isEmpty || buying.value == product) buying.value = null;
  }

  PurchaseUpdate get _pending => PurchaseUpdate(
        PurchaseOutcome.pending,
        'Tu pago está pendiente en ${_plataforma.nombre}. El polvo llegará '
        'cuando se confirme.',
      );

  PurchaseUpdate get _notOpened => PurchaseUpdate(
        PurchaseOutcome.failed,
        'No se pudo abrir la compra de ${_plataforma.nombre}.',
      );

  PurchaseUpdate get _unreadable => PurchaseUpdate(
        PurchaseOutcome.failed,
        'No se pudo leer la compra de ${_plataforma.nombre}.',
      );

  static const _alreadyOwned = PurchaseUpdate(
    PurchaseOutcome.retryLater,
    'Tienes una compra de este paquete sin terminar. La estamos revisando.',
  );
}
