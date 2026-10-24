import '../models/wallpaper_link.dart';
import 'api_client.dart';
import 'coin_balance.dart';

/// El enlace del fondo animado de cada favorito (`/api/favoritos/{id}/fondo`).
/// Es el mismo token del Lively del PC: regenerarlo corta también ese.
class WallpaperLinksService {
  WallpaperLinksService({ApiClient? api}) : _apiOverride = api;

  final ApiClient? _apiOverride;
  ApiClient get _api => _apiOverride ?? ApiClient.instance;

  Future<WallpaperLink> get(int favoriteId) async =>
      _link(await _api.get('/favoritos/$favoriteId/fondo'));

  /// Si ya existía, el servidor devuelve el mismo.
  Future<WallpaperLink> create(int favoriteId) async =>
      _link(await _api.post('/favoritos/$favoriteId/fondo'));

  /// Token nuevo: el anterior da 404 al instante.
  Future<WallpaperLink> regenerate(int favoriteId) async =>
      _link(await _api.post('/favoritos/$favoriteId/fondo/regenerar'));

  /// Pago único por favorito. Si falta polvo o ya lo tiene, el servidor
  /// responde 422 con un mensaje para el usuario.
  Future<WallpaperLink> unlockRotating(int favoriteId) async {
    final body = jsonMap(await _api.post('/favoritos/$favoriteId/fondo/rotativo'));
    updateCoinBalance(body['saldo']);
    return WallpaperLink.fromJson(body);
  }

  static WallpaperLink _link(dynamic body) => WallpaperLink.fromJson(jsonMap(body));
}
