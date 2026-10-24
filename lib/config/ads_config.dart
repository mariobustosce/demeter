import 'package:flutter/foundation.dart';

/// IDs de AdMob centralizados.
///
/// En debug se usan siempre los IDs de prueba de Google. En release se usan
/// los IDs reales, y si todavía no están configurados se cae a los de prueba
/// para no romper el layout (un ID inválido hace fallar la carga del anuncio).
///
/// Los App ID no pueden vivir aquí porque los lee el sistema antes que Dart:
/// están en `android/app/src/main/AndroidManifest.xml`
/// (`com.google.android.gms.ads.APPLICATION_ID`) y en `ios/Runner/Info.plist`
/// (`GADApplicationIdentifier`). Hoy los dos son de prueba.
class AdsConfig {
  AdsConfig._();

  // --- IDs de prueba oficiales de Google (no generan ingresos) ---
  static const String _testAndroidBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testIosBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testAndroidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testIosInterstitial =
      'ca-app-pub-3940256099942544/4411468910';

  // TODO(admob): reemplazar por los Ad Unit ID reales de la cuenta de AdMob,
  // junto con los App ID del manifest y del Info.plist.
  static const String _prodAndroidBanner = '';
  static const String _prodIosBanner = '';
  static const String _prodAndroidInterstitial = '';
  static const String _prodIosInterstitial = '';

  static bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  /// `true` cuando el build de release todavía apunta a inventario de prueba.
  static bool get usingTestAds =>
      kDebugMode ||
      (_isIos ? _prodIosBanner.isEmpty : _prodAndroidBanner.isEmpty);

  /// Ad Unit ID del banner del home para la plataforma actual.
  static String get bannerAdUnitId => _pick(
        test: _isIos ? _testIosBanner : _testAndroidBanner,
        prod: _isIos ? _prodIosBanner : _prodAndroidBanner,
      );

  /// Ad Unit ID del intersticial de las consultas al oráculo.
  static String get interstitialAdUnitId => _pick(
        test: _isIos ? _testIosInterstitial : _testAndroidInterstitial,
        prod: _isIos ? _prodIosInterstitial : _prodAndroidInterstitial,
      );

  static String _pick({required String test, required String prod}) =>
      kDebugMode || prod.isEmpty ? test : prod;
}
