import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'token_store.dart';

/// Cliente HTTP único del API de windowsdemeter.com.
///
/// Pone las cabeceras y el token, aplica timeout a todas las llamadas y
/// convierte las respuestas de error en [ApiException]. Nunca registra bodies,
/// cabeceras ni la query (que puede llevar coordenadas).
class ApiClient {
  ApiClient({
    http.Client? httpClient,
    TokenStore? tokenStore,
    String baseUrl = kApiBase,
    Future<void> Function(Duration)? sleep,
  })  : _http = httpClient ?? http.Client(),
        _tokens = tokenStore ?? TokenStore(),
        _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _sleep = sleep ?? Future<void>.delayed;

  /// Instancia que usan los servicios. Los tests pueden reemplazarla.
  static ApiClient instance = ApiClient();

  /// El servidor rechazó el token (401) y la sesión ya se borró.
  void Function()? onSessionExpired;

  /// Al usuario no le alcanza el polvo estelar (403 `insufficient_coins`).
  void Function(InsufficientCoinsException error)? onInsufficientCoins;

  final http.Client _http;
  final TokenStore _tokens;
  final String _baseUrl;
  final Future<void> Function(Duration) _sleep;

  // Reintentos ante 429, y la espera máxima que aceptamos del servidor.
  static const int _maxRetries = 2;
  static const Duration _maxRetryWait = Duration(seconds: 10);

  bool _expiring = false;

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
    Duration timeout = kRequestTimeout,
  }) =>
      _send('GET', path, query: query, auth: auth, timeout: timeout);

  Future<dynamic> post(
    String path, {
    Object? body,
    bool auth = true,
    Duration timeout = kRequestTimeout,
  }) =>
      _send('POST', path, body: body, auth: auth, timeout: timeout);

  Future<dynamic> put(
    String path, {
    Object? body,
    Duration timeout = kRequestTimeout,
  }) =>
      _send('PUT', path, body: body, timeout: timeout);

  Future<dynamic> patch(
    String path, {
    Object? body,
    Duration timeout = kRequestTimeout,
  }) =>
      _send('PATCH', path, body: body, timeout: timeout);

  Future<dynamic> delete(
    String path, {
    Object? body,
    Duration timeout = kRequestTimeout,
  }) =>
      _send('DELETE', path, body: body, timeout: timeout);

  /// Devuelve el body decodificado (JSON, texto o `null` si viene vacío) o
  /// lanza una [ApiException].
  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = true,
    required Duration timeout,
  }) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }

    final token = auth ? await _tokens.read() : null;
    final headers = {
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final encodedBody = body == null ? null : jsonEncode(body);

    for (var attempt = 0;; attempt++) {
      final response = await _request(method, uri, headers, encodedBody, timeout);

      if (response.statusCode == 429 && attempt < _maxRetries) {
        final wait = _retryDelay(response, attempt);
        if (wait != null) {
          await _sleep(wait);
          continue;
        }
      }

      return _handle(method, uri, response, token);
    }
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
    Duration timeout,
  ) async {
    // Se arma de nuevo en cada intento: un http.Request no se puede reenviar.
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = body;

    try {
      return await _http
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on TimeoutException {
      _log(method, uri, 'timeout');
      throw const NetworkException('El servidor tardó demasiado en responder.');
    } on http.ClientException {
      // El mensaje de ClientException trae la URL completa: no se propaga.
      _log(method, uri, 'sin conexión');
      throw const NetworkException('No hay conexión con el servidor.');
    }
  }

  Future<dynamic> _handle(
    String method,
    Uri uri,
    http.Response response,
    String? sentToken,
  ) async {
    final status = response.statusCode;
    final data = _decode(response);
    if (status >= 200 && status < 300) return data;

    _log(method, uri, '$status');
    final message = apiMessage(data);

    switch (status) {
      case 401:
        // Sin token es un login fallido, no una sesión vencida.
        if (sentToken == null) {
          throw UnauthorizedException(message ?? 'No autorizado.');
        }
        await _expireSession(sentToken);
        throw const UnauthorizedException('Tu sesión expiró. Vuelve a entrar.');

      case 403 when data is Map && data['insufficient_coins'] == true:
        final error = InsufficientCoinsException(
          message ?? 'Polvo estelar insuficiente.',
          required: _asInt(data['required_coins']),
          balance: _asInt(data['current_balance']),
        );
        onInsufficientCoins?.call(error);
        throw error;

      case 422:
        final fieldErrors = _fieldErrors(data);
        final first = fieldErrors.values.expand((e) => e).firstOrNull;
        throw ValidationException(
          first ?? message ?? 'Revisa los datos ingresados.',
          fieldErrors,
        );

      case 429:
        throw const RateLimitedException(
          'Demasiadas solicitudes. Intenta de nuevo en un momento.',
        );

      default:
        throw ApiException(
          message ?? 'Error del servidor ($status).',
          statusCode: status,
        );
    }
  }

  /// Borra la sesión y avisa a la app una sola vez, aunque fallen varias
  /// llamadas a la vez con el mismo token.
  Future<void> _expireSession(String sentToken) async {
    if (_expiring) return;
    _expiring = true;
    try {
      // Si el token cambió (otro login entretanto), este 401 es viejo.
      if (await _tokens.read() != sentToken) return;
      await _tokens.clear();
      onSessionExpired?.call();
    } finally {
      _expiring = false;
    }
  }

  /// Usa `Retry-After` si viene en segundos; si no, 1 s y luego 2 s. `null`
  /// si el servidor pide esperar más de lo razonable con la pantalla abierta.
  Duration? _retryDelay(http.Response response, int attempt) {
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    final wait = seconds != null
        ? Duration(seconds: seconds)
        : Duration(seconds: 1 << attempt);
    return wait > _maxRetryWait ? null : wait;
  }

  static dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      return response.body;
    }
  }

  static Map<String, List<String>> _fieldErrors(dynamic data) {
    final errors = data is Map ? data['errors'] : null;
    if (errors is! Map) return const {};
    return {
      for (final entry in errors.entries)
        entry.key.toString(): entry.value is List
            ? [for (final e in entry.value as List) e.toString()]
            : [entry.value.toString()],
    };
  }

  static int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  // Solo método, ruta y resultado: nada de query, cabeceras ni body.
  static void _log(String method, Uri uri, String result) {
    if (kDebugMode) debugPrint('API $method ${uri.path} → $result');
  }
}

