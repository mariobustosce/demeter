import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../services/api_client.dart';
import '../services/map_urls.dart';

/// Fondo de la página del mapa: se ve mientras carga, sin destellos.
const Color kSkyColor = Color(0xFF0A0A0F);

const _accentCyan = Color(0xFF4FD0E7);
const _textColor = Color(0xFFF7FAFC);
const _secondaryTextColor = Color(0xFF94A3B8);

/// La URL del mapa para un alto ÷ ancho dado. Con [renew], el servidor ya no
/// reconoció la anterior (404) y hay que pedir otro token de vista.
typedef MapUrlBuilder = Future<Uri> Function(double ratio, {bool renew});

/// Avisa al mapa cuando otra página lo tapa, para que suelte el WebView
/// mientras tanto. Va en `navigatorObservers` de la app.
final RouteObserver<PageRoute<dynamic>> mapRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// El mapa kiosk del servidor en un WebView, con pantallas nativas de carga y
/// de error.
///
/// Solo navega a `/app/mapa/…`; los demás enlaces del sitio se abren en el
/// navegador y los de otros sitios se bloquean. No recibe el Bearer, no tiene
/// puentes JS ni acceso a archivos, y no registra URLs: llevan el token de
/// vista.
class MapWebView extends StatefulWidget {
  const MapWebView({
    super.key,
    required this.target,
    required this.buildUrl,
    this.visible = true,
  });

  /// Lo que se quiere ver (modo, lugar…). Al cambiar se pide la URL de nuevo.
  /// Con `null` aún no se sabe y se muestra la carga.
  final Object? target;

  final MapUrlBuilder buildUrl;

  /// Con `false` (otra pestaña a la vista) el WebView sale del árbol para no
  /// animar oculto; la página se conserva y vuelve sin recargar. Lo mismo pasa
  /// solo cuando otra página lo tapa.
  final bool visible;

  @override
  State<MapWebView> createState() => _MapWebViewState();
}

