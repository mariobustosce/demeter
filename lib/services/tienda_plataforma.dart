import 'dart:io';

import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart'
    show InAppPurchaseAndroidPlatformAddition;
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

/// Lo que cambia entre Google Play y la App Store al vender polvo. El resto
/// del flujo (verificar en el servidor y cerrar solo con su 200) es común.
abstract class TiendaPlataforma {
  const TiendaPlataforma();

  /// La de este teléfono.
  factory TiendaPlataforma.actual() =>
      Platform.isIOS ? const TiendaAppStore() : const TiendaPlay();

  /// `plataforma` de `GET /store/packages`.
  String get plataforma;

  /// El campo del paquete con el producto de esta tienda.
  String get campoProducto;

  /// El campo del catálogo con la cuenta que va en la compra.
  String get campoCuenta;

  String get rutaVerificar;

  /// «Google Play» o «la App Store», para los avisos.
  String get nombre;

  /// Lo que identifica la compra ante el servidor, o `null` si no trae.
  String? clave(PurchaseDetails compra);

  Map<String, String> cuerpo(PurchaseDetails compra, String clave);

  /// Una compra «hecha» sin clave: en Play es un OK sin compras.
  bool get sinClaveEsError;

  Future<bool> lanzar(PurchaseParam param);

  /// Consumir (Play) o terminar (App Store). Solo tras el 200.
  Future<bool> cerrar(PurchaseDetails compra);

  /// Las compras hechas que la tienda tiene sin cerrar.
  Future<List<PurchaseDetails>> sinCerrar();

  /// El error dice que ya hay una compra de ese paquete sin cerrar.
  bool yaHayUna(Object? error);
}

class TiendaPlay extends TiendaPlataforma {
  const TiendaPlay();

  @override
  String get plataforma => 'android';
  @override
  String get campoProducto => 'google_play_product_id';
  @override
  String get campoCuenta => 'obfuscated_account_id';
  @override
  String get rutaVerificar => '/store/google-play/verificar';
  @override
  String get nombre => 'Google Play';
  @override
  bool get sinClaveEsError => false;

  @override
  String? clave(PurchaseDetails compra) =>
      compra.verificationData.serverVerificationData;

  @override
  Map<String, String> cuerpo(PurchaseDetails compra, String clave) =>
      {'product_id': compra.productID, 'purchase_token': clave};

  @override
  Future<bool> lanzar(PurchaseParam param) => InAppPurchase.instance
      .buyConsumable(purchaseParam: param, autoConsume: false);

  @override
  Future<bool> cerrar(PurchaseDetails compra) async {
    final result = await InAppPurchase.instance
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
        .consumePurchase(compra);
    return result.responseCode == BillingResponse.ok;
  }

  @override
  Future<List<PurchaseDetails>> sinCerrar() async {
    // `restorePurchases()` las marca todas como restored, también las
    // pendientes: por eso se consultan aquí.
    final response = await InAppPurchase.instance
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
        .queryPastPurchases();
    return response.pastPurchases;
  }

  @override
  bool yaHayUna(Object? error) =>
      error is IAPError &&
      error.message == BillingResponse.itemAlreadyOwned.toString();
}

class TiendaAppStore extends TiendaPlataforma {
  const TiendaAppStore();

  /// Lo que lanza StoreKit al comprar un paquete con otra transacción suya
  /// sin terminar.
  static const duplicada = 'storekit_duplicate_product_object';

  @override
  String get plataforma => 'ios';
  @override
  String get campoProducto => 'app_store_product_id';
  @override
  String get campoCuenta => 'app_account_token';
  @override
  String get rutaVerificar => '/store/app-store/verificar';
  @override
  String get nombre => 'la App Store';
  @override
  bool get sinClaveEsError => true;

  /// El `transactionId` de StoreKit 2. El recibo de
  /// `serverVerificationData` no le sirve al servidor.
  @override
  String? clave(PurchaseDetails compra) => compra.purchaseID;

  @override
  Map<String, String> cuerpo(PurchaseDetails compra, String clave) =>
      {'product_id': compra.productID, 'transaction_id': clave};

  // En iOS el plugin exige autoConsume y aun así no termina la transacción:
  // eso lo hace [cerrar].
  @override
  Future<bool> lanzar(PurchaseParam param) =>
      InAppPurchase.instance.buyConsumable(purchaseParam: param);

  @override
  Future<bool> cerrar(PurchaseDetails compra) async {
    await InAppPurchase.instance.completePurchase(compra);
    return true;
  }

  @override
  Future<List<PurchaseDetails>> sinCerrar() async => [
        for (final t in await SK2Transaction.unfinishedTransactions())
          SK2PurchaseDetails(
            productID: t.productId,
            purchaseID: t.id,
            verificationData: PurchaseVerificationData(
              localVerificationData: t.jsonRepresentation ?? '',
              serverVerificationData: t.receiptData ?? '',
              source: kIAPSource,
            ),
            transactionDate: t.purchaseDate,
            status: PurchaseStatus.purchased,
            appAccountToken: t.appAccountToken,
            sk2Transaction: t,
          ),
      ];

  @override
  bool yaHayUna(Object? error) =>
      (error is PlatformException && error.code == duplicada) ||
      (error is IAPError && error.code == duplicada);
}
