import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'map_urls.dart';

/// Un token de vista del mapa del usuario.
@immutable
class MapView {
  const MapView({required this.baseUrl, required this.expiresAt});

  /// `https://…/app/mapa/t/<token>`, sin barra final. Lleva el token: no se
  /// registra en ningún log.
  final String baseUrl;
  final DateTime expiresAt;

  /// Lee la respuesta de `POST /api/app/vista`. La vigencia se cuenta desde
  /// el reloj del teléfono con `expira_en`, por si ese reloj está corrido.
  factory MapView.fromJson(Map<String, dynamic> json, {required DateTime now}) {
    final rawBase = json['base_url'];
    final base = rawBase is String ? rawBase.replaceFirst(RegExp(r'/+$'), '') : '';
    if (base.isEmpty || !MapUrls.isMapPage(Uri.parse('$base/basico'))) {
      throw const ApiException('Respuesta inesperada del servidor.');
    }

    final seconds = json['expira_en'];
    final DateTime expiresAt;
    if (seconds is num && seconds > 0) {
      expiresAt = now.add(Duration(seconds: seconds.toInt()));
    } else {
      expiresAt = DateTime.tryParse('${json['expira_at']}') ?? now;
    }
    return MapView(baseUrl: base, expiresAt: expiresAt);
  }
}

/// Token de vista del mapa del usuario (`POST /api/app/vista`).
///
/// Vive solo en memoria: se pide al abrir la app y se renueva cuando le queda
/// menos de [renewBefore] o cuando el servidor ya no lo reconoce (404).
class MapViewService {
  MapViewService({ApiClient? api, DateTime Function()? clock})
      : _api = api,
        _clock = clock ?? DateTime.now;

  /// Instancia que usa la app. Los tests pueden reemplazarla.
  static MapViewService instance = MapViewService();

  static const Duration renewBefore = Duration(hours: 1);

  final ApiClient? _api;
  final DateTime Function() _clock;

  MapView? _current;
  Future<MapView>? _pending;

  // Sube con cada logout: una respuesta que llega después es de la sesión
  // anterior y no se guarda.
  int _session = 0;

  /// La vista vigente. Pide una nueva si no hay, si vence pronto o con
  /// [renew] (el servidor respondió 404 con la anterior).
  Future<MapView> get({bool renew = false}) {
    final current = _current;
    if (!renew &&
        current != null &&
        current.expiresAt.difference(_clock()) > renewBefore) {
      return Future.value(current);
    }
    // Varias pantallas pidiendo a la vez comparten la misma llamada.
    return _pending ??= _fetch();
  }

  Future<MapView> _fetch() async {
    final session = _session;
    try {
      final api = _api ?? ApiClient.instance;
      final body = jsonMap(await api.post('/app/vista'));
      final view = MapView.fromJson(body, now: _clock());
      if (session == _session) _current = view;
      return view;
    } finally {
      if (session == _session) _pending = null;
    }
  }

  /// Olvida la vista. Se llama al cerrar la sesión.
  void clear() {
    _session++;
    _current = null;
    _pending = null;
  }
}
