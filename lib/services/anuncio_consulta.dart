import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ads_config.dart';

/// El intersticial que se muestra antes de cada consulta, igual que en la
/// antigua NewConsultationScreen: se carga al abrir la consola, se muestra al
/// pulsar «Consultar» y la consulta sale cuando se cierra (o si no había
/// anuncio listo). Los tests usan [AnuncioConsulta.ninguno].
abstract class AnuncioConsulta {
  void cargar();

  /// Muestra el anuncio si hay uno listo y luego corre [despues].
  void mostrarYLuego(Future<void> Function() despues);

  void dispose();

  static AnuncioConsulta intersticial() => _Intersticial();

  static AnuncioConsulta ninguno() => _Ninguno();
}

class _Ninguno implements AnuncioConsulta {
  @override
  void cargar() {}

  @override
  void mostrarYLuego(Future<void> Function() despues) => despues();

  @override
  void dispose() {}
}

class _Intersticial implements AnuncioConsulta {
  InterstitialAd? _anuncio;
  bool _listo = false;
  bool _cerrado = false;

  @override
  void cargar() {
    if (_cerrado) return;
    InterstitialAd.load(
      adUnitId: AdsConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (_cerrado) {
            ad.dispose();
            return;
          }
          _anuncio = ad;
          _listo = true;
          ad.fullScreenContentCallback = _alCerrar(null);
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: ${error.message}');
          _listo = false;
        },
      ),
    );
  }

  @override
  void mostrarYLuego(Future<void> Function() despues) {
    final anuncio = _anuncio;
    if (!_listo || anuncio == null) {
      despues();
      return;
    }
    anuncio.fullScreenContentCallback = _alCerrar(despues);
    anuncio.show();
  }

  FullScreenContentCallback<InterstitialAd> _alCerrar(Future<void> Function()? despues) {
    void reponer(InterstitialAd ad) {
      ad.dispose();
      _anuncio = null;
      _listo = false;
      cargar();
      despues?.call();
    }

    return FullScreenContentCallback(
      onAdDismissedFullScreenContent: reponer,
      onAdFailedToShowFullScreenContent: (ad, _) => reponer(ad),
    );
  }

  @override
  void dispose() {
    _cerrado = true;
    _anuncio?.dispose();
    _anuncio = null;
  }
}