class _MapWebViewState extends State<MapWebView>
    with WidgetsBindingObserver, RouteAware {
  // La página no avisa si su refresco falla (vista vencida): cada tanto y al
  // volver a primer plano se pide la URL otra vez, por si hay token nuevo.
  static const Duration _recheckEvery = Duration(minutes: 15);

  // Tope a las renovaciones por 404, para no entrar en bucle si el 404 no es
  // por el token (un favorito borrado).
  static const Duration _renewCooldown = Duration(minutes: 10);

  late final WebViewController _controller = _createController();

  double? _ratio; // el que mide el widget ahora
  double? _usedRatio; // el de la URL cargada
  Uri? _url; // la URL cargada
  bool _needsLoad = true;
  bool _scheduled = false;
  bool _loading = true;
  String? _error;
  int _attempt = 0;
  DateTime? _renewedAt;
  Timer? _recheck;
  bool _covered = false; // otra página encima

  bool get _shown => widget.visible && !_covered;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recheck = Timer.periodic(_recheckEvery, (_) => _refreshIfStale());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) mapRouteObserver.subscribe(this, route);
  }

  @override
  void didUpdateWidget(MapWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.target != oldWidget.target) {
      _needsLoad = true;
      _renewedAt = null;
    }
    if (widget.visible && !oldWidget.visible) _refreshIfStale();
  }

  @override
  void dispose() {
    _recheck?.cancel();
    mapRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshIfStale();
  }

  @override
  void didPushNext() => setState(() => _covered = true);

  @override
  void didPopNext() {
    setState(() => _covered = false);
    _refreshIfStale();
  }

  WebViewController _createController() {
    final controller = WebViewController()
      // El mapa se anima con JS. No se agrega ningún JavaScriptChannel.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(kSkyColor)
      ..enableZoom(false)
      ..setVerticalScrollBarEnabled(false)
      ..setHorizontalScrollBarEnabled(false)
      ..setOverScrollMode(WebViewOverScrollMode.never)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _onNavigation,
        onPageFinished: _onPageFinished,
        onWebResourceError: _onResourceError,
        onHttpError: _onHttpError,
      ));

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform
        ..setAllowFileAccess(false)
        ..setAllowContentAccess(false)
        ..setMixedContentMode(MixedContentMode.neverAllow)
        // La ubicación la pone la app en la URL, redondeada.
        ..setGeolocationEnabled(false)
        // Con un callback, Chromium no copia la consola al logcat, donde iría
        // la URL de la página (con el token). En iOS no se pone: agregaría un
        // puente JS.
        ..setOnConsoleMessage((_) {});
    }
    return controller;
  }

  void _measure(Size size) {
    if (!size.isFinite || size.width <= 0 || size.height <= 0) return;
    final ratio = MapUrls.clampRatio(size.height / size.width);
    _ratio = ratio;

    // Si el alto ÷ ancho cambia en 0,1 o más, la página se recargaría sola con
    // el valor viejo: mejor cargar la URL con el nuevo.
    final used = _usedRatio;
    final resized = used != null && (ratio - used).abs() >= 0.1;
    if ((_needsLoad || resized) && !_scheduled && widget.target != null) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted) _load();
      });
    }
  }

  Future<void> _load({bool renew = false}) async {
    final ratio = _ratio;
    if (ratio == null || widget.target == null) return;
    _needsLoad = false;
    final attempt = ++_attempt;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = await widget.buildUrl(ratio, renew: renew);
      if (!mounted || attempt != _attempt) return;
      if (!MapUrls.isMapPage(url)) {
        throw const ApiException('No se pudo armar la dirección del mapa.');
      }
      _usedRatio = ratio;
      setState(() => _url = url);
      await _controller.loadRequest(url);
    } on UnauthorizedException {
      // El ApiClient ya borró la sesión y llevó al mapa de invitado.
    } on ApiException catch (e) {
      _fail(attempt, e.message);
    } catch (e) {
      debugPrint('Mapa: no se pudo cargar (${e.runtimeType}).');
      _fail(attempt, 'No se pudo cargar el mapa.');
    }
  }

  void _fail(int attempt, String message) {
    if (mounted && attempt == _attempt) setState(() => _error = message);
  }

  /// Si la URL cambió (token de vista renovado), la carga. Con la pantalla de
  /// error, reintenta: quizá volvió la red.
  Future<void> _refreshIfStale() async {
    // El timer sigue vivo con la app en segundo plano: ahí no se hace nada.
    final state = WidgetsBinding.instance.lifecycleState;
    final foreground = state == null || state == AppLifecycleState.resumed;
    if (!mounted || !_shown || !foreground || widget.target == null) return;
    if (_error != null) return _load();

    final ratio = _usedRatio;
    final current = _url;
    if (ratio == null || current == null || _loading) return;
    final attempt = _attempt;
    try {
      final url = await widget.buildUrl(ratio);
      if (mounted && attempt == _attempt && url != current) await _load();
    } catch (_) {
      // Sin red: la página se queda con su mapa y se reintenta más tarde.
    }
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (MapUrls.isMapPage(uri)) return NavigationDecision.navigate;

    // Otra página del sitio, tocada en la principal (no en un iframe): al
    // navegador. Lo demás no se abre.
    if (request.isMainFrame && MapUrls.opensInBrowser(uri)) {
      unawaited(_openInBrowser(uri));
    }
    return NavigationDecision.prevent;
  }

  static Future<void> _openInBrowser(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('No se pudo abrir el navegador (${e.runtimeType}).');
    }
  }

  void _onPageFinished(String _) {
    if (mounted) setState(() => _loading = false);
  }

  void _onResourceError(WebResourceError error) {
    // Solo cuenta el documento: una imagen o un script que fallan no tumban el
    // mapa.
    if (error.isForMainFrame == false) return;
    if (error.isForMainFrame == null) {
      final uri = Uri.tryParse(error.url ?? '');
      if (uri == null || !MapUrls.isMapPage(uri)) return;
    }
    // iOS: una carga cancelada por otra más nueva, o por la regla de
    // navegación. No es una falla.
    if (error.errorCode == -999 || error.errorCode == 102) return;

    debugPrint('Mapa: error de carga (${error.errorType?.name}).');
    if (mounted) setState(() => _error = _networkMessage(error.errorType));
  }

  void _onHttpError(HttpResponseError error) {
    final uri = error.request?.uri;
    final status = error.response?.statusCode;
    // Solo la página del mapa y su refresco; otros recursos no cuentan.
    if (uri == null || status == null || !MapUrls.isMapPage(uri)) return;

    // Vista vencida o revocada: otra vez con un token nuevo.
    final renewedAt = _renewedAt;
    if (status == 404 &&
        (renewedAt == null ||
            DateTime.now().difference(renewedAt) > _renewCooldown)) {
      _renewedAt = DateTime.now();
      unawaited(_load(renew: true));
      return;
    }

    // Si falla el refresco de 5 minutos, la página deja el mapa como estaba.
    if (MapUrls.isRefresh(uri)) return;

    debugPrint('Mapa: el servidor respondió $status.');
    if (mounted) setState(() => _error = _httpMessage(status));
  }

  static String _networkMessage(WebResourceErrorType? type) => switch (type) {
        WebResourceErrorType.hostLookup ||
        WebResourceErrorType.connect ||
        WebResourceErrorType.timeout ||
        WebResourceErrorType.io =>
          'Sin conexión. Revisa tu red e inténtalo de nuevo.',
        WebResourceErrorType.failedSslHandshake =>
          'No se pudo establecer una conexión segura con el servidor.',
        _ => 'No se pudo cargar el mapa.',
      };

  static String _httpMessage(int status) => switch (status) {
        404 => 'Este mapa ya no está disponible.',
        429 => 'Demasiadas solicitudes. Espera un momento e inténtalo de nuevo.',
        503 => 'El servidor está en mantenimiento. Inténtalo en unos segundos.',
        _ => 'El servidor no pudo mostrar el mapa ($status).',
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _measure(constraints.biggest);
        final error = _error;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: kSkyColor),
            if (_url != null && _shown) WebViewWidget(controller: _controller),
            if (error != null)
              _MapError(message: error, onRetry: _load)
            else if (_loading)
              const IgnorePointer(
                child: Center(
                  child: CircularProgressIndicator(color: _accentCyan),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MapError extends StatelessWidget {
  const _MapError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kSkyColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, color: _secondaryTextColor, size: 48),
              const SizedBox(height: 16),
              const Text(
                'No pudimos cargar el cielo',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textColor, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _secondaryTextColor, fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accentCyan,
                  foregroundColor: kSkyColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
