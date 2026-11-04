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

  Future<Estudio> _estudioDe(Future<dynamic> peticion) async {
    final body = jsonMap(await peticion);
    updateCoinBalance(body['saldo']);
    return Estudio.fromJson(body['estudio']) ??
        (throw const ApiException('Respuesta inesperada del servidor.'));
  }
}
