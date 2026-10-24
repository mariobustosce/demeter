import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// WebView de mentira para los tests: guarda lo que se carga y deja disparar
/// los eventos de navegación a mano.
class FakeWebViewPlatform extends WebViewPlatform {
  final List<FakeWebViewController> controllers = [];

  FakeWebViewController get last => controllers.last;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = FakeWebViewController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) =>
      FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) =>
      _FakeWebViewWidget(params);
}

class FakeWebViewController extends PlatformWebViewController {
  FakeWebViewController(super.params) : super.implementation();

  final List<Uri> loaded = [];
  FakeNavigationDelegate? delegate;

  @override
  Future<void> loadRequest(LoadRequestParams params) async =>
      loaded.add(params.uri);

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async =>
      delegate = handler as FakeNavigationDelegate;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> enableZoom(bool enabled) async {}

  @override
  Future<void> setVerticalScrollBarEnabled(bool enabled) async {}

  @override
  Future<void> setHorizontalScrollBarEnabled(bool enabled) async {}

  @override
  Future<void> setOverScrollMode(WebViewOverScrollMode mode) async {}
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  PageEventCallback? onPageFinished;
  WebResourceErrorCallback? onWebResourceError;
  HttpResponseErrorCallback? onHttpError;

  /// Lo que decidió la app para una navegación.
  Future<NavigationDecision> navigate(String url, {bool isMainFrame = true}) async =>
      await onNavigationRequest!(NavigationRequest(url: url, isMainFrame: isMainFrame));

  void finish(String url) => onPageFinished!(url);

  void httpError(Uri uri, int status) => onHttpError!(HttpResponseError(
        request: WebResourceRequest(uri: uri),
        response: WebResourceResponse(uri: uri, statusCode: status),
      ));

  void resourceError(WebResourceErrorType type, {bool mainFrame = true}) =>
      onWebResourceError!(WebResourceError(
        errorCode: -2,
        description: 'net::ERR',
        errorType: type,
        isForMainFrame: mainFrame,
      ));

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback callback) async =>
      onNavigationRequest = callback;

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async =>
      onPageFinished = callback;

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async =>
      onWebResourceError = callback;

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async =>
      onHttpError = callback;
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: Key('fake-webview'));
}
