import 'package:flutter/foundation.dart';

import '../models/aviso.dart';
import 'api_client.dart';

/// Avisos sin leer de la lista vigente (`no_leidos`), o `null` si todavía no
/// se sabe. Es el número de la pestaña ALERTAS.
final ValueNotifier<int?> unreadAlerts = ValueNotifier<int?>(null);

/// Los avisos del usuario (`/api/avisos`) y a qué alertas está suscrito.
class AlertsService {
  AlertsService({ApiClient? api}) : _apiOverride = api;

  final ApiClient? _apiOverride;
  ApiClient get _api => _apiOverride ?? ApiClient.instance;

  // El uuid de la ruta; así el id del push no puede salirse del path.
  static final RegExp _validId = RegExp(r'^[0-9a-fA-F-]{36}$');

  /// Los vigentes, del más nuevo al más viejo (máximo 20). Deja la cuenta de
  /// no leídos en [unreadAlerts].
  Future<List<Aviso>> list() async {
    final body = jsonMap(await _api.get('/avisos'));
    final raw = body['avisos'];
    final avisos = [
      if (raw is List)
        for (final item in raw) ?Aviso.fromJson(item),
    ];
    final unread = body['no_leidos'];
    unreadAlerts.value =
        unread is num ? unread.toInt() : avisos.where((a) => !a.read).length;
    return avisos;
  }

  /// Si el aviso ya no es suyo o no existe (404), no pasa nada: se ignora.
  Future<void> markRead(String id) async {
    if (!_validId.hasMatch(id)) return;
    try {
      await _api.post('/avisos/$id/leido');
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow;
    }
  }

  Future<void> markAllRead() async {
    await _api.post('/avisos/leidos');
    unreadAlerts.value = 0;
  }

  Future<AlertPreferences> preferences() async =>
      AlertPreferences.fromJson(jsonMap(await _api.get('/avisos/preferencias')));

  /// Devuelve las preferencias como quedaron en el servidor.
  Future<AlertPreferences> setActive(String type, bool active) async =>
      AlertPreferences.fromJson(jsonMap(await _api.put(
        '/avisos/preferencias',
        body: {'tipo': type, 'activo': active},
      )));
}
