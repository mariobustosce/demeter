import '../models/estudio_detalle.dart';
import '../models/observatorio.dart';
import 'api_client.dart';
import 'coin_balance.dart';

/// El Observatorio (`/api/observatorio`) y los Estudios del cielo. Se pagan
/// con polvo estelar ya comprado, sin Google Play Billing. Los errores de
/// negocio son 422 con el mensaje listo para mostrar.
class ObservatorioService {
  ObservatorioService({ApiClient? api}) : _apiOverride = api;

  final ApiClient? _apiOverride;
  ApiClient get _api => _apiOverride ?? ApiClient.instance;

  Future<Observatorio> resumen() async {
    final body = jsonMap(await _api.get('/observatorio'));
    updateCoinBalance(body['saldo']);
    return Observatorio.fromJson(body);
  }

  /// Contrata el estudio anual de un favorito.
  Future<Estudio> contratar(int favoritoId) =>
      _estudioDe(_api.post('/favoritos/$favoritoId/estudio'));

  /// Desde 30 días antes de vencer; reanuda uno en pausa.
  Future<Estudio> renovar(int estudioId) => _estudioDe(_api.post('/estudios/$estudioId/renovar'));

  /// Cabecera del estudio, con su primera y última captura. Lo ajeno es 404.
  Future<Estudio> estudio(int id) async {
    final body = jsonMap(await _api.get('/estudios/$id'));
    return Estudio.fromJson(body['estudio']) ??
        (throw const ApiException('Respuesta inesperada del servidor.'));
  }

  /// Los últimos 14 días, como el detalle web.
  Future<ResumenEstudio> resumen14(int id) async =>
      ResumenEstudio.fromJson(jsonMap(await _api.get('/estudios/$id/resumen')));

  /// Una página de capturas, la más reciente primero (máx. 200 por página).
  Future<PaginaCapturas> capturas(int id, {int pagina = 1, int porPagina = 50}) async =>
      PaginaCapturas.fromJson(jsonMap(await _api.get('/estudios/$id/capturas', query: {
        'page': '$pagina',
        'por_pagina': '${porPagina.clamp(1, 200)}',
      })));

  /// `csv` o `json`. Cobra por descarga: no se guarda para repetirla gratis.
  /// Un 422 es «te falta polvo» y no descuenta nada.
  Future<Descarga> exportar(int id, String formato) async {
    if (formato != 'csv' && formato != 'json') {
      throw const ApiException('Formato no válido.');
    }
    final d = await _api.download('/estudios/$id/exportar/$formato', timeout: const Duration(seconds: 60));
    // La respuesta es el archivo: el saldo nuevo se pide aparte.
    try {
      final me = jsonMap(await _api.get('/me'));
      updateCoinBalance(me['celestial_coins']);
    } on ApiException {
      // El archivo ya llegó; el saldo se pone al día en la próxima carga.
    }
    return d;
  }

  Future<Estudio> _estudioDe(Future<dynamic> peticion) async {
    final body = jsonMap(await peticion);
    updateCoinBalance(body['saldo']);
    return Estudio.fromJson(body['estudio']) ??
        (throw const ApiException('Respuesta inesperada del servidor.'));
  }
}