/// El mensaje que manda el servidor en `message` o `error`, si hay.
String? apiMessage(dynamic data) {
  if (data is! Map) return null;
  for (final key in const ['message', 'error']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value;
  }
  return null;
}

/// El body como mapa JSON, o un error legible si el servidor mandó otra cosa.
Map<String, dynamic> jsonMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  throw const ApiException('Respuesta inesperada del servidor.');
}

/// Error del API con un mensaje listo para mostrar. `toString()` da solo ese
/// mensaje: nunca el body, las cabeceras ni la URL.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Sin red, o el servidor no respondió dentro del timeout.
class NetworkException extends ApiException {
  const NetworkException(super.message);
}

/// 401. Si la llamada llevaba token, la sesión ya se borró.
class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message) : super(statusCode: 401);
}

/// 403 `insufficient_coins`.
class InsufficientCoinsException extends ApiException {
  const InsufficientCoinsException(super.message, {this.required, this.balance})
      : super(statusCode: 403);

  final int? required;
  final int? balance;
}

/// 422, con los errores de cada campo del formulario.
class ValidationException extends ApiException {
  const ValidationException(super.message, this.fieldErrors)
      : super(statusCode: 422);

  final Map<String, List<String>> fieldErrors;

  String? errorFor(String field) => fieldErrors[field]?.firstOrNull;
}

/// 429 que siguió tras los reintentos.
class RateLimitedException extends ApiException {
  const RateLimitedException(super.message) : super(statusCode: 429);
}
