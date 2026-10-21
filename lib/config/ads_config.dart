import 'package:flutter/foundation.dart';

/// IDs de AdMob centralizados.
///
/// En debug se usan siempre los IDs de prueba de Google. En release se usan
/// los IDs reales, y si todavía no están configurados se cae a los de prueba
/// para no romper el layout (un ID inválido hace fallar la carga del banner).
class AdsConfig {
  AdsConfig._();

  // --- IDs de prueba oficiales de Google (no generan ingresos) ---
  static const String _testAndroidBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testIosBanner = 'ca-app-pub-3940256099942544/2934735716';

  // TODO(admob): reemplazar por los Ad Unit ID reales de la cuenta de AdMob.
  // El App ID real va además en android/app/src/main/AndroidManifest.xml
  // (meta-data com.google.android.gms.ads.APPLICATION_ID).
  static const String _prodAndroidBanner = '';
  static const String _prodIosBanner = '';

  /// `true` cuando el build de release todavía apunta a inventario de prueba.
  static bool get usingTestAds =>
      kDebugMode ||
      (defaultTargetPlatform == TargetPlatform.iOS
          ? _prodIosBanner.isEmpty
          : _prodAndroidBanner.isEmpty);

  /// Ad Unit ID del banner del home para la plataforma actual.
  static String get bannerAdUnitId {
    final bool isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (kDebugMode) return isIos ? _testIosBanner : _testAndroidBanner;

    final String prod = isIos ? _prodIosBanner : _prodAndroidBanner;
    if (prod.isNotEmpty) return prod;
    return isIos ? _testIosBanner : _testAndroidBanner;
  }
}
