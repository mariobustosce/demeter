import '../models/landscape.dart';
import 'api_client.dart';
import 'coin_balance.dart';

/// El catálogo de «Mis paisajes» (`/api/paisajes`) y su compra con polvo
/// estelar. Las dos respuestas traen el saldo y lo dejan en [coinBalance].
class LandscapesService {
  LandscapesService({ApiClient? api}) : _apiOverride = api;

  final ApiClient? _apiOverride;
  ApiClient get _api => _apiOverride ?? ApiClient.instance;

  // La que acepta la ruta del servidor; así la clave no puede salirse del path.
  static final RegExp _validKey = RegExp(r'^[a-z0-9-]{1,40}$');

  /// En el orden que fija el admin.
  Future<List<Landscape>> catalog() async {
    final body = jsonMap(await _api.get('/paisajes'));
    updateCoinBalance(body['saldo']);
    final raw = body['paisajes'];
    if (raw is! List) return const [];
    return [
      for (final item in raw) ?Landscape.fromJson(item),
    ];
  }

  /// Devuelve el paisaje ya comprado. Si falta polvo o ya se podía usar, el
  /// servidor responde 422 con un mensaje para el usuario.
  Future<Landscape> buy(String key) async {
    if (!_validKey.hasMatch(key)) {
      throw const ApiException('Ese paisaje no está a la venta.');
    }
    final body = jsonMap(await _api.post('/paisajes/$key/comprar'));
    updateCoinBalance(body['saldo']);
    return Landscape.fromJson(body['paisaje']) ??
        (throw const ApiException('Respuesta inesperada del servidor.'));
  }
}
